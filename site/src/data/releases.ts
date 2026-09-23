export interface Release {
  version: string;
  date: string;
  title: string;
  changes: string[];
}

export const releases: Release[] = [
  {
    version: "1.0",
    date: "2026-09-23",
    title: "Steady under real use",
    changes: [
      "Pausing one app no longer interrupts the others: the mixer stays built and simply idles, so nothing jumps to full volume while it rebuilds.",
      "Apps that start or stop playing, and output devices that come and go, are picked up the moment they change instead of on the next poll.",
      "A browser tab that starts playing after you set the browser's volume is included in it, rather than playing at full volume.",
      "Open at login, from the … menu.",
      "VoiceOver can read and adjust every volume slider.",
      "Quitting always takes MixBar out of the audio path, including at logout and during a Homebrew upgrade.",
    ],
  },
  {
    version: "0.2",
    date: "2026-09-22",
    title: "One build for every Mac",
    changes: [
      "A universal binary: one download for Apple silicon and Intel.",
      "The output picker says what kind of device each one is, and groups them: built-in, headphones, Bluetooth, AirPlay, displays, external, virtual.",
      "A way to report a bug from inside the app, with the debug log attached.",
      "A download URL that always points at the newest release.",
    ],
  },
  {
    version: "0.1",
    date: "2026-09-18",
    title: "First release",
    changes: [
      "Per-app volume and mute, remembered by app across restarts.",
      "A live level meter drawn inside each volume bar.",
      "Output device switching.",
      "Three layouts: compact, comfortable, and a mixing-desk view.",
      "Signed and notarized, so it opens without a Gatekeeper warning.",
    ],
  },
];
