<div align="center">

<img src="docs/brand/mark.svg" width="120" height="120" alt="">

# MixBar

**Per-app volume for Mac.**

A slider for every app that's making noise, in the menu bar, plus quick
output-device switching. Free and open source.

[![Tests](https://github.com/quentinvedrenne/mixbar/actions/workflows/test.yml/badge.svg)](https://github.com/quentinvedrenne/mixbar/actions/workflows/test.yml)
[![Latest release](https://img.shields.io/github/v/release/quentinvedrenne/mixbar?color=6B5CF2)](https://github.com/quentinvedrenne/mixbar/releases/latest)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-6B5CF2)](https://github.com/quentinvedrenne/mixbar/releases/latest)
[![MIT licence](https://img.shields.io/badge/licence-MIT-9E3DE3)](LICENSE)

[Download](https://github.com/quentinvedrenne/mixbar/releases/latest) ·
[Website](https://mixbar.app) ·
[Contributing](CONTRIBUTING.md) ·
[Security](SECURITY.md)

</div>

At default volume MixBar stays completely out of your audio path — it creates no
taps and no aggregate device until you actually move a slider.

## Install

Download the `.dmg` from Releases and drag MixBar to Applications.

macOS asks once for permission to record audio. That permission is the whole
mechanism — see below.

Requires macOS 15 or later.

## Using it

Click the slider icon in the menu bar. Apps appear as they start making sound.

| What you want | How |
| --- | --- |
| Change one app's volume | Drag its slider, or click anywhere on the track to jump there |
| Mute one app | Click the speaker icon on its row |
| Unmute | Click it again, or drag the slider up — the old level comes back |
| Undo everything | `…` → **Reset all volumes** |
| Switch output device | Click the device name at the top |
| See apps that are not currently playing | `…` → **Show idle apps** |

**Three layouts**, from the segmented control at the top:

- **Compact** — one line per app, to see the most at once.
- **Comfortable** — icon, name and a full-width slider. The default.
- **Mixer** — vertical faders side by side, like a mixing desk.

The bright band inside each slider is a live level meter. It reads the signal
*after* your gain is applied, so it can never exceed the fill — what you see is
what is actually reaching your speakers.

Volumes are remembered per app by bundle ID, so quitting Spotify and reopening
it keeps the level you set. Settings survive a restart.

### If an app does not appear

MixBar can only list apps that hold an output stream open. If something is
playing but missing, it is almost always the permission: `…` → **Audio
permission…** opens the right pane in System Settings. Grant **Audio
Recording** and reopen the menu.

A missing grant is silent by design in Core Audio — the tap is created, the
render callback runs, and every buffer is zeros. There is no error to show you.

## Why it needs "audio recording" permission

macOS has no per-app volume API. The only way to change one app's volume is to
capture that app's audio and play it back yourself at a different level. Apple
classifies reading another app's sound as recording, under the same umbrella as
the microphone — so MixBar needs the **Audio Recording** permission
(`kTCCServiceAudioCapture`), even though it never touches your microphone.

## How it works

1. Enumerate audio processes via `AudioHardwareSystem.shared.processes`.
2. Group them by owning application, because browsers and Electron apps play
   through anonymous helper processes rather than themselves.
3. For an app you have adjusted, create one `CATapDescription` spanning all of
   its processes, marked `isPrivate` with `muteBehavior = .mutedWhenTapped`.
   That silences the app's own path to the speakers while we are reading it, so
   our gain becomes its volume.
4. Put the default output device and every tap into one private aggregate
   device, and run a single IOProc that applies per-app gain and sums the
   result.

No kernel extension, no virtual audio driver, no installer privileges.

**At default volume, MixBar creates nothing at all.** No taps, no aggregate
device, no presence in the audio path. An app enters the audio path only once
its slider moves, and leaves the moment it returns to 100%. This matters: an
earlier version routed everything through the mixer and caused audible
crackling system-wide, even while mixing pure silence.

## Architecture

Hexagonal (ports and adapters). The core holds the mixing rules and imports no
frameworks at all; everything external arrives through a port.

```
app/Sources/MixBar/
├── Domain/          AudioApplication, AppMix, MixerLayout, MixerSnapshot,
│                    MixerService — the rules. Imports Foundation, nothing else.
├── Ports/           DrivenPorts (catalog, engine, outputs, settings)
│                    MixerControlling (driving port: all a UI may touch)
├── Adapters/
│   ├── CoreAudio/   taps, aggregate device, device switching
│   │                RealtimeMixer.swift is the IOProc: no allocation, no locks
│   ├── Persistence/ UserDefaults
│   └── UI/          SwiftUI menu bar popover, three row layouts
└── MixBarApp.swift  composition root
```

`ProcessRegistry` is the seam that makes this work: it maps the domain's
`AudioAppID` to the several Core Audio process objects behind it, so
`AudioObjectID` never appears above the adapter layer. Every port has a fake, so
the rules are tested without an audio device, an output, or a permission prompt.

The package is `swift-tools-version: 6.0` but pins `.swiftLanguageMode(.v5)`:
the core is single-threaded and driven entirely from the main actor, and
adopting full Swift 6 concurrency would mean annotating the driving port
`@MainActor` — worth doing, not yet done.

## Contributing

Contributions are welcome, and [CONTRIBUTING.md](CONTRIBUTING.md) is the place
to start — it covers the build loop, the one architectural rule, and the Core
Audio traps that will otherwise cost you an afternoon. The items under
[Status](#status) that are not done yet are where help goes furthest.

By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Security
problems go through [SECURITY.md](SECURITY.md), privately, not as a public issue.

The rest of this section is the detail behind that guide.

## Development

Everything is SwiftPM and the macOS SDK — no third-party dependencies, no
Xcode project file. You need Xcode 16 or later (for the macOS 15 SDK) and
macOS 15 to run it.

```sh
git clone https://github.com/quentinvedrenne/mixbar.git
cd mixbar/app
swift test                  # 33 tests, no audio hardware needed
./build.sh                  # -> build/MixBar.app
open ../build/MixBar.app
```

`swift run` is not enough: **an unbundled binary never gets the permission
prompt**, and an ungranted tap returns silence rather than an error, so the
failure is invisible. Always test through the `.app` that `build.sh` produces.

Launch it from Finder or `open`, not from your editor's terminal — running it
from a VS Code terminal records the permission grant against VS Code.

### The build/run loop

```sh
cd app && ./build.sh && open ../build/MixBar.app
```

Ad-hoc signing changes identity on every rebuild, so macOS re-prompts for audio
permission each time. Pass a real certificate to make the grant stick:

```sh
SIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" ./build.sh
```

Quit from the menu (`…` → **Quit**), never with `kill -9`. Taps and aggregate
devices registered with `coreaudiod` outlive the process; `SIGKILL` skips
teardown and leaves them orphaned in the audio path. If that happens,
`spike/` can list and remove them, or `sudo killall coreaudiod` clears them.

### Debugging

`os_log` from an ad-hoc-signed app does not survive to `log show`, and `open`
discards stderr, so there is a file log instead:

```sh
defaults write com.quentinvedrenne.MixBar debugLogging -bool true
tail -f ~/Library/Logs/MixBar.log
# or, for one run:  MIXBAR_DEBUG=1 build/MixBar.app/Contents/MacOS/MixBar
```

It is off by default and the messages are built lazily, so a release build does
no work for logging it will not write.

### Where to put things

The architecture is hexagonal and the dependency rule is enforced by review:

- A new **rule** (when an app is routed, what a mute means) goes in `Domain/`,
  which imports `Foundation` and nothing else.
- A new **need** (something the core wants from the outside world) is a method
  on a port in `Ports/`, plus a fake in `Tests/MixBarTests/Fakes.swift`.
- A new **mechanism** (Core Audio, UserDefaults, SwiftUI) goes in `Adapters/`.

If you find yourself importing `CoreAudio` or `SwiftUI` inside `Domain/`, the
design has gone wrong rather than the rule. `CLAUDE.md` has the full
conventions, including the real-time thread constraints.

### Tests

`swift test` must pass with no audio device, no output and no permission grant
— CI depends on it. Three suites:

- **Mixer rules** — the domain, driven through `MixerService` against the fakes.
- **Render thread** — `renderMix` is a free function over raw buffers, so the
  IOProc's arithmetic is tested by hand-building `AudioBufferList`s. No device
  is involved, and the gain, summing, peak and buffer-layout cases are covered.
- **Settings storage** — the `UserDefaults` round-trip, in a throwaway domain,
  including the plist type coercion that makes a stored volume come back as an
  `Int` or a `String`.

Never add a test that needs Core Audio. Name tests as the behaviour they
protect.

### Style

Enforced by [SwiftLint](https://github.com/realm/SwiftLint) against
`.swiftlint.yml` — notably `function_body_length` (warn at 50 lines, error at
100) and `line_length` (100 characters):

```sh
brew install swiftlint && swiftlint
```

Comments explain *why*, not *what*. The hard-won knowledge in this project is
all non-obvious, and the section below is most of it.

### The spike

`spike/` is a standalone CLI that answered "do process taps actually work on
this machine?" before any of the app existed. It is kept because it is still
the fastest way to diagnose a tap problem, and it is excluded from linting: it
is a preserved experiment, not shipped code.

```sh
cd spike && ./build.sh
./audiotap-spike.app/Contents/MacOS/audiotap-spike list
./audiotap-spike.app/Contents/MacOS/audiotap-spike tap <pid> --gain 0.05
./audiotap-spike.app/Contents/MacOS/audiotap-spike cleanup --destroy
```

### Packaging

```sh
tools/package.sh            # -> dmg, pkg, Homebrew cask
tools/release.sh            # the above, signed + notarized + stapled
```

## Things that cost time to discover

**Missing permission is silent.** Without `kTCCServiceAudioCapture` the tap is
created, the IOProc runs, and every buffer is zeros. No error anywhere, and
there is no permission-check API in CoreAudio. Do not try to infer denial from
silence either — apps that hold a permanently silent stream open make that
inference fire constantly.

**A command-line tool cannot get the prompt.** An unbundled binary never even
creates a TCC entry. The same binary inside a `.app` blocks in
`AudioDeviceCreateIOProcIDWithBlock` waiting for the prompt.

**Launching from a terminal misattributes the grant.** Run from a VS Code
terminal, the permission is recorded against VS Code, not your app.

**Holding an output stream open is not the same as playing.** Teams, FaceTime
and a dozen Apple daemons report `isRunningOutput == true` forever while
emitting silence.

**Browsers do not play their own audio.** Netflix in Arc comes from
`company.thebrowser.browser.helper`, and there is more than one helper — mute
the wrong one and the audio simply moves to the next. One tap must span all of
an app's processes.

**Building taps blocks.** It is IPC with `coreaudiod`, takes ~1.8s, and blocks
indefinitely the first time while the prompt waits. Never on the main thread.

**A menu bar popover freezes default-mode timers.** `MenuBarExtra` in `.window`
style puts the run loop into event tracking, so `Timer.scheduledTimer` stops
firing exactly while the user is looking at it. Use `.common` mode, and drive
the view's state from the publisher explicitly.

**Kill it gently.** Taps and aggregate devices registered with `coreaudiod`
outlive the process. `SIGKILL` skips teardown and leaves them orphaned in the
audio path, and only `sudo killall coreaudiod` clears them.

## Status

Working: per-app volume, mute, live meters, output switching, persistence by
bundle ID, app grouping.

Not done yet: sleep/wake handling, launch at login, global hotkeys, per-app
output routing, and a Homebrew tap for the cask that `tools/package.sh` emits.

## Releasing

Public distribution needs a **Developer ID Application** certificate (paid Apple
Developer Program) and notarization. Keychain profile names must be at least
three characters.

```sh
xcrun notarytool store-credentials mixbar-notary \
    --apple-id you@example.com --team-id <your-team-id> --password <app-specific-password>

tools/release.sh        # builds, signs, notarizes, staples, then checks Gatekeeper
```

`release.sh` picks up the Developer ID Application certificate from the keychain
itself, so there is nothing to pass on the command line.

Two details that will otherwise cost you a failed release:

- **Notarization requires a secure timestamp.** `build.sh` passes
  `--timestamp` whenever it signs with a Developer ID, and `--timestamp=none`
  otherwise, because an ad-hoc signature cannot carry one and a dev build
  should not need a network round-trip. Signing a release without it gets the
  upload rejected with *"The signature does not include a secure timestamp."*
- **The `.pkg` needs a second certificate.** Installer packages are signed with
  a **Developer ID Installer** certificate, which is not the same as the
  Application one. Without it `package.sh` skips the `.pkg` rather than emitting
  an unsigned one that Gatekeeper would reject on every machine but yours.

`build.sh` signs with `--options runtime`, which notarization also requires. If
taps stop working once the hardened runtime is paired with a Developer ID
certificate, add an entitlements file granting
`com.apple.security.device.audio-input`.

## Prior art

macOS has never shipped a per-app volume mixer, so several people have built
one. Worth knowing before you pick:

- [SoundSource](https://rogueamoeba.com/soundsource/) — the commercial
  benchmark. Paid, mature, does far more than this (EQ, per-app routing, effects).
- [Background Music](https://github.com/kyleneideck/BackgroundMusic) — free, and
  the long-standing open-source answer. Uses a virtual audio driver (a HAL
  plugin) rather than process taps, so it installs a driver and sits in the
  audio path permanently.
- [Fader](https://github.com/pantafive/fader), [MixDesk](https://mixdesk.app/),
  [Volumes Bar](https://volumes.bar/),
  [SoundLevels](https://github.com/andgabx/SoundLevels),
  [FineTune](https://github.com/ronitsingh10/FineTune) — other menu bar mixers,
  several also built on Core Audio process taps.

What MixBar does differently: it stays out of the audio path entirely until a
slider moves, its core is framework-free and covered by tests that need no audio
hardware, and it groups an app's helper processes under one slider so a browser
cannot escape the mixer by moving audio to another helper.

## License

[MIT](LICENSE).

## Continuous integration

`.github/workflows/test.yml` runs the suite on every push. The core imports no
frameworks and every port has a fake, so it needs no audio device and no
permissions on the runner.

`.github/workflows/release.yml` publishes a signed, notarized release when you
push a tag:

```sh
git tag v0.2 && git push origin v0.2
```

It needs five repository secrets (Settings → Secrets and variables → Actions):

| Secret | What it is | Where it comes from |
| --- | --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Certificate **and** private key | Keychain Access → export the Developer ID Application identity as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_P12_PASSWORD` | Password you set on that export | You choose it during export |
| `NOTARY_KEY_P8_BASE64` | App Store Connect API key | App Store Connect → Users and Access → Integrations → Keys. **Downloadable once only**, then `base64 -i AuthKey_XXX.p8 \| pbcopy` |
| `NOTARY_KEY_ID` | That key's ID | Shown next to the key |
| `NOTARY_ISSUER_ID` | Issuer ID (a UUID) | Same page, above the key list |

The API key authenticates as the team rather than as one person's Apple ID, so
releases keep working when a password changes. The certificate is imported into
a throwaway keychain that is discarded with the runner.

`tools/release.sh` works the same way locally, using a `notarytool` keychain
profile instead of the API key.
