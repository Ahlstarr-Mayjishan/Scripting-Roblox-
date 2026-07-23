const SECURITY_HEADERS = {
  "Cache-Control": "no-store",
  "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
};

export function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...SECURITY_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}

export function html(title, message, success) {
  const color = success ? "#38d67a" : "#ff5d73";
  const body = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>${escapeHtml(title)}</title><style>
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#111214;color:#eee;font:16px system-ui,sans-serif}
main{width:min(520px,calc(100% - 40px));border:1px solid #34363b;padding:28px;background:#1c1d21;border-radius:8px}
h1{margin:0 0 12px;font-size:24px;color:${color}}p{margin:0;color:#c9cbd1;line-height:1.5}
</style></head><body><main><h1>${escapeHtml(title)}</h1><p>${escapeHtml(message)}</p></main></body></html>`;
  return new Response(body, {
    status: success ? 200 : 403,
    headers: { ...SECURITY_HEADERS, "Content-Type": "text/html; charset=utf-8" },
  });
}

export function approvalHtml(recoveryCode) {
  const body = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>NULLSCAPE Login approved</title><style>
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#111214;color:#eee;font:16px system-ui,sans-serif}
main{width:min(520px,calc(100% - 40px));border:1px solid #34363b;padding:28px;background:#1c1d21;border-radius:8px}
h1{margin:0 0 12px;font-size:24px;color:#38d67a}p{color:#c9cbd1;line-height:1.5}
code{display:block;margin-top:16px;padding:14px;text-align:center;letter-spacing:.12em;font:700 20px ui-monospace,monospace;background:#111214;border:1px solid #484b52;color:#78c8ff;user-select:all}
</style></head><body><main><h1>Login approved</h1>
<p>Return to Roblox. If Roblox was closed by your phone, run the loader again and enter this one-time recovery code:</p>
<code>${escapeHtml(recoveryCode)}</code>
<p>The code expires with this login request and can only be claimed by one device.</p>
</main></body></html>`;
  return new Response(body, {
    status: 200,
    headers: { ...SECURITY_HEADERS, "Content-Type": "text/html; charset=utf-8" },
  });
}

export function loginInfoHtml(publicBaseUrl) {
  const loaderUrl = `${publicBaseUrl}/loader?v=${Date.now()}`;
  const body = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>NULLSCAPE Login</title><style>
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#111214;color:#eee;font:16px system-ui,sans-serif}
main{width:min(620px,calc(100% - 40px));border:1px solid #34363b;padding:28px;background:#1c1d21;border-radius:8px}
h1{margin:0 0 12px;font-size:24px}p{color:#c9cbd1;line-height:1.55}code{display:block;overflow-wrap:anywhere;padding:14px;background:#111214;border:1px solid #34363b;color:#78c8ff}
</style></head><body><main><h1>NULLSCAPE Login</h1>
<p>Discord login is paired to the Roblox client that started it. Run the loader below; NULLSCAPE will display the authorization link and continue automatically after approval.</p>
<code>loadstring(game:HttpGet(&quot;${escapeHtml(loaderUrl)}&quot;))()</code>
<p>This page never asks for a Discord password or stores a Discord access token.</p>
</main></body></html>`;
  return new Response(body, {
    headers: { ...SECURITY_HEADERS, "Content-Type": "text/html; charset=utf-8" },
  });
}

export async function readJson(request, maxBytes = 2048) {
  const contentLength = Number(request.headers.get("content-length") || 0);
  if (contentLength > maxBytes) throw new HttpError(413, "REQUEST_TOO_LARGE");
  const text = await request.text();
  if (text.length > maxBytes) throw new HttpError(413, "REQUEST_TOO_LARGE");
  try {
    return text === "" ? {} : JSON.parse(text);
  } catch {
    throw new HttpError(400, "INVALID_JSON");
  }
}

export class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
