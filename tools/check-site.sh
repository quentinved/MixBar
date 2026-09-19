#!/bin/bash
# Checks site/ before it ships. Every check here is a way the page breaks while
# still rendering and reporting nothing — the CSP dropping a style="" attribute
# is how the old mockup's sliders all sat at zero in production.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/site"
HTML="$SITE/index.html"

fails=0
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
pass() { printf '  ok    %s\n' "$1"; }

echo "Required files"
for f in index.html styles.css _headers _redirects mark.svg mark-1024.png og.png; do
    if [ -f "$SITE/$f" ]; then pass "$f"; else fail "$f is missing"; fi
done

echo
echo "Content-Security-Policy compatibility"
if grep -q 'style=' "$HTML"; then
    fail "index.html has style=\"\" attributes; style-src has no 'unsafe-inline'"
else
    pass "no inline style attributes"
fi
if grep -qE '<script|\son[a-z]+=' "$HTML"; then
    fail "index.html has script or an event handler; default-src is 'none'"
else
    pass "no scripts or event handlers"
fi
# Only subresources are governed by the CSP: a <link> or a src=, never an <a>.
# rel="canonical" names the site's own origin and fetches nothing.
canonical="$(grep -oE 'rel="canonical" href="https://[a-z.]+' "$HTML" | sed 's|.*https://||')"
for host in $(grep -oE '(<link[^>]+href|src)="https://[a-z.]+' "$HTML" \
              | grep -oE 'https://[a-z.]+' | sed 's|https://||' | sort -u); do
    if [ "$host" = "$canonical" ]; then
        continue
    elif grep -q "$host" "$SITE/_headers"; then
        pass "$host is allowed by the CSP"
    else
        fail "$host is fetched but absent from _headers"
    fi
done
echo
echo "Local references resolve"
# srcset too: a missing dark-mode image is invisible, because the browser just
# falls back to the light one and the page still looks right.
for ref in $(grep -oE '(href|src|srcset)="/[^"]*"' "$HTML" | sed -E 's/.*"(.*)"/\1/' | sort -u); do
    if [ -f "$SITE$ref" ]; then
        pass "$ref"
    elif grep -qE "^${ref}[[:space:]]" "$SITE/_redirects"; then
        pass "$ref (redirect)"
    else
        fail "$ref resolves to neither a file nor a redirect"
    fi
done

echo
echo "Open Graph image"
og_w="$(grep -oE 'og:image:width" content="[0-9]+' "$HTML" | grep -oE '[0-9]+$')"
og_h="$(grep -oE 'og:image:height" content="[0-9]+' "$HTML" | grep -oE '[0-9]+$')"
real="$(file "$SITE/og.png" | grep -oE '[0-9]+ x [0-9]+' | head -1 | tr -d ' ')"
if [ "$real" = "${og_w}x${og_h}" ]; then
    pass "og.png is ${real}, as declared"
else
    fail "og.png is $real but the meta tags declare ${og_w}x${og_h}"
fi

echo
echo "External links"
# A renamed repository or a moved page leaves a dead link nothing else would notice.
for url in $(grep -oE '<a [^>]*href="https://[^"]+' "$HTML" \
              | grep -oE 'https://[^"]+' | sort -u); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' -L --max-time 20 "$url" || echo 000)"
    case "$code" in
        200|429|5??|000) pass "$code $url" ;;
        *) fail "$code $url" ;;
    esac
done

echo
if [ "$fails" -eq 0 ]; then
    echo "site/ is good."
else
    echo "$fails check(s) failed."
fi
exit $(( fails > 0 ))
