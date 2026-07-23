import { tokenHash } from "./crypto.js";

export async function readNetworkSignals(request, pepper) {
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const country = normalizeSignal(request.headers.get("cf-ipcountry"));
  const asn = normalizeSignal(request.cf?.asn);
  return {
    ipHash: await tokenHash(`nullscape-network:v1:${ip}`, pepper),
    country,
    asn,
  };
}

export function compareNetworkSignals(previous, current) {
  if (!previous) {
    return { ipChanged: false, countryChanged: false, asnChanged: false, score: 0 };
  }
  const ipChanged = knownDifferent(previous.ipHash, current.ipHash);
  const countryChanged = knownDifferent(previous.country, current.country);
  const asnChanged = knownDifferent(previous.asn, current.asn);
  return {
    ipChanged,
    countryChanged,
    asnChanged,
    score: (ipChanged ? 10 : 0) + (countryChanged ? 35 : 0) + (asnChanged ? 25 : 0),
  };
}

export function requiresNetworkReauth(previous, current, now, windowSeconds) {
  if (!previous) return false;
  const lastSeenAt = Number(previous.last_seen_at);
  if (!Number.isFinite(lastSeenAt) || now - lastSeenAt < 0 || now - lastSeenAt > windowSeconds) {
    return false;
  }
  const risk = compareNetworkSignals(previous, current);
  return risk.countryChanged || risk.asnChanged;
}

function knownDifferent(left, right) {
  return Boolean(left && right && left !== "unknown" && right !== "unknown" && left !== right);
}

function normalizeSignal(value) {
  const normalized = String(value || "").trim();
  return normalized === "" ? "unknown" : normalized.slice(0, 32);
}
