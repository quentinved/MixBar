#!/bin/bash
# Checks the built page before it ships. Every check here is a way the page
# breaks while still rendering and reporting nothing — the CSP dropping a
# style="" attribute is how the old mockup's sliders all sat at zero in
# production, and a canonical naming a host that does not resolve is how the
# real URL stays out of the index.
#
# Runs against site/dist: build first with `npm run build --prefix site`.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/site/dist"
HTML="$SITE/index.html"
PAGES="index.html 404.html"

[ -f "$HTML" ] || { echo "no build in site/dist — run: npm run build --prefix site" >&2; exit 1; }

fails=0
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
pass() { printf '  ok    %s\n' "$1"; }

echo "Required files"
for f in index.html 404.html _headers _redirects mark.svg mark-1024.png og.png \
         robots.txt sitemap.xml; do
    if [ -f "$SITE/$f" ]; then pass "$f"; else fail "$f is missing"; fi
done

echo
echo "Content-Security-Policy compatibility"
for page in $PAGES; do
    if grep -q ' style=' "$SITE/$page"; then
        fail "$page has style=\"\" attributes; style-src has no 'unsafe-inline'"
    else
        pass "$page: no inline style attributes"
    fi
    if grep -q '<style' "$SITE/$page"; then
        fail "$page has a <style> block; style-src has no 'unsafe-inline'"
    else
        pass "$page: no inline stylesheet"
    fi
    # ld+json is a data block the parser never executes, and a module under
    # /_astro/ is a file that script-src 'self' allows. Anything else is inline,
    # and the CSP drops it on the floor.
    if grep -oE '<script[^>]*>' "$SITE/$page" \
        | grep -vE '^<script type="application/ld\+json">$' \
        | grep -qvE '^<script type="module" src="/_astro/[^"]+"></script>$|^<script type="module" src="/_astro/[^"]+">$'; then
        fail "$page has an inline script; script-src is 'self'"
    elif grep -qE '\son[a-z]+=' "$SITE/$page"; then
        fail "$page has an inline event handler; script-src is 'self'"
    else
        pass "$page: every script is a hashed file under /_astro/"
    fi
done
# img-src is 'self', which excludes data: URIs, CSS masks and backgrounds
# included. They render in any preview that lacks the header and nowhere else,
# which is how the demo's app icons went blank in production.
if grep -qE 'url\(["'"'"']?data:' "$SITE"/_astro/*.css $(printf "$SITE/%s " $PAGES); then
    fail "a stylesheet or page loads a data: URI; img-src is 'self'"
else
    pass "no data: URIs for the CSP to block"
fi
# Only subresources are governed by the CSP: a <link> or a src=, never an <a>.
# rel="canonical" names the site's own origin and fetches nothing.
canonical="$(grep -oE 'rel="canonical" href="https://[a-z.]+' "$HTML" | sed 's|.*https://||')"
for host in $(grep -hoE '(<link[^>]+href|src)="https://[a-z.]+' $(printf "$SITE/%s " $PAGES) \
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
# A fragment on the home page is the home page; a missing font or script is
# invisible, because the page falls back to a system face and a still demo.
# srcset carries several candidates with density descriptors, "/a.avif 1x, /b.avif 2x".
for ref in $(grep -hoE '(href|src|srcset)="/[^"]*"' $(printf "$SITE/%s " $PAGES) \
             | sed -E 's/.*"(.*)"/\1/' | tr ',' '\n' | sed -E 's/^ *//; s/ [0-9.]+[xw]$//' | sort -u); do
    path="${ref%%#*}"
    if [ -f "$SITE$path" ] || [ -z "$path" ] || [ "$path" = "/" ]; then
        pass "$ref"
    elif grep -qE "^${path}[[:space:]]" "$SITE/_redirects"; then
        pass "$ref (redirect)"
    else
        fail "$ref resolves to neither a file nor a redirect"
    fi
done
for ref in $(grep -hoE 'url\(/_astro/[^)]+\)' "$SITE"/_astro/*.css | sed -E 's/url\((.*)\)/\1/' | sort -u); do
    if [ -f "$SITE$ref" ]; then pass "$ref"; else fail "$ref is named in a stylesheet but was not emitted"; fi
done

echo
echo "Search metadata"
# Every one of these agrees with rel="canonical" or it is worse than absent:
# a sitemap or an og:url on a second hostname splits the page in two.
og_url="$(grep -oE 'og:url" content="https://[a-z.]+' "$HTML" | sed 's|.*https://||')"
if [ -n "$canonical" ]; then pass "canonical is $canonical"; else fail "no rel=canonical"; fi
if [ "$og_url" = "$canonical" ]; then
    pass "og:url matches the canonical host"
else
    fail "og:url is $og_url but the canonical is $canonical"
fi
if grep -q "<loc>https://$canonical/</loc>" "$SITE/sitemap.xml"; then
    pass "sitemap.xml lists the canonical URL"
else
    fail "sitemap.xml does not list https://$canonical/"
fi
if grep -qx "Sitemap: https://$canonical/sitemap.xml" "$SITE/robots.txt"; then
    pass "robots.txt points at the sitemap"
else
    fail "robots.txt does not point at https://$canonical/sitemap.xml"
fi
if grep -q 'name="robots" content="noindex' "$SITE/404.html"; then
    pass "404.html is noindex"
else
    fail "404.html is indexable; every mistyped URL becomes a page"
fi
if command -v python3 >/dev/null; then
    python3 - "$HTML" "$canonical" <<'PY'
import html as entities, json, re, sys
page = open(sys.argv[1], encoding="utf-8").read()
canonical = sys.argv[2]

def check(ok, message):
    print(("  ok    " if ok else "  FAIL  ") + message)
    return 0 if ok else 1

bad = 0
title = entities.unescape(re.search(r"<title>(.*?)</title>", page, re.S).group(1))
bad += check(len(title) <= 60, f"title is {len(title)} chars (Google truncates past ~60)")
desc = entities.unescape(re.search(r'name="description" content="(.*?)"', page, re.S).group(1))
bad += check(120 <= len(desc) <= 160, f"meta description is {len(desc)} chars (want 120-160)")

blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', page, re.S)
kinds = {}
for block in blocks:
    try:
        data = json.loads(block)
    except json.JSONDecodeError as error:
        bad += check(False, f"JSON-LD does not parse: {error}")
    else:
        kinds[data.get("@type")] = data
app = kinds.get("SoftwareApplication")
bad += check(app is not None, "JSON-LD describes a SoftwareApplication")
if app:
    bad += check(app.get("url") == f"https://{canonical}/", "JSON-LD url matches the canonical")
    bad += check(bool(app.get("softwareVersion")), f"JSON-LD carries the version ({app.get('softwareVersion')})")
questions = kinds.get("FAQPage", {}).get("mainEntity", [])
bad += check(len(questions) >= 5, f"JSON-LD FAQPage lists {len(questions)} questions")
bad += check(all(q.get("acceptedAnswer", {}).get("text") for q in questions), "every FAQ answer has text")
sys.exit(1 if bad else 0)
PY
    [ $? -eq 0 ] || fails=$((fails + 1))
else
    echo "  skip  python3 is absent; JSON-LD and length checks not run"
fi

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
echo "Redirect targets"
# The download button is a redirect, so nothing in the page names the file: a
# release missing the version-less MixBar.dmg breaks it while the page looks fine.
for target in $(awk '$1 ~ /^\// && $2 ~ /^https:/ { print $2 }' "$SITE/_redirects"); do
    code="$(curl -s -o /dev/null -w '%{http_code}' -IL --max-time 25 "$target")"
    case "$code" in
        200|429|5??) pass "$code $target" ;;
        *) fail "$code $target" ;;
    esac
done

echo
echo "External links"
# A renamed repository or a moved page leaves a dead link nothing else would notice.
for url in $(grep -hoE '<a [^>]*href="https://[^"]+' $(printf "$SITE/%s " $PAGES) \
              | grep -oE 'https://[^"]+' | sed 's/&amp;/\&/g' | sort -u); do
    code="$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 20 "$url")"
    # curl already reports 000 when it cannot connect. Once is the network
    # having a moment; twice is a domain that is not there.
    if [ "$code" = "000" ]; then
        sleep 2
        code="$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 20 "$url")"
    fi
    case "$code" in
        200|429|5??) pass "$code $url" ;;
        *) fail "$code $url" ;;
    esac
done

echo
if [ "$fails" -eq 0 ]; then
    echo "site/dist is good."
else
    echo "$fails check(s) failed."
fi
exit $(( fails > 0 ))
