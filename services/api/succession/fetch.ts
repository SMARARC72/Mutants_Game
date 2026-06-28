// Vercel route: GET /api/succession/fetch (TDD §7.4).

import { vercelRoute, type VercelRequest, type VercelResponse } from "../_adapter.js";
import { successionFetchHandler } from "../../lib/app.js";

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  return vercelRoute("GET", successionFetchHandler())(req, res);
}
