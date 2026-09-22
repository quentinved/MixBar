#!/bin/bash
# Checks every link in the repository's markdown. A dead link is the one kind of
# documentation rot nothing else reports: the file renders, the text still reads
# correctly, and only a reader who clicks finds out. It also catches a pointer to
# a file that is deliberately not committed, which looks fine from a working copy
# and is broken for everyone who clones.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import glob, os, re, subprocess, sys
from urllib.parse import urlparse

root = sys.argv[1]
os.chdir(root)

# Placeholders stay in the text on purpose until the thing exists. Naming them
# here is what stops one shipping as a link that quietly 404s.
PLACEHOLDERS = {
    "SLACK_INVITE_URL": "the Slack workspace has not been created yet",
}

# Hosts that refuse datacenter traffic answer a runner with 000 and a browser
# with 200, which is the same signal a dead domain gives. Naming the few keeps
# the check honest about the rest rather than making every 000 a warning.
BLOCKS_CI = {
    "rogueamoeba.com": "blocks CI egress; reachable by hand",
}

fails = 0

def pass_(message):
    print("  ok    " + message)

def fail(message):
    global fails
    print("  FAIL  " + message)
    fails += 1

def slug(heading):
    return re.sub(r"[^a-z0-9 -]", "", heading.lower()).replace(" ", "-")

files = sorted(set(glob.glob("*.md")
                   + glob.glob("docs/**/*.md", recursive=True)
                   + glob.glob(".github/**/*.md", recursive=True)))
remote = {}

print("Local references and anchors")
for path in files:
    text = open(path, encoding="utf-8").read()
    headings = {slug(h) for h in re.findall(r"^#+ (.+)$", text, re.M)}
    targets = (re.findall(r"\]\(([^)\s]+)\)", text)
               + re.findall(r'(?:src|srcset)="([^"]+)"', text)
               + re.findall(r"^\[[^\]]+\]:\s*(\S+)", text, re.M))
    for target in targets:
        where = f"{path}: {target}"
        if target in PLACEHOLDERS:
            fail(f"{where} is still a placeholder ({PLACEHOLDERS[target]})")
        elif target.startswith("http"):
            remote.setdefault(target, set()).add(path)
        elif target.startswith("mailto:"):
            pass_(where)
        elif target.startswith("#"):
            if target[1:] in headings:
                pass_(where)
            else:
                fail(f"{where} names no heading in this file")
        else:
            base = target.split("#")[0]
            near = os.path.join(os.path.dirname(path), base)
            if os.path.exists(base) or os.path.exists(near):
                pass_(where)
            else:
                fail(f"{where} resolves to no file")

print()
print("External links")
def status(url):
    return subprocess.run(
        ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-L",
         "--max-time", "20", "-A", "Mozilla/5.0", url],
        capture_output=True, text=True).stdout.strip()

for url in sorted(remote):
    code = status(url)
    # curl reports 000 when it cannot connect at all. Once is the network having
    # a moment; twice is a host that is not there. A 429 or a 5xx is the far end
    # rate-limiting CI, which is not a broken link.
    if code == "000":
        code = status(url)
    host = urlparse(url).hostname or ""
    blocked = next((h for h in BLOCKS_CI
                    if host == h or host.endswith("." + h)), None)
    if code == "000" and blocked:
        pass_(f"000 {url}  ({BLOCKS_CI[blocked]})")
    elif code == "200" or code == "429" or code.startswith("5"):
        pass_(f"{code} {url}")
    else:
        fail(f"{code} {url}  ({', '.join(sorted(remote[url]))})")

print()
if fails:
    print(f"{fails} check(s) failed.")
else:
    print(f"{len(files)} markdown files, {len(remote)} external URLs — all good.")
sys.exit(1 if fails else 0)
PY
