// TURN relay settings for family calls.
//
// Calls connect peer to peer using public STUN; on strict mobile networks
// (symmetric NAT, CGNAT) that fails and only a TURN relay gets through. The
// relay's address and credentials live in function secrets, never in the app:
//
//   TURN_URL         e.g. "turn:turn.example.com:3478,turns:turn.example.com:5349"
//   TURN_USERNAME
//   TURN_CREDENTIAL
//
// Returns {turn: {urls, username, credential}} to signed-in users, or
// {turn: null} when no relay is configured (the app then uses STUN only).
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const auth = req.headers.get("Authorization") ?? "";
  const db = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: auth } } },
  );
  const { data: { user } } = await db.auth.getUser();
  if (!user) return json({ error: "sign in first" }, 401);

  const urls = (Deno.env.get("TURN_URL") ?? "")
    .split(",").map((u) => u.trim()).filter(Boolean);
  if (urls.length === 0) return json({ turn: null });

  return json({
    turn: {
      urls,
      username: Deno.env.get("TURN_USERNAME") ?? "",
      credential: Deno.env.get("TURN_CREDENTIAL") ?? "",
    },
  });
});
