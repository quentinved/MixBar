import { links } from "./links";

export interface Question {
  question: string;
  // A little HTML: links and the odd <code>. The structured data gets it
  // with the tags stripped.
  answer: string;
}

export const faq: Question[] = [
  {
    question: "How do I change the volume of one app on a Mac?",
    answer:
      "macOS has no per‑app volume control of its own: the volume keys change everything at once. MixBar adds a slider per app to the menu bar. Click the slider icon, and every app that is making sound is listed with its own volume and mute.",
  },
  {
    question: "An app is playing but it is not in the list.",
    answer:
      "It is almost always the permission. MixBar can only list apps that hold an output stream open, and without the audio‑recording grant it is handed silence rather than an error. Open <code>…</code> → <strong>Audio permission…</strong>, grant Audio Recording, and reopen the menu.",
  },
  {
    question: "Why is an app listed when it is not playing anything?",
    answer:
      "Holding an output stream open is not the same as playing. Video‑call apps and a number of Apple daemons keep one open forever while emitting silence. Hide them with <code>…</code> → <strong>Show idle apps</strong>.",
  },
  {
    question: "Does it work on Intel Macs?",
    answer:
      "Yes. The download is a universal binary, one file for Apple silicon and Intel. It needs macOS 15 or later on either.",
  },
  {
    question: "Why macOS 15?",
    answer:
      "MixBar is built on Core Audio process taps, the mechanism that lets one app read another's output without a driver. They are recent, and the app targets the first release where they are dependable enough to ship on.",
  },
  {
    question: "Which output devices can it switch between?",
    answer:
      "Anything Core Audio lists as an output: the built‑in speakers, headphones, Bluetooth, AirPlay, a display's speakers, an external interface, or a virtual device. The picker groups them by kind so that three names that look alike are not one undifferentiated list.",
  },
  {
    question: "Can it launch at login, or take a global hotkey?",
    answer: `Not yet. Launch at login, global hotkeys, sleep and wake handling, and per‑app output routing are the things not built yet, and they are <a href="${links.issues}">where help goes furthest</a>.`,
  },
  {
    question: "Is there a Homebrew cask?",
    answer:
      "Not yet. The build already emits one, but a cask needs a tap to live in before <code>brew install</code> works. Until then the download is the one install path.",
  },
  {
    question: "How do I uninstall it completely?",
    answer:
      "Quit it from the <code>…</code> menu, then drag MixBar out of Applications. Its settings live in one preferences domain, <code>com.quentinved.MixBar</code>, and the audio permission can be revoked in System Settings → Privacy &amp; Security. Quit from the menu rather than force‑quitting: taps registered with <code>coreaudiod</code> outlive a killed process.",
  },
  {
    question: "Something is wrong. Where do I say so?",
    answer: `<a href="${links.bug}">Open an issue</a>, or use <code>…</code> → <strong>Report a bug…</strong> in the app, which attaches the debug log. If you would rather not use GitHub, <a href="${links.email}">email works too</a>. Say which apps had sound and which output device was selected: that is most of the diagnosis.`,
  },
];

export const plainText = (html: string) =>
  html
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
