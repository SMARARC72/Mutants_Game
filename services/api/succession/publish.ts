// Vercel route: POST /api/succession/publish (TDD §7.4).

import { vercelRoute, type VercelRequest, type VercelResponse } from "../_adapter.js";
import { successionPublishHandler } from "../../lib/app.js";

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  return vercelRoute("POST", successionPublishHandler())(req, res);
}
