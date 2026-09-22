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
      "macOS has no per-app volume control of its own: the volume keys change everything at once. MixBar adds one to the menu bar. Click its icon and every app making sound is listed with its own slider and mute.",
  },
  {
    question: "How is it different from SoundSource or Background Music?",
    answer: `<a href="https://rogueamoeba.com/soundsource/">SoundSource</a> is the paid benchmark and does far more: EQ, effects, per-app routing. <a href="https://github.com/kyleneideck/BackgroundMusic">Background Music</a> is free, but installs a virtual audio driver that stays in your audio path permanently. MixBar is free, installs no driver, and is not in the audio path at all until you move a slider.`,
  },
  {
    question: "An app is playing but it is not in the list.",
    answer:
      "It is almost always the permission: without the audio-recording grant, macOS hands MixBar silence instead of an error. Open <code>…</code> → <strong>Audio permission…</strong>, grant Audio Recording, and reopen the menu.",
  },
  {
    question: "Which Macs does it run on?",
    answer:
      "Any Mac on macOS 15 or later, Apple silicon or Intel: the download is one universal app. It needs macOS 15 because it is built on Core Audio process taps, which that release made dependable.",
  },
  {
    question: "Can it launch at login, or take a global hotkey?",
    answer: `Not yet. Launch at login, global hotkeys, sleep and wake handling and per-app output routing are the next things to build, and <a href="${links.issues}">where help goes furthest</a>.`,
  },
  {
    question: "How do I uninstall it completely?",
    answer:
      "Quit it from the <code>…</code> menu, then drag it out of Applications. Its settings live in <code>com.quentinved.MixBar</code>, and the permission can be revoked in System Settings → Privacy &amp; Security. Quit rather than force-quit: taps registered with <code>coreaudiod</code> outlive a killed process.",
  },
  {
    question: "Something is wrong. Where do I say so?",
    answer: `<a href="${links.bug}">Open an issue</a>, or use <code>…</code> → <strong>Report a bug…</strong> in the app, which attaches the debug log. <a href="${links.email}">Email</a> works too. Say which apps had sound and which output device was selected.`,
  },
];

export const plainText = (html: string) =>
  html
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
