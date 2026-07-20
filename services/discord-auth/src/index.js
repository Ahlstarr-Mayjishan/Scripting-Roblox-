import { readConfig } from "./config.js";
import { sendDiscordLog } from "./discord.js";
import { HttpError, json } from "./http.js";
import { cleanupExpired } from "./repository.js";
import { route } from "./routes.js";

export default {
  async fetch(request, env, ctx) {
    try {
      return await route(request, env, readConfig(env), ctx);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: { code: error.code } }, error.status);
      }
      console.error("Unhandled auth worker error", error instanceof Error ? error.message : "unknown");
      return json({ error: { code: "INTERNAL_ERROR" } }, 500);
    }
  },

  async scheduled(_event, env, ctx) {
    const config = readConfig(env);
    ctx.waitUntil((async () => {
      await cleanupExpired(env.DB, Math.floor(Date.now() / 1000));
      await sendDiscordLog(
        config,
        "systemHealth",
        "Daily auth cleanup completed | service=nullscape-discord-auth",
      ).catch((error) => {
        console.error("Discord health log failed", error instanceof Error ? error.message : "unknown");
      });
    })());
  },
};
