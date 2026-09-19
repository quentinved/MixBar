# Contributing to MixBar

MixBar is a small app with a strict shape. Most of this document is about that
shape, because a change that fits it is easy to accept and a change that doesn't
is hard to review however good the idea is.

## Getting set up

```sh
git clone https://github.com/quentinved/MixBar
cd MixBar/app
swift test        # 33 tests, no audio hardware and no permissions needed
./build.sh        # -> build/MixBar.app
```

Requires macOS 15 and a recent Xcode. There are no dependencies to install.

**Run the built `.app`, not the bare binary.** An unbundled binary never gets a
TCC entry, so macOS silently hands it buffers of zeros instead of audio. And
**launch it from Finder, not from a terminal** — launched from a VS Code
terminal, the audio-capture permission is recorded against VS Code rather than
against MixBar, and you will spend an afternoon debugging it.

## The architecture, and the one rule

MixBar is hexagonal (ports and adapters):

```
app/Sources/MixBar/
├── Domain/     the mixing rules. Imports nothing.
├── Ports/      protocols: the only way the domain talks to the world
├── Adapters/   CoreAudio, UserDefaults, SwiftUI
└── MixBarApp.swift   composition root, where the real adapters get wired in
```

**The rule: `Domain/` imports no frameworks.** Not CoreAudio, not SwiftUI, not
Foundation where it can be avoided. It takes its clock as an injected
`() -> Date`. That is what lets the whole rule set run on a CI box with no audio
device, and it is why `swift test` takes a millisecond instead of a minute. A PR
that imports a framework into `Domain/` will be asked to move that code into an
adapter.

`AudioObjectID` must never appear above the adapter layer. `ProcessRegistry` is
the seam: it maps the domain's `AudioAppID` to the several Core Audio process
objects behind it.

Every port has a fake in `app/Tests/MixBarTests/Fakes.swift`. New port, new fake.

## Working on the audio path

This is the part that bites. Read these before debugging:

- **Kill it gently.** Taps and aggregate devices are registered with
  `coreaudiod` and outlive the process. `SIGKILL` skips teardown and leaves them
  orphaned in your audio path; only `sudo killall coreaudiod` clears them. Quit
  from the menu, or `SIGTERM`.
- **Missing permission is silent.** No error, just zeros. There is no
  permission-check API in CoreAudio, and you cannot infer denial from silence —
  plenty of apps hold a permanently silent stream open.
- **Building taps blocks.** It is IPC with `coreaudiod`, takes ~1.8s, and blocks
  indefinitely the first time while the permission prompt waits. Never on the
  main thread.
- **Nothing at default volume.** MixBar creates no tap and no aggregate device
  until a slider actually moves, and tears down when it returns to 100%. An
  earlier version routed everything through the mixer and caused audible
  crackling system-wide, even while mixing pure silence. Please don't undo this.

`spike/` holds a standalone command-line harness for poking at Core Audio taps
without running the app. It is scratch space, not shipped code.

## Style

`swift test` and `swift build -c release` must pass; CI runs both on every push.
The repo has a `.swiftlint.yml` — run `swiftlint` if you have it installed.

Comments explain **why**, not what. The existing code is the reference: it
documents the surprising Core Audio behaviour that forced each decision, and
that is the most valuable thing in the repo. Match it.

## Pull requests

- One change per PR. A rename and a behaviour change in the same diff is two PRs.
- Say what you tested, and on what hardware. "Tested with Spotify and Arc on an
  M2, Sequoia 15.3" tells a reviewer more than a paragraph of prose.
- New rules in the domain need a test. Adapter changes often can't be tested
  without hardware — say so, and say what you did manually instead.
- Draft PRs are welcome early, especially for anything touching the audio path.

## Good first contributions

The things that aren't built yet, roughly easiest first:

- Launch at login (`SMAppService`)
- Sleep/wake handling — the aggregate device needs rebuilding after wake
- Global hotkeys
- Per-app output routing (send Spotify to headphones, everything else to speakers)
- A proper preferences window

Open an issue before starting something large, so two people don't build it
twice.

## Licence

By contributing you agree that your contributions are licensed under the MIT
Licence, the same terms that cover the rest of the project.
