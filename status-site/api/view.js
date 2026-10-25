// Vercel Function: the view JSON for the page (lib/handler.js), read from GitHub Actions when requested.
import { serveView } from "../lib/handler.js";

export function GET(request) {
  return serveView(request, {
    fetch,
    token: process.env.GITHUB_TOKEN,
    repo: "josephsilcock/skimapper",
    deployment: process.env.VERCEL_ENV,
  });
}
