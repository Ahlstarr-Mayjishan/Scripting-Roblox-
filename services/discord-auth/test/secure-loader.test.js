import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const loaderPath = new URL("../client/secure-loader.template.luau", import.meta.url);

test("secure loader keeps auth state when mobile filesystem APIs are incomplete", async () => {
  const source = await readFile(loaderPath, "utf8");

  assert.match(source, /RUNTIME_AUTH_KEY/);
  assert.match(source, /runtimeEnvironment\[RUNTIME_AUTH_KEY\] = encoded/);
  assert.match(source, /AUTH_FALLBACK_FILE/);
  assert.doesNotMatch(source, /not \(isfile and readfile and isfile/);
  assert.doesNotMatch(source, /not \(makefolder and writefile/);
});
test("secure loader does not delete saved sessions on transient verify failures", async () => {
  const source = await readFile(loaderPath, "utf8");

  assert.match(source, /isTerminalSessionError/);
  assert.match(source, /SESSION_INVALID_OR_EXPIRED/);
  assert.match(source, /Saved login could not be checked; continuing with saved session\./);
  assert.match(source, /not isTerminalSessionError\(verifyError\)/);
});

test("secure loader persists and resumes an unfinished mobile OAuth request", async () => {
  const source = await readFile(loaderPath, "utf8");

  assert.match(source, /pending_auth/);
  assert.match(source, /request_token/);
  assert.match(source, /authorize_url/);
  assert.match(source, /expires_at/);
  assert.match(source, /resumePendingAuthentication/);
  assert.match(source, /writeAuthState\(authState\)/);
});

test("secure loader retries transient mobile network failures", async () => {
  const source = await readFile(loaderPath, "utf8");

  assert.match(source, /isTransientRequestError/);
  assert.match(source, /postWithRetry/);
  assert.match(source, /POLL_RETRY_MAX_SECONDS/);
  assert.doesNotMatch(source, /statusError and statusError ~= "RATE_LIMITED"/);
});

test("secure loader reports whether session storage is durable", async () => {
  const source = await readFile(loaderPath, "utf8");

  assert.match(source, /authStorageMode/);
  assert.match(source, /persistent/);
  assert.match(source, /runtime-only/);
  assert.match(source, /readBackAuthState/);
});
test("secure loader mirrors auth state and reads the newest durable copy", async () => {
  const source = await readFile(loaderPath, "utf8");

  assert.match(source, /state\.revision = \(tonumber\(state\.revision\) or 0\) \+ 1/);
  assert.match(source, /state\.updated_at = os\.time\(\)/);
  assert.match(source, /newestUpdatedAt/);
  assert.match(source, /durableCopies/);
  assert.match(source, /durableCopies > 0/);
});

test("secure loader supports one-time mobile recovery without a reusable key", async () => {
  const source = await readFile(loaderPath, "utf8");

  assert.match(source, /Recovery code/);
  assert.match(source, /ConsumeRecoveryCode/);
  assert.match(source, /\/v1\/auth\/recover/);
  assert.match(source, /device_label/);
  assert.match(source, /DEVICE_LIMIT_REACHED/);
  assert.match(source, /DEVICE_TRANSFER_COOLDOWN/);
  assert.match(source, /NETWORK_REAUTH_REQUIRED/);
});
