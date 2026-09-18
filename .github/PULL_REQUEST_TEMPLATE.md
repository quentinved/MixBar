## What this changes

<!-- One or two sentences. If it fixes an issue: Fixes #123 -->

## How it was tested

<!-- Which apps were playing, which output device, which Mac and macOS version.
     For domain changes, the new tests are usually enough — say so. -->

- [ ] `swift test` passes
- [ ] `./build.sh` produces an app that launches and mixes correctly

## Checklist

- [ ] `Domain/` still imports no frameworks
- [ ] `AudioObjectID` does not appear above the adapter layer
- [ ] Any new port has a fake in `MixBarTests/Fakes.swift`
- [ ] MixBar still creates no tap and no aggregate device while every app is at 100%
- [ ] Comments explain *why*, in the style of the surrounding code
