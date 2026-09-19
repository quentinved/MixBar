#!/bin/bash
# Serves site/ the way Cloudflare Pages does: applying _redirects and _headers.
#
# Without those, /download 404s and the CSP is absent, so the page looks fine
# locally in exactly the two ways it can be broken in production.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8080}"

echo "site/ on http://127.0.0.1:$PORT — ctrl-c to stop"
exec python3 - "$ROOT/site" "$PORT" <<'PY'
import functools, http.server, sys, re

site, port = sys.argv[1], int(sys.argv[2])

redirects = []
for line in open(f"{site}/_redirects"):
    parts = line.split("#")[0].split()
    if len(parts) >= 2:
        redirects.append((parts[0], parts[1], int(parts[2]) if len(parts) > 2 else 302))

# _headers is `pattern` followed by indented `Name: value` lines.
rules, pattern = [], None
for line in open(f"{site}/_headers"):
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    if not line[0].isspace():
        pattern = line.strip()
        rules.append((pattern, []))
    elif rules:
        name, _, value = line.strip().partition(":")
        rules[-1][1].append((name, value.strip()))

def matches(pattern, path):
    return re.fullmatch(re.escape(pattern).replace(r"\*", ".*"), path) is not None

class Handler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        for src, dest, code in redirects:
            if self.path == src:
                self.send_response(code)
                self.send_header("Location", dest)
                self.end_headers()
                return None
        return super().send_head()

    def end_headers(self):
        for pattern, headers in rules:
            if matches(pattern, self.path.split("?")[0]):
                for name, value in headers:
                    self.send_header(name, value)
        super().end_headers()

http.server.HTTPServer(("127.0.0.1", port),
    functools.partial(Handler, directory=site)).serve_forever()
PY
