const repo = "https://github.com/quentinved/MixBar";

export const links = {
  repo,
  releases: `${repo}/releases`,
  issues: `${repo}/issues`,
  bug: `${repo}/issues/new?template=bug_report.yml`,
  license: `${repo}/blob/main/LICENSE`,
  contributing: `${repo}/blob/main/CONTRIBUTING.md`,
  security: `${repo}/blob/main/SECURITY.md`,
  mixer: `${repo}/blob/main/app/Sources/MixBar/Adapters/CoreAudio/RealtimeMixer.swift`,
  readme: `${repo}#readme`,
  // A redirect in public/_redirects, so the button never names a version.
  download: "/download",
  email: "mailto:contact@quentinvedrenne.com",
  author: "https://quentinvedrenne.com",
} as const;

export const alternatives = [
  {
    name: "SoundSource",
    href: "https://rogueamoeba.com/soundsource/",
    kind: "Commercial",
    note: "The benchmark. Paid, mature, and it does far more than this: EQ, effects, per-app routing.",
  },
  {
    name: "Background Music",
    href: "https://github.com/kyleneideck/BackgroundMusic",
    kind: "Open source",
    note: "The long-standing free answer. Built on a virtual audio driver, so it installs one and stays in the audio path permanently.",
  },
  {
    name: "Other menu bar mixers",
    href: "https://github.com/quentinved/MixBar#prior-art",
    kind: "Open source and indie",
    note: "Fader, MixDesk, Volumes Bar, SoundLevels and FineTune, several also built on Core Audio process taps.",
  },
] as const;
