#!/bin/bash
# Serves the page the way production does: the same wrangler and the same
# wrangler.jsonc, so _redirects, _headers and the 404 page all apply. Without
# them /download 404s and the CSP is absent, and the page looks fine locally in
# exactly the two ways it can be broken in production.
#
# The build command in wrangler.jsonc runs first and again on every change
# under site/src; reload to see the edit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8080}"
WRANGLER="$ROOT/site/node_modules/.bin/wrangler"

[ -x "$WRANGLER" ] || { echo "install the site's tooling first: npm ci --prefix site" >&2; exit 1; }

cd "$ROOT"
echo "site/ on http://127.0.0.1:$PORT — ctrl-c to stop"
WRANGLER_SEND_METRICS=false exec "$WRANGLER" dev --port "$PORT"
