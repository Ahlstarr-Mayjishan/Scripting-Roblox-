import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const routesPath = new URL("../src/routes.js", import.meta.url);
const repositoryPath = new URL("../src/repository.js", import.meta.url);

test("approved OAuth requests can safely return the same session more than once", async () => {
  const routes = await readFile(routesPath, "utf8");
  const repository = await readFile(repositoryPath, "utf8");

  assert.match(routes, /sessionTokenForRequest/);
  assert.doesNotMatch(routes, /consumeApprovedRequest/);
  assert.match(repository, /INSERT OR IGNORE INTO sessions/);
  assert.match(repository, /export async function createSession[\s\S]*?return db\.prepare/);
});
