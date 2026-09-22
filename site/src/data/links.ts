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
  latest: `${repo}/releases/latest`,
  // A redirect in public/_redirects, so the button never names a version.
  download: "/download",
  email: "mailto:contact@quentinvedrenne.com",
  author: "https://quentinvedrenne.com",
} as const;
