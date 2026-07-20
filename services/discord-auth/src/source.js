import { SOURCE_BUNDLE_JSON } from "../generated/source-bundle.js";
import { SECURE_LOADER_TEMPLATE } from "../generated/secure-loader.js";

export function sourceBundleResponse() {
  return new Response(SOURCE_BUNDLE_JSON, {
    status: 200,
    headers: {
      "Cache-Control": "no-store, no-cache, must-revalidate, private",
      "Content-Type": "application/json; charset=utf-8",
      "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
      "Cross-Origin-Resource-Policy": "same-site",
      "Pragma": "no-cache",
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
    },
  });
}

export function secureLoaderResponse(publicBaseUrl) {
  const source = SECURE_LOADER_TEMPLATE.replaceAll("__NULLSCAPE_AUTH_BASE_URL__", publicBaseUrl);
  return new Response(source, {
    status: 200,
    headers: {
      "Cache-Control": "no-store, no-cache, must-revalidate",
      "Content-Type": "text/plain; charset=utf-8",
      "Pragma": "no-cache",
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
