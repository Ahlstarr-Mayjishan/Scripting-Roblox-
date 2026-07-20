const API_ROOT = "https://discord.com/api/v10";

export function authorizationUrl(config, state) {
  const query = new URLSearchParams({
    client_id: config.clientId,
    redirect_uri: `${config.publicBaseUrl}/oauth/discord/callback`,
    response_type: "code",
    scope: "identify guilds.members.read",
    state,
  });
  return `https://discord.com/oauth2/authorize?${query}`;
}

export async function exchangeCode(config, code) {
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: config.clientSecret,
    grant_type: "authorization_code",
    code,
    redirect_uri: `${config.publicBaseUrl}/oauth/discord/callback`,
  });
  const response = await fetch(`${API_ROOT}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    throw new Error("Discord token exchange failed");
  }
  return result.access_token;
}

export async function getIdentityAndMember(config, accessToken) {
  const headers = { Authorization: `Bearer ${accessToken}` };
  const [userResponse, memberResponse] = await Promise.all([
    fetch(`${API_ROOT}/users/@me`, { headers }),
    fetch(`${API_ROOT}/users/@me/guilds/${config.guildId}/member`, { headers }),
  ]);

  if (!userResponse.ok) throw new Error("Discord user lookup failed");
  const user = await userResponse.json();
  if (!memberResponse.ok) return { user, member: null };
  return { user, member: await memberResponse.json() };
}

export async function getLiveGuildMember(config, discordUserId) {
  const response = await fetch(
    `${API_ROOT}/guilds/${config.guildId}/members/${discordUserId}`,
    { headers: { Authorization: `Bot ${config.botToken}` } },
  );
  if (response.status === 404) return null;
  if (!response.ok) throw new Error("Discord live member lookup failed");
  return response.json();
}

export async function sendDiscordLog(config, channelName, message) {
  const channelId = config.channelIds[channelName];
  if (!channelId) return;

  const response = await fetch(`${API_ROOT}/channels/${channelId}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bot ${config.botToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      content: String(message).slice(0, 1900),
      allowed_mentions: { parse: [] },
    }),
  });
  if (!response.ok) {
    throw new Error(`Discord channel log failed (${response.status})`);
  }
}
