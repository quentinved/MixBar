// The page is built from inside the repository, so the numbers it quotes are
// read from the source rather than copied in and left to drift. Importing the
// files makes them build inputs: a change to either rebuilds the page.
import plist from "../../../app/Info.plist?raw";

const tests = import.meta.glob("../../../app/Tests/**/*.swift", {
  query: "?raw",
  import: "default",
  eager: true,
}) as Record<string, string>;

const shortVersion = plist.match(
  /<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/,
);
if (!shortVersion?.[1]) throw new Error("app/Info.plist has no CFBundleShortVersionString");

export const version = shortVersion[1];

export const testCount = Object.values(tests)
  .map((source) => (source.match(/^\s*@Test\b/gm) ?? []).length)
  .reduce((sum, count) => sum + count, 0);

if (testCount === 0) throw new Error("no @Test found under app/Tests");
