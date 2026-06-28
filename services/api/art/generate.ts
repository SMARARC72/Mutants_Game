// Vercel route: POST /api/art/generate (ADR-007, TDD §7.3).
// The real dependencies (env secrets, OpenAI, Supabase service-role, Storage) are built
// lazily on first request so importing this module never requires secrets at build time.

import { vercelRoute, type VercelRequest, type VercelResponse } from "../_adapter.js";
import { artGenerateHandler } from "../../lib/app.js";

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  return vercelRoute("POST", artGenerateHandler())(req, res);
}
