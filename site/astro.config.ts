import { defineConfig } from "astro/config";

// The page ships under `default-src 'none'` with no 'unsafe-inline' anywhere,
// so every stylesheet and script has to be a file the CSP can allow by origin.
// Astro's defaults inline small ones, which the browser would then drop.
export default defineConfig({
  site: "https://mixbar.quentinvedrenne.com",
  trailingSlash: "never",
  build: {
    format: "file",
    inlineStylesheets: "never",
  },
  vite: {
    build: { assetsInlineLimit: 0 },
  },
});
