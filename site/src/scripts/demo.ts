// The popover, rebuilt in the page. It follows the app's two rules: the meter
// reads the signal after the gain, so it can never reach past the fill, and
// nothing is "in the audio path" until a slider leaves 100%.

interface Channel {
  row: HTMLElement;
  input: HTMLInputElement;
  mute: HTMLButtonElement;
  percent: HTMLElement;
  name: string;
  seed: number;
  silent: boolean;
  gain: number;
  muted: boolean;
  remembered: number;
}

const root = document.querySelector<HTMLElement>("[data-demo]");

if (root) {
  const channels = Array.from(root.querySelectorAll<HTMLElement>("[data-channel]")).map(
    (row, index): Channel => {
      const input = row.querySelector<HTMLInputElement>("input[type=range]");
      const mute = row.querySelector<HTMLButtonElement>("[data-mute]");
      const percent = row.querySelector<HTMLElement>("[data-percent]");
      if (!input || !mute || !percent) throw new Error("demo row is missing a part");
      const gain = Number(input.value) / 100;
      return {
        row,
        input,
        mute,
        percent,
        name: row.dataset.channel ?? "",
        seed: index + 1,
        silent: row.hasAttribute("data-silent"),
        gain,
        muted: gain === 0,
        remembered: gain === 0 ? 0.5 : gain,
      };
    },
  );
  const status = root.querySelector<HTMLElement>("[data-status]");
  const reset = root.querySelector<HTMLButtonElement>("[data-reset]");
  const stillness = matchMedia("(prefers-reduced-motion: reduce)");

  const isRouted = (channel: Channel) => channel.muted || channel.gain < 1;

  // Decorative and cheap: two sines per app, out of phase with each other.
  function level(channel: Channel, time: number): number {
    if (channel.silent || channel.muted) return 0;
    const slow = 0.5 + 0.5 * Math.sin(time * 0.00041 * (1 + (channel.seed % 3)) + channel.seed);
    const fast = Math.abs(Math.sin(time * 0.0023 + channel.seed * 1.7));
    return 0.12 + 0.88 * (0.55 * slow + 0.45 * fast);
  }

  function paint(channel: Channel, time: number): void {
    const shown = channel.muted ? 0 : channel.gain;
    const signal = Math.min(level(channel, time) * shown, shown);
    channel.row.style.setProperty("--gain", String(shown));
    channel.row.style.setProperty("--level", String(signal));
    channel.row.toggleAttribute("data-muted", channel.muted);
    channel.row.toggleAttribute("data-routed", isRouted(channel));
    channel.percent.textContent = `${Math.round(shown * 100)}%`;
    channel.mute.setAttribute("aria-pressed", String(channel.muted));
    if (document.activeElement !== channel.input) {
      channel.input.value = String(Math.round(shown * 100));
    }
  }

  function describe(): void {
    if (!status) return;
    const routed = channels.filter(isRouted);
    if (routed.length === 0) {
      status.textContent = "Audio path untouched. No taps, no aggregate device.";
      return;
    }
    const names = routed.map((channel) => channel.name).join(", ");
    const taps = routed.length === 1 ? "1 tap" : `${routed.length} taps`;
    status.textContent = `${taps}, one aggregate device. Routed: ${names}.`;
  }

  for (const channel of channels) {
    channel.input.addEventListener("input", () => {
      const gain = Number(channel.input.value) / 100;
      // Dragging up out of a mute unmutes, as it does in the app.
      channel.muted = gain === 0;
      channel.gain = gain;
      if (gain > 0) channel.remembered = gain;
      paint(channel, performance.now());
      describe();
    });
    channel.mute.addEventListener("click", () => {
      channel.muted = !channel.muted;
      channel.gain = channel.muted ? channel.gain : channel.remembered;
      paint(channel, performance.now());
      describe();
    });
  }

  reset?.addEventListener("click", () => {
    for (const channel of channels) {
      channel.gain = 1;
      channel.remembered = 1;
      channel.muted = false;
      paint(channel, performance.now());
    }
    describe();
  });

  // The meters only move while someone can see them.
  let visible = false;
  let frame = 0;
  function tick(time: number): void {
    for (const channel of channels) paint(channel, time);
    frame = visible && !stillness.matches ? requestAnimationFrame(tick) : 0;
  }
  function wake(): void {
    if (frame === 0) frame = requestAnimationFrame(tick);
  }
  new IntersectionObserver(
    (entries) => {
      visible = entries.some((entry) => entry.isIntersecting) && !document.hidden;
      if (visible) wake();
    },
    { threshold: 0.1 },
  ).observe(root);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) visible = false;
    else wake();
  });
  stillness.addEventListener("change", wake);

  channels.forEach((channel) => paint(channel, 0));
  describe();
  root.setAttribute("data-live", "");
}
