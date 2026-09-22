export interface Release {
  version: string;
  date: string;
  title: string;
  changes: string[];
}

export const releases: Release[] = [
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
