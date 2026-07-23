import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const routesPath = new URL("../src/routes.js", import.meta.url);
const repositoryPath = new URL("../src/repository.js", import.meta.url);
const migrationPath = new URL("../migrations/0003_trusted_devices.sql", import.meta.url);
const workflowPath = new URL("../../../.github/workflows/deploy-discord-auth.yml", import.meta.url);
const managementScriptPath = new URL("../scripts/manage-devices.mjs", import.meta.url);

test("trusted-device schema and recovery claims are server-side", async () => {
  const [routes, repository, migration] = await Promise.all([
    readFile(routesPath, "utf8"),
    readFile(repositoryPath, "utf8"),
    readFile(migrationPath, "utf8"),
  ]);

  assert.match(migration, /CREATE TABLE IF NOT EXISTS trusted_devices/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS device_security/);
  assert.match(migration, /resume_code_hash/);
  assert.match(migration, /resume_client_hash/);
  assert.match(routes, /\/v1\/auth\/recover/);
  assert.match(routes, /DEVICE_LIMIT_REACHED/);
  assert.match(repository, /resume_client_hash IS NULL OR resume_client_hash =/);
  assert.match(repository, /releaseRecoveredDevice/);
  assert.match(repository, /claimDeviceTransfer/);
  assert.match(routes, /DEVICE_TRANSFER_COOLDOWN/);
  assert.match(routes, /NETWORK_REAUTH_REQUIRED/);
  assert.match(routes, /allowNetworkChange:\s*true/);
  assert.match(repository, /DELETE FROM sessions[\s\S]*client_hash/);
  assert.match(repository, /COUNT\(\*\)[\s\S]*trusted_devices/);
  assert.doesNotMatch(routes, /ipChanged[\s\S]*throw new HttpError/);
});

test("production deploy applies D1 migrations before publishing the Worker", async () => {
  const workflow = await readFile(workflowPath, "utf8");
  const migrationStep = workflow.indexOf("npm run db:remote");
  const deployStep = workflow.indexOf("npm run deploy");

  assert.ok(migrationStep >= 0);
  assert.ok(deployStep > migrationStep);
});

test("device administration uses Wrangler without opening a public admin endpoint", async () => {
  const [routes, managementScript] = await Promise.all([
    readFile(routesPath, "utf8"),
    readFile(managementScriptPath, "utf8"),
  ]);

  assert.doesNotMatch(routes, /\/v1\/admin\//);
  assert.match(managementScript, /const DISCORD_ID = \/\^\\d\{17,20\}\$\//);
  assert.match(managementScript, /shell:\s*false/);
  assert.match(managementScript, /DELETE FROM sessions/);
});
