import assert from "node:assert/strict";
import test from "node:test";

import {
  normalizeRecoveryCode,
  recoveryCodeForState,
  sessionTokenForRequest,
} from "../src/crypto.js";

test("session token derivation is stable for a resumable OAuth exchange", async () => {
  const requestToken = "request-token";
  const clientToken = "client-token";
  const pepper = "a-secure-test-pepper-that-is-long-enough";

  const first = await sessionTokenForRequest(requestToken, clientToken, pepper);
  const second = await sessionTokenForRequest(requestToken, clientToken, pepper);

  assert.equal(first, second);
  assert.match(first, /^[A-Za-z0-9_-]{43}$/);
});

test("session token derivation remains bound to the OAuth request and device", async () => {
  const pepper = "a-secure-test-pepper-that-is-long-enough";
  const baseline = await sessionTokenForRequest("request-a", "client-a", pepper);

  assert.notEqual(await sessionTokenForRequest("request-b", "client-a", pepper), baseline);
  assert.notEqual(await sessionTokenForRequest("request-a", "client-b", pepper), baseline);
  assert.notEqual(
    await sessionTokenForRequest("request-a", "client-a", `${pepper}-rotated`),
    baseline,
  );
});

test("recovery codes are deterministic, human-readable, and normalized", async () => {
  const pepper = "a-secure-test-pepper-that-is-long-enough";
  const code = await recoveryCodeForState("oauth-state", pepper);

  assert.match(code, /^[A-F0-9]{4}(?:-[A-F0-9]{4}){3}$/);
  assert.equal(await recoveryCodeForState("oauth-state", pepper), code);
  assert.equal(normalizeRecoveryCode(code.toLowerCase()), code.replaceAll("-", ""));
  assert.equal(normalizeRecoveryCode(` ${code} `), code.replaceAll("-", ""));
  assert.equal(normalizeRecoveryCode("NOT-A-VALID-CODE"), null);
});
