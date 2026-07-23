import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const DISCORD_ID = /^\d{17,20}$/;
const [action, discordUserId] = process.argv.slice(2);

if (!["list", "revoke"].includes(action) || !DISCORD_ID.test(discordUserId || "")) {
  console.error("Usage: npm run devices -- <list|revoke> <discord-user-id>");
  process.exit(2);
}

const wranglerPath = fileURLToPath(
  new URL("../node_modules/wrangler/bin/wrangler.js", import.meta.url),
);
const command = action === "list"
  ? `SELECT device_label, first_seen_at, last_seen_at, last_country, last_asn
       FROM trusted_devices
      WHERE discord_user_id = '${discordUserId}' AND revoked_at IS NULL
      ORDER BY last_seen_at DESC;`
  : `UPDATE trusted_devices
        SET revoked_at = unixepoch()
      WHERE discord_user_id = '${discordUserId}' AND revoked_at IS NULL;
     DELETE FROM sessions WHERE discord_user_id = '${discordUserId}';`;

const result = spawnSync(process.execPath, [
  wranglerPath,
  "d1",
  "execute",
  "NULLSCAPE_AUTH",
  "--remote",
  "--command",
  command,
], {
  cwd: fileURLToPath(new URL("..", import.meta.url)),
  stdio: "inherit",
  shell: false,
});

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status ?? 1);
