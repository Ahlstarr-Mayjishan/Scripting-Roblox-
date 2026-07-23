const encoder = new TextEncoder();

export function randomToken(byteLength = 32) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

export async function sessionTokenForRequest(requestToken, clientToken, pepper) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const material = `nullscape-session:v1:${requestToken}:${clientToken}`;
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(material));
  return base64Url(new Uint8Array(signature));
}

export async function recoveryCodeForState(state, pepper) {
  const digest = await tokenHash(`nullscape-recovery:v1:${state}`, pepper);
  return digest.slice(0, 16).toUpperCase().match(/.{4}/g).join("-");
}

export function normalizeRecoveryCode(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim().replaceAll("-", "").replaceAll(" ", "").toUpperCase();
  return /^[A-F0-9]{16}$/.test(normalized) ? normalized : null;
}

export async function tokenHash(token, pepper) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(token));
  return hex(new Uint8Array(signature));
}

function base64Url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function hex(bytes) {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
