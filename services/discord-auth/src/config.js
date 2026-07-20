const DISCORD_ID = /^\d{17,20}$/;

export function readConfig(env) {
  const publicBaseUrl = required(env.PUBLIC_BASE_URL, "PUBLIC_BASE_URL").replace(/\/$/, "");
  const clientId = discordId(env.DISCORD_CLIENT_ID, "DISCORD_CLIENT_ID");
  const guildId = discordId(env.DISCORD_GUILD_ID, "DISCORD_GUILD_ID");
  const allowedRoleIds = required(env.ALLOWED_ROLE_IDS, "ALLOWED_ROLE_IDS")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  if (allowedRoleIds.length === 0 || allowedRoleIds.some((value) => !DISCORD_ID.test(value))) {
    throw new Error("ALLOWED_ROLE_IDS must contain comma-separated Discord role IDs");
  }

  required(env.DISCORD_CLIENT_SECRET, "DISCORD_CLIENT_SECRET");
  required(env.DISCORD_BOT_TOKEN, "DISCORD_BOT_TOKEN");
  if (required(env.TOKEN_PEPPER, "TOKEN_PEPPER").length < 32) {
    throw new Error("TOKEN_PEPPER must contain at least 32 characters");
  }

  return {
    publicBaseUrl,
    clientId,
    guildId,
    allowedRoleIds,
    clientSecret: env.DISCORD_CLIENT_SECRET,
    botToken: env.DISCORD_BOT_TOKEN,
    tokenPepper: env.TOKEN_PEPPER,
    channelIds: {
      adminAudit: discordId(env.CHANNEL_ADMIN_AUDIT, "CHANNEL_ADMIN_AUDIT"),
      systemHealth: discordId(env.CHANNEL_SYSTEM_HEALTH, "CHANNEL_SYSTEM_HEALTH"),
      securityAlerts: discordId(env.CHANNEL_SECURITY_ALERTS, "CHANNEL_SECURITY_ALERTS"),
      sessionLogs: discordId(env.CHANNEL_SESSION_LOGS, "CHANNEL_SESSION_LOGS"),
      licenseLogs: discordId(env.CHANNEL_LICENSE_LOGS, "CHANNEL_LICENSE_LOGS"),
      discordOauth: discordId(env.CHANNEL_DISCORD_OAUTH_LOG, "CHANNEL_DISCORD_OAUTH_LOG"),
      adminControl: discordId(env.CHANNEL_ADMIN_CONTROL, "CHANNEL_ADMIN_CONTROL"),
    },
  };
}

export function hasAllowedRole(memberRoleIds, allowedRoleIds) {
  const memberRoles = new Set(Array.isArray(memberRoleIds) ? memberRoleIds : []);
  return allowedRoleIds.some((roleId) => memberRoles.has(roleId));
}

function discordId(value, name) {
  const result = required(value, name);
  if (!DISCORD_ID.test(result)) {
    throw new Error(`${name} must be a Discord snowflake ID`);
  }
  return result;
}

function required(value, name) {
  if (typeof value !== "string" || value.trim() === "" || value.startsWith("REPLACE_")) {
    throw new Error(`${name} is not configured`);
  }
  return value.trim();
}
