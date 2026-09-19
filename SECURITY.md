# Security policy

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report it privately through GitHub:
[**Report a vulnerability**](https://github.com/quentinved/MixBar/security/advisories/new).
That opens a private advisory only you and the maintainers can see.

You can expect an acknowledgement within 72 hours and an assessment within a
week. If a fix is warranted, you'll be credited in the release notes unless you
ask not to be.

## Supported versions

MixBar is pre-1.0. Only the latest release gets fixes.

## What is worth reporting

MixBar holds the `kTCCServiceAudioCapture` permission, which means it can read
the audio of every other app on the machine. That makes the following especially
serious, and very much worth reporting:

- Any path by which captured audio leaves the machine, is written to disk, or
  reaches another process
- Anything that lets another process drive MixBar's tap creation, or read from
  its aggregate device
- Tampering with the release artifacts, the signing chain, or the update path
- Anything that causes MixBar to capture audio while every app is at default
  volume, since it is supposed to create no tap at all in that state

## What MixBar does with your audio

For completeness, because this is the question the permission raises:

MixBar reads audio buffers in a realtime IOProc, multiplies them by a gain, sums
them, and writes them to the output device. **Nothing is recorded, buffered
beyond the current IOProc callback, written to disk, or sent anywhere.** There is
no network code in the app at all. The only file it writes is an optional local
debug log (`~/Library/Logs/MixBar.log`, off by default) which contains device
and process names, never audio.

The source is here, and the part that matters is
`app/Sources/MixBar/Adapters/CoreAudio/RealtimeMixer.swift`. Please read it and
tell us if it does not do what this page says.
