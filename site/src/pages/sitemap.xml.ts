import type { APIRoute } from "astro";
import { execFileSync } from "node:child_process";

// lastmod is the date of the last commit that touched the site, not the build
// date: a page rebuilt because a test was added has not changed for a crawler.
// A checkout without history (or without git) falls back to today, which is
// wrong in the safe direction.
function lastModified(): string {
  try {
    const date = execFileSync("git", ["log", "-1", "--format=%cs", "--", "."], {
      cwd: new URL("../../", import.meta.url),
      encoding: "utf8",
    }).trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(date)) return date;
  } catch {
    // fall through
  }
  return new Date().toISOString().slice(0, 10);
}

export const GET: APIRoute = ({ site }) => {
  if (!site) throw new Error("astro.config.ts must set `site`");
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${site.href}</loc>
    <lastmod>${lastModified()}</lastmod>
    <changefreq>monthly</changefreq>
  </url>
</urlset>
`;
  return new Response(body, { headers: { "Content-Type": "application/xml" } });
};
