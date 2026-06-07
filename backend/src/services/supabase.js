import { createClient } from "@supabase/supabase-js";
import dotenv from "dotenv";

import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const envPath = path.resolve(__dirname, "../../.env");
dotenv.config({ path: envPath });

function getRoleFromKey(key) {
  if (!key) return "MISSING";
  try {
    const parts = key.split(".");
    if (parts.length !== 3) return "INVALID FORMAT";
    const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());
    return payload.role || "NO ROLE IN PAYLOAD";
  } catch (e) {
    return "DECODE ERROR";
  }
}

console.log(
  "[SupabaseService] Initializing Supabase client with URL:",
  process.env.SUPABASE_URL,
  "and Key Role:",
  getRoleFromKey(process.env.SUPABASE_SERVICE_ROLE_KEY),
);

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);

export const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);

export default supabase;
