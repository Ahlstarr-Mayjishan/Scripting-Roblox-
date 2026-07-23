import assert from "node:assert/strict";
import test from "node:test";
import { hasAllowedRole, readConfig } from "../src/config.js";

const validEnv = {
  PUBLIC_BASE_URL: "https://auth.example.workers.dev/",
  DISCORD_CLIENT_ID: "123456789012345678",
  DISCORD_GUILD_ID: "223456789012345678",
  ALLOWED_ROLE_IDS: "323456789012345678, 423456789012345678",
  DISCORD_CLIENT_SECRET: "secret",
  DISCORD_BOT_TOKEN: "bot-secret",
  TOKEN_PEPPER: "01234567890123456789012345678901",
  MAX_TRUSTED_DEVICES: "2",
  DEVICE_TRANSFER_COOLDOWN_SECONDS: "86400",
  CONCURRENT_NETWORK_WINDOW_SECONDS: "180",
  CHANNEL_ADMIN_AUDIT: "1528712160404963458",
  CHANNEL_SYSTEM_HEALTH: "1528712049188671549",
  CHANNEL_SECURITY_ALERTS: "1528711953038704831",
  CHANNEL_SESSION_LOGS: "1528711893643038800",
  CHANNEL_LICENSE_LOGS: "1528711373801001050",
  CHANNEL_DISCORD_OAUTH_LOG: "1528706549566935142",
  CHANNEL_ADMIN_CONTROL: "1528705779568476260",
};

test("readConfig normalizes IDs and base URL", () => {
  const config = readConfig(validEnv);
  assert.equal(config.publicBaseUrl, "https://auth.example.workers.dev");
  assert.deepEqual(config.allowedRoleIds, ["323456789012345678", "423456789012345678"]);
  assert.equal(config.channelIds.discordOauth, "1528706549566935142");
  assert.equal(config.maxTrustedDevices, 2);
  assert.equal(config.deviceTransferCooldownSeconds, 86400);
  assert.equal(config.concurrentNetworkWindowSeconds, 180);
});

test("hasAllowedRole accepts any configured role", () => {
  assert.equal(hasAllowedRole(["423456789012345678"], ["323456789012345678", "423456789012345678"]), true);
  assert.equal(hasAllowedRole(["523456789012345678"], ["323456789012345678"]), false);
});

test("readConfig rejects placeholders", () => {
  assert.throws(() => readConfig({ ...validEnv, DISCORD_CLIENT_ID: "REPLACE_WITH_DISCORD_CLIENT_ID" }));
});

test("readConfig rejects missing audit channel IDs", () => {
  assert.throws(() => readConfig({ ...validEnv, CHANNEL_SECURITY_ALERTS: "" }));
});

test("readConfig rejects unsafe trusted-device limits", () => {
  assert.throws(() => readConfig({ ...validEnv, MAX_TRUSTED_DEVICES: "0" }));
  assert.throws(() => readConfig({ ...validEnv, MAX_TRUSTED_DEVICES: "20" }));
  assert.throws(() => readConfig({ ...validEnv, DEVICE_TRANSFER_COOLDOWN_SECONDS: "60" }));
  assert.throws(() => readConfig({ ...validEnv, CONCURRENT_NETWORK_WINDOW_SECONDS: "10" }));
});
