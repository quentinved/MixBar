# Repository setup

Everything to configure once, before and just after making the repository
public. Ordered so that nothing is public before it is safe to be.

## 0. Before you make it public

- [ ] **`AuthKey_*.p8` and `*.p12` are in the working tree.** They are covered by
      `.gitignore`, but confirm with `git status --ignored | grep -E '\.p8|\.p12'`
      and `git log --all --name-only | grep -E '\.p8|\.p12'` (should be empty).
      These are your Developer ID private key and App Store Connect key — if
      either has ever been committed, revoke it rather than deleting the commit.
- [x] `CODE_OF_CONDUCT.md` lists **contact@quentinvedrenne.com** as the conduct
      contact. Confirm that mailbox is monitored — it is on a public page and
      will be scraped, so a filter for it is worth setting up.
- [x] Repository name: **`MixBar`**, under `quentinved`. Every URL in this repo
      assumes `github.com/quentinved/MixBar`; `tools/check-site.sh` fails if the
      landing page ever points somewhere that 404s, so a later rename is caught
      rather than shipped.

## 1. About panel

Settings → General, or the gear beside **About** on the repo home page.

**Description.** The limit is 350 characters, but the About panel renders as a
narrow sidebar column — anything past about a line reads as a wall. One sentence,
carrying the strings people search (`per-app volume`, `macOS`, `menu bar`):

```
Per-app volume for macOS. A slider in your menu bar for every app that's making noise.
```

Everything else — the taps, the empty audio path, the permission — is what the
README is for. The description's only job is to get someone to open it.

**Website:** `https://mixbar.app` (or the `*.pages.dev` URL until the domain is live).

**Topics** — add all of these; topic pages are a real discovery channel:

```
macos  swift  swiftui  audio  volume-control  per-app-volume
coreaudio  audio-mixer  menubar  menu-bar-app  macos-app  open-source
```

**Social preview:** Settings → General → Social preview → upload `site/og.png`.
Without it, shared links show a generic grey box.

## 2. Features

Settings → General → Features.

| Feature | Setting | Why |
| --- | --- | --- |
| Issues | **On** | The bug template needs it |
| Discussions | **On** | Referenced from `.github/ISSUE_TEMPLATE/config.yml` |
| Wiki | Off | The README is the documentation |
| Projects | Off until there is a roadmap worth tracking | |
| Sponsorships | Your call — a `.github/FUNDING.yml` adds the Sponsor button | |

Pull Requests → enable **Allow squash merging** only, and tick **Automatically
delete head branches**. A linear history is much easier to bisect when an audio
regression appears three releases later.

## 3. Security

Settings → Advanced Security (some of these are on by default for public repos;
confirm each one).

- [ ] **Private vulnerability reporting: On.** `SECURITY.md` links straight to it.
- [ ] **Secret scanning: On**, and **Push protection: On** — this is the one that
      would stop a `.p8` being pushed by accident.
- [ ] **Dependabot alerts: On.** MixBar has no package dependencies, but the
      GitHub Actions it uses do get advisories.

## 4. Actions

Settings → Actions → General.

- **Workflow permissions: Read repository contents**. `release.yml` requests the
  write scope it needs in the workflow file itself, so the default stays narrow.
- Leave **Allow all actions** unless you want to pin an allowlist; the workflows
  use `actions/checkout`, `softprops/action-gh-release` and
  `cloudflare/wrangler-action`.

### Secrets and variables

Settings → Secrets and variables → Actions.

| Name | Kind | For | Where it comes from |
| --- | --- | --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Secret | Release | Keychain Access → export the Developer ID Application identity → `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_P12_PASSWORD` | Secret | Release | The password you set on that export |
| `NOTARY_KEY_P8_BASE64` | Secret | Release | App Store Connect → Users and Access → Integrations → Keys. **Downloadable once only** → `base64 -i AuthKey_XXX.p8 \| pbcopy` |
| `NOTARY_KEY_ID` | Secret | Release | Shown next to the key |
| `NOTARY_ISSUER_ID` | Secret | Release | Same page, above the key list |
| `CLOUDFLARE_API_TOKEN` | Secret | Site | Cloudflare → My Profile → API Tokens → **Cloudflare Pages: Edit** |
| `CLOUDFLARE_ACCOUNT_ID` | Secret | Site | Cloudflare dashboard URL, or the right-hand column of the account home |
| `CLOUDFLARE_PROJECT` | **Variable** | Site | The Pages project name, e.g. `mixbar`. `site.yml` skips entirely while this is unset |

## 5. Branch protection

Settings → Rules → Rulesets → New branch ruleset, targeting `main`:

- Require a pull request before merging (1 approval — set to 0 while you are the
  only maintainer, so you are not blocked on yourself)
- **Require status checks to pass** → add the `test` job from `Test`
- Require branches to be up to date before merging
- Block force pushes

Do not tick "Require signed commits" unless you have commit signing set up
already; it rejects contributions from people who don't, with an error most
first-time contributors cannot diagnose.

## 6. Labels

The templates apply `bug` and `enhancement`, which exist by default. Worth adding:

| Label | Colour | For |
| --- | --- | --- |
| `good first issue` | `#7057ff` | Exists by default — **use it**, it feeds GitHub's contributor discovery pages |
| `help wanted` | `#008672` | Exists by default |
| `core-audio` | `#6B5CF2` | Touches taps, aggregate devices or the IOProc — needs careful review |
| `needs-hardware` | `#9E3DE3` | Cannot be reproduced or tested on CI |
| `permission` | `#d4c5f9` | TCC / audio-capture grant problems, the most common report |

Tag the four unbuilt features from the README's Status section as
`good first issue` + `help wanted` the day you go public. An empty issue tracker
gives a visitor nothing to do.

## 7. Cloudflare Pages

Deployed from Cloudflare's own Git integration, which needs no GitHub secrets:

1. Cloudflare dashboard → **Workers & Pages** → Create → **Pages** → Connect to Git.
2. Authorise GitHub and pick the `MixBar` repository.
3. Build settings: **Framework preset** None, **Build command** empty,
   **Build output directory** `site`. Leave the root directory alone.
4. Deploy. You land on `mixbar.pages.dev`, and every PR gets a preview URL.
5. Settings → **Builds & deployments** → **Build watch paths** → set *Include
   paths* to `site/*`. Without this a Swift-only commit still triggers a rebuild
   and a new deployment, which makes the deployment list useless for working out
   when the page last actually changed.

`site/_redirects` then makes `/download` always point at the newest GitHub
release, so the download button never needs touching on a version bump.
`site/_headers` sets the CSP and cache policy.

**Cloudflare does not wait for GitHub Actions.** A push to `main` deploys whether
or not the `check` job in `site.yml` passed, so that job reports rather than
gates. The gate is §5's branch protection: require the `check` status on pull
requests and merge only through them, and `main` is never broken in the first
place.

**Custom domain:** Pages project → Custom domains → add `mixbar.app`. If the
domain is registered with Cloudflare the records are created for you; otherwise
add the `CNAME` they display. Until then the page's `canonical`, `og:url` and
`og:image` all hard-code `https://mixbar.app/`, so launching on `*.pages.dev`
first means changing those three or shipping dead link previews. Then update the
About panel's Website field.

If you would rather deploy from CI instead, set the three Cloudflare entries in
the table above and the `deploy` job in `.github/workflows/site.yml` takes over —
it gates on `check`, but you lose PR previews.

## 8. Release

```sh
git tag v0.2 && git push origin v0.2
```

`release.yml` builds, signs, notarizes, staples, verifies Gatekeeper, publishes
the release, and prints the Homebrew cask. Nothing else to do by hand.

A Homebrew cask needs somewhere to live before `brew install --cask mixbar`
works: either a personal tap (`quentinved/homebrew-tap`) or a PR to
`homebrew/homebrew-cask`, which requires the app to be notarized and reasonably
established. Until one exists, **do not advertise the brew command anywhere** —
the download link is the only install path that works today.
