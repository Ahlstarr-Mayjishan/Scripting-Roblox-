import { hasAllowedRole } from "./config.js";
import {
  normalizeRecoveryCode,
  randomToken,
  recoveryCodeForState,
  sessionTokenForRequest,
  tokenHash,
} from "./crypto.js";
import {
  authorizationUrl,
  exchangeCode,
  getIdentityAndMember,
  getLiveGuildMember,
  sendDiscordLog,
} from "./discord.js";
import { approvalHtml, html, HttpError, json, loginInfoHtml, readJson } from "./http.js";
import {
  compareNetworkSignals,
  readNetworkSignals,
  requiresNetworkReauth,
} from "./risk.js";
import { secureLoaderResponse, sourceBundleResponse } from "./source.js";
import {
  claimApprovedRecovery,
  claimDeviceTransfer,
  completeAuthRequest,
  countTrustedDevices,
  createAuthRequest,
  createSession,
  deleteSession,
  readAuthRequest,
  readSession,
  readTrustedDevice,
  releaseRecoveredDevice,
  reserveCallback,
  trustDevice,
} from "./repository.js";

const AUTH_REQUEST_TTL_SECONDS = 10 * 60;
const SESSION_TTL_SECONDS = 12 * 60 * 60;
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{40,100}$/;

export async function route(request, env, config, ctx) {
  const url = new URL(request.url);

  if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/login")) {
    return loginInfoHtml(config.publicBaseUrl);
  }
  if (request.method === "GET" && url.pathname === "/health") {
    return json({ ok: true, service: "nullscape-discord-auth" });
  }
  if (request.method === "GET" && url.pathname === "/loader") {
    return secureLoaderResponse(config.publicBaseUrl);
  }
  if (request.method === "POST" && url.pathname === "/v1/auth/start") {
    return startAuth(request, env, config);
  }
  if (request.method === "POST" && url.pathname === "/v1/auth/status") {
    return authStatus(request, env, config, ctx);
  }
  if (request.method === "POST" && url.pathname === "/v1/auth/recover") {
    return recoverAuth(request, env, config, ctx);
  }
  if (request.method === "POST" && url.pathname === "/v1/session/verify") {
    return verifySession(request, env, config, ctx);
  }
  if (request.method === "POST" && url.pathname === "/v1/source/bundle") {
    return downloadBundle(request, env, config, ctx);
  }
  if (request.method === "GET" && url.pathname === "/oauth/discord/callback") {
    return discordCallback(url, env, config, ctx);
  }
  throw new HttpError(404, "NOT_FOUND");
}

async function startAuth(request, env, config) {
  await enforceRateLimit(
    env.AUTH_START_LIMITER,
    request.headers.get("cf-connecting-ip") || "unknown-source",
  );
  const body = await readJson(request);
  const clientToken = validToken(body.client_token, "INVALID_CLIENT_TOKEN");
  const now = unixTime();
  const requestToken = randomToken();
  const state = randomToken();
  const recoveryCode = await recoveryCodeForState(state, config.tokenPepper);
  const normalizedRecoveryCode = normalizeRecoveryCode(recoveryCode);
  await createAuthRequest(env.DB, {
    requestHash: await tokenHash(requestToken, config.tokenPepper),
    stateHash: await tokenHash(state, config.tokenPepper),
    clientHash: await tokenHash(clientToken, config.tokenPepper),
    resumeCodeHash: await tokenHash(normalizedRecoveryCode, config.tokenPepper),
    createdAt: now,
    expiresAt: now + AUTH_REQUEST_TTL_SECONDS,
  });
  return json({
    status: "pending",
    request_token: requestToken,
    authorize_url: authorizationUrl(config, state),
    recovery_code: recoveryCode,
    expires_in: AUTH_REQUEST_TTL_SECONDS,
    poll_after_seconds: 4,
  }, 201);
}

async function authStatus(request, env, config, ctx) {
  const body = await readJson(request);
  const requestToken = validToken(body.request_token, "INVALID_REQUEST_TOKEN");
  const clientToken = validToken(body.client_token, "INVALID_CLIENT_TOKEN");
  const requestHash = await tokenHash(requestToken, config.tokenPepper);
  const clientHash = await tokenHash(clientToken, config.tokenPepper);
  const deviceLabel = validDeviceLabel(body.device_label);
  await enforceRateLimit(env.AUTH_STATUS_LIMITER, requestHash);
  const now = unixTime();
  const record = await readAuthRequest(env.DB, requestHash, clientHash, now);
  if (!record) throw new HttpError(404, "AUTH_REQUEST_NOT_FOUND");
  if (record.status === "pending" || record.status === "processing") {
    return json({ status: "pending", poll_after_seconds: 4 });
  }
  if (record.status === "denied") {
    return json({ status: "denied", reason: record.denied_reason || "ROLE_REQUIRED" }, 403);
  }

  return issueSession({
    request,
    env,
    config,
    ctx,
    clientToken,
    clientHash,
    discordUserId: record.discord_user_id,
    displayName: record.display_name,
    roleIdsJson: record.role_ids_json,
    deviceLabel,
    proof: requestToken,
    now,
  });
}

async function recoverAuth(request, env, config, ctx) {
  await enforceRateLimit(
    env.AUTH_START_LIMITER,
    `recover:${request.headers.get("cf-connecting-ip") || "unknown-source"}`,
  );
  const body = await readJson(request);
  const recoveryCode = normalizeRecoveryCode(body.recovery_code);
  if (!recoveryCode) throw new HttpError(400, "INVALID_RECOVERY_CODE");
  const clientToken = validToken(body.client_token, "INVALID_CLIENT_TOKEN");
  const clientHash = await tokenHash(clientToken, config.tokenPepper);
  const now = unixTime();
  const record = await claimApprovedRecovery(
    env.DB,
    await tokenHash(recoveryCode, config.tokenPepper),
    clientHash,
    now,
  );
  if (!record) throw new HttpError(409, "RECOVERY_CODE_INVALID_OR_USED");
  const originalDevice = record.original_client_hash
    ? await readTrustedDevice(env.DB, record.discord_user_id, record.original_client_hash)
    : null;
  if (originalDevice && record.original_client_hash !== clientHash) {
    const transfer = await claimDeviceTransfer(
      env.DB,
      record.discord_user_id,
      now,
      config.deviceTransferCooldownSeconds,
    );
    if (!transfer) {
      queueLog(
        ctx,
        config,
        "securityAlerts",
        `Device transfer cooldown blocked | user=${record.discord_user_id}`,
      );
      throw new HttpError(429, "DEVICE_TRANSFER_COOLDOWN");
    }
  }
  await releaseRecoveredDevice(
    env.DB,
    record.discord_user_id,
    record.original_client_hash,
    clientHash,
    now,
  );
  if (originalDevice && record.original_client_hash !== clientHash) {
    queueLog(
      ctx,
      config,
      "adminAudit",
      `Trusted device transferred by one-time recovery | user=${record.discord_user_id}`,
    );
  }
  return issueSession({
    request,
    env,
    config,
    ctx,
    clientToken,
    clientHash,
    discordUserId: record.discord_user_id,
    displayName: record.display_name,
    roleIdsJson: record.role_ids_json,
    deviceLabel: validDeviceLabel(body.device_label),
    proof: `recovery:${recoveryCode}`,
    now,
  });
}

async function verifySession(request, env, config, ctx) {
  const body = await readJson(request);
  const sessionToken = validToken(body.session_token, "INVALID_SESSION_TOKEN");
  const clientToken = validToken(body.client_token, "INVALID_CLIENT_TOKEN");
  const sessionHash = await tokenHash(sessionToken, config.tokenPepper);
  const clientHash = await tokenHash(clientToken, config.tokenPepper);
  await enforceRateLimit(env.SESSION_VERIFY_LIMITER, sessionHash);
  const now = unixTime();
  const session = await readSession(
    env.DB,
    sessionHash,
    clientHash,
    now,
  );
  if (!session) throw new HttpError(401, "SESSION_INVALID_OR_EXPIRED");
  await authorizeSessionDevice({
    request,
    env,
    config,
    ctx,
    session,
    sessionHash,
    clientHash,
    deviceLabel: validDeviceLabel(body.device_label),
    now,
  });
  return json({
    valid: true,
    expires_at: session.expires_at,
    user: { id: session.discord_user_id, display_name: session.display_name },
  });
}

async function downloadBundle(request, env, config, ctx) {
  const body = await readJson(request);
  const sessionToken = validToken(body.session_token, "INVALID_SESSION_TOKEN");
  const clientToken = validToken(body.client_token, "INVALID_CLIENT_TOKEN");
  const sessionHash = await tokenHash(sessionToken, config.tokenPepper);
  const clientHash = await tokenHash(clientToken, config.tokenPepper);
  await enforceRateLimit(env.SOURCE_BUNDLE_LIMITER, sessionHash);
  const session = await readSession(env.DB, sessionHash, clientHash, unixTime());
  if (!session) throw new HttpError(401, "SESSION_INVALID_OR_EXPIRED");
  await authorizeSessionDevice({
    request,
    env,
    config,
    ctx,
    session,
    sessionHash,
    clientHash,
    deviceLabel: validDeviceLabel(body.device_label),
    now: unixTime(),
  });
  const liveMember = await getLiveGuildMember(config, session.discord_user_id);
  if (!liveMember || !hasAllowedRole(liveMember.roles, config.allowedRoleIds)) {
    await deleteSession(env.DB, sessionHash);
    queueLog(ctx, config, "licenseLogs", `Access revoked | user=${session.discord_user_id} | reason=ROLE_REQUIRED`);
    queueLog(ctx, config, "securityAlerts", `Protected source denied | user=${session.discord_user_id} | reason=ROLE_REQUIRED`);
    throw new HttpError(403, "ROLE_REQUIRED");
  }
  queueLog(ctx, config, "sessionLogs", `Protected runtime delivered | user=${session.discord_user_id}`);
  return sourceBundleResponse();
}

async function discordCallback(url, env, config, ctx) {
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  if (!code || !state || !TOKEN_PATTERN.test(state)) {
    return html("Login failed", "The Discord callback was incomplete or invalid.", false);
  }

  const now = unixTime();
  const stateHash = await tokenHash(state, config.tokenPepper);
  const reserved = await reserveCallback(env.DB, stateHash, now);
  if (!reserved) return html("Login expired", "Start a new login from NULLSCAPE.", false);

  try {
    const accessToken = await exchangeCode(config, code);
    const { user, member } = await getIdentityAndMember(config, accessToken);
    const roleIds = member?.roles || [];
    const approved = member !== null && hasAllowedRole(roleIds, config.allowedRoleIds);
    await completeAuthRequest(env.DB, stateHash, {
      status: approved ? "approved" : "denied",
      discordUserId: user.id,
      displayName: user.global_name || user.username || user.id,
      roleIds,
      deniedReason: member === null ? "GUILD_MEMBERSHIP_REQUIRED" : "ROLE_REQUIRED",
    }, now);
    queueLog(
      ctx,
      config,
      "discordOauth",
      `${approved ? "OAuth approved" : "OAuth denied"} | user=${user.id} | reason=${approved ? "ALLOWED_ROLE" : (member === null ? "GUILD_MEMBERSHIP_REQUIRED" : "ROLE_REQUIRED")}`,
    );
    if (!approved) {
      queueLog(ctx, config, "securityAlerts", `OAuth access denied | user=${user.id}`);
    }
    const recoveryCode = await recoveryCodeForState(state, config.tokenPepper);
    return approved
      ? approvalHtml(recoveryCode)
      : html("Access denied", "Your Discord account does not have an allowed role.", false);
  } catch (error) {
    await completeAuthRequest(env.DB, stateHash, {
      status: "denied",
      deniedReason: "DISCORD_AUTH_FAILED",
    }, now);
    const reason = error instanceof Error ? error.message : "unknown Discord OAuth error";
    queueLog(ctx, config, "securityAlerts", `Discord OAuth failed before identity verification | error=${reason}`);
    return html("Login failed", "Discord authentication could not be completed. Try again.", false);
  }
}

async function issueSession(options) {
  const device = await authorizeDevice({
    request: options.request,
    env: options.env,
    config: options.config,
    ctx: options.ctx,
    discordUserId: options.discordUserId,
    clientHash: options.clientHash,
    deviceLabel: options.deviceLabel,
    now: options.now,
    allowNetworkChange: true,
  });
  const sessionToken = await sessionTokenForRequest(
    options.proof,
    options.clientToken,
    options.config.tokenPepper,
  );
  const sessionHash = await tokenHash(sessionToken, options.config.tokenPepper);
  const expiresAt = options.now + SESSION_TTL_SECONDS;
  const creation = await createSession(options.env.DB, {
    tokenHash: sessionHash,
    clientHash: options.clientHash,
    discordUserId: options.discordUserId,
    displayName: options.displayName,
    roleIdsJson: options.roleIdsJson,
    createdAt: options.now,
    expiresAt,
  });
  const session = await readSession(options.env.DB, sessionHash, options.clientHash, options.now);
  if (!session) throw new HttpError(503, "SESSION_ISSUE_FAILED");
  if (Number(creation?.meta?.changes || 0) > 0) {
    queueLog(
      options.ctx,
      options.config,
      "sessionLogs",
      `Session issued | user=${options.discordUserId} | device=${options.deviceLabel} | expires=${session.expires_at}`,
    );
  }
  return json({
    status: "approved",
    session_token: sessionToken,
    expires_at: session.expires_at,
    device: { trusted: true, count: device.count, limit: options.config.maxTrustedDevices },
    user: { id: options.discordUserId, display_name: options.displayName },
  });
}

async function authorizeSessionDevice(options) {
  try {
    return await authorizeDevice({
      request: options.request,
      env: options.env,
      config: options.config,
      ctx: options.ctx,
      discordUserId: options.session.discord_user_id,
      clientHash: options.clientHash,
      deviceLabel: options.deviceLabel,
      now: options.now,
    });
  } catch (error) {
    if (
      error instanceof HttpError
      && (error.code === "DEVICE_LIMIT_REACHED" || error.code === "NETWORK_REAUTH_REQUIRED")
    ) {
      await deleteSession(options.env.DB, options.sessionHash);
    }
    throw error;
  }
}

async function authorizeDevice(options) {
  const previous = await readTrustedDevice(
    options.env.DB,
    options.discordUserId,
    options.clientHash,
  );
  const network = await readNetworkSignals(options.request, options.config.tokenPepper);
  const risk = compareNetworkSignals(previous, network);
  if (
    !options.allowNetworkChange
    && requiresNetworkReauth(
      previous,
      network,
      options.now,
      options.config.concurrentNetworkWindowSeconds,
    )
  ) {
    queueLog(
      options.ctx,
      options.config,
      "securityAlerts",
      `Concurrent network change requires re-auth | user=${options.discordUserId} | device=${options.deviceLabel} | country=${network.country} | asn=${network.asn} | score=${risk.score}`,
    );
    throw new HttpError(401, "NETWORK_REAUTH_REQUIRED");
  }
  const trusted = await trustDevice(options.env.DB, {
    discordUserId: options.discordUserId,
    clientHash: options.clientHash,
    deviceLabel: options.deviceLabel,
    network,
    now: options.now,
  }, options.config.maxTrustedDevices);
  if (!trusted) {
    queueLog(
      options.ctx,
      options.config,
      "securityAlerts",
      `Device limit reached | user=${options.discordUserId} | device=${options.deviceLabel}`,
    );
    throw new HttpError(403, "DEVICE_LIMIT_REACHED");
  }

  const count = await countTrustedDevices(options.env.DB, options.discordUserId);
  if (!previous) {
    queueLog(
      options.ctx,
      options.config,
      "adminAudit",
      `Trusted device enrolled | user=${options.discordUserId} | device=${options.deviceLabel} | devices=${count}/${options.config.maxTrustedDevices} | country=${network.country} | asn=${network.asn}`,
    );
  } else if (risk.countryChanged || risk.asnChanged) {
    queueLog(
      options.ctx,
      options.config,
      "securityAlerts",
      `Network risk changed | user=${options.discordUserId} | device=${options.deviceLabel} | country=${network.country} | asn=${network.asn} | score=${risk.score}`,
    );
  }
  return { count, risk };
}

function queueLog(ctx, config, channelName, message) {
  const operation = sendDiscordLog(config, channelName, message).catch((error) => {
    console.error("Discord audit log failed", error instanceof Error ? error.message : "unknown");
  });
  if (ctx && typeof ctx.waitUntil === "function") ctx.waitUntil(operation);
}

function validToken(value, code) {
  if (typeof value !== "string" || !TOKEN_PATTERN.test(value)) throw new HttpError(400, code);
  return value;
}

function validDeviceLabel(value) {
  if (typeof value !== "string") return "Unknown device";
  const normalized = value.trim().replace(/[^A-Za-z0-9 ._-]/g, "").slice(0, 32);
  return normalized || "Unknown device";
}

function unixTime() {
  return Math.floor(Date.now() / 1000);
}

async function enforceRateLimit(limiter, key) {
  const result = await limiter.limit({ key });
  if (!result.success) throw new HttpError(429, "RATE_LIMITED");
}
