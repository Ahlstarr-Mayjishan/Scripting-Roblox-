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
