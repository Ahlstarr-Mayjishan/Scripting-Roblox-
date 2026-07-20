import { hasAllowedRole } from "./config.js";
import { randomToken, tokenHash } from "./crypto.js";
import {
  authorizationUrl,
  exchangeCode,
  getIdentityAndMember,
  getLiveGuildMember,
  sendDiscordLog,
} from "./discord.js";
import { html, HttpError, json, loginInfoHtml, readJson } from "./http.js";
import { secureLoaderResponse, sourceBundleResponse } from "./source.js";
import {
  completeAuthRequest,
  consumeApprovedRequest,
  createAuthRequest,
  createSession,
  deleteSession,
  readAuthRequest,
  readSession,
  reserveCallback,
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
  if (request.method === "POST" && url.pathname === "/v1/session/verify") {
    return verifySession(request, env, config);
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
  await createAuthRequest(env.DB, {
    requestHash: await tokenHash(requestToken, config.tokenPepper),
    stateHash: await tokenHash(state, config.tokenPepper),
    clientHash: await tokenHash(clientToken, config.tokenPepper),
    createdAt: now,
    expiresAt: now + AUTH_REQUEST_TTL_SECONDS,
  });
  return json({
    status: "pending",
    request_token: requestToken,
    authorize_url: authorizationUrl(config, state),
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

  const approved = await consumeApprovedRequest(env.DB, requestHash, clientHash, now);
  if (!approved) throw new HttpError(409, "AUTH_REQUEST_ALREADY_USED");
  const sessionToken = randomToken();
  const expiresAt = now + SESSION_TTL_SECONDS;
  await createSession(env.DB, {
    tokenHash: await tokenHash(sessionToken, config.tokenPepper),
    clientHash,
    discordUserId: approved.discord_user_id,
    displayName: approved.display_name,
    roleIdsJson: approved.role_ids_json,
    createdAt: now,
    expiresAt,
  });
  queueLog(ctx, config, "sessionLogs", `Session issued | user=${approved.discord_user_id} | expires=${expiresAt}`);
  return json({
    status: "approved",
    session_token: sessionToken,
    expires_at: expiresAt,
    user: { id: approved.discord_user_id, display_name: approved.display_name },
  });
}

async function verifySession(request, env, config) {
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
    return approved
      ? html("Login approved", "Return to Roblox. NULLSCAPE will continue automatically.", true)
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

function unixTime() {
  return Math.floor(Date.now() / 1000);
}

async function enforceRateLimit(limiter, key) {
  const result = await limiter.limit({ key });
  if (!result.success) throw new HttpError(429, "RATE_LIMITED");
}
