// Push (FCM) for things that must reach a closed app: incoming calls and
// direct messages / pokes.
//
// The app calls this right after it rings someone or sends a message:
//   {type: "call", call_id}         caller rang callee: ring their phones
//   {type: "call_cancel", call_id}  call stopped ringing: clear the ring
//   {type: "dm", message_id}        sender sent a message: notify recipient
// Only the caller of that call / sender of that message may trigger it.
//
// Messages are data-only; the app's background handler draws the ringing
// screen or the chat notification itself. Sent via FCM HTTP v1 with an OAuth
// token minted from the service account in the FIREBASE_SERVICE_ACCOUNT
// secret (the full JSON key file as one string).
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

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

// ---- Google OAuth (RS256 JWT, Web Crypto) ---------------------------------

const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlText = (s: string) => b64url(new TextEncoder().encode(s));

let cached: { token: string; exp: number } | null = null;

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;

  const aud = sa.token_uri ?? "https://oauth2.googleapis.com/token";
  const unsigned = b64urlText(JSON.stringify({ alg: "RS256", typ: "JWT" })) + "." +
    b64urlText(JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud,
      iat: now,
      exp: now + 3600,
    }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );

  const res = await fetch(aud, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${b64url(sig)}`,
    }),
  });
  const body = await res.json();
  if (!res.ok || !body.access_token) {
    throw new Error(`oauth ${res.status}: ${JSON.stringify(body)}`);
  }
  cached = { token: body.access_token, exp: now + (body.expires_in ?? 3600) };
  return cached.token;
}

// ---- FCM ------------------------------------------------------------------

/** Sends [data] to every token; returns the tokens FCM says are dead. */
async function send(
  sa: ServiceAccount,
  tokens: string[],
  data: Record<string, string>,
  android: Record<string, unknown>,
): Promise<{ sent: number; dead: string[]; errors: string[] }> {
  const bearer = await accessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const dead: string[] = [];
  const errors: string[] = [];
  let sent = 0;
  await Promise.all(tokens.map(async (token) => {
    const res = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token, data, android } }),
    });
    if (res.ok) {
      sent++;
      return;
    }
    const err = (await res.json().catch(() => ({})))?.error ?? {};
    const codes: string[] = (err.details ?? []).map((d: { errorCode?: string }) => d.errorCode ?? "");
    const badToken = codes.includes("UNREGISTERED") ||
      // INVALID_ARGUMENT is also returned for a bad payload; only a bad token
      // is a reason to forget it.
      (err.status === "INVALID_ARGUMENT" && /registration token/i.test(err.message ?? ""));
    if (badToken) dead.push(token);
    else console.error("fcm", res.status, JSON.stringify(err));
    errors.push(`${res.status} ${err.status ?? ""} ${err.message ?? ""}`.slice(0, 200));
  }));
  return { sent, dead, errors };
}

// ---- notification text ----------------------------------------------------

type DmRow = {
  sender_id: string;
  recipient_id: string;
  body: string | null;
  kind: string | null;
  view_once: boolean | null;
  media_kind: string | null;
};

/** What the chat notification says. Never carries media itself. */
function dmText(m: DmRow): string | null {
  const body = (m.body ?? "").trim();
  if (m.kind === "poke") return "👋 Poked you!";
  // Call logs: only a missed call is news to the callee.
  if (m.kind === "call") return body.startsWith("Missed") ? body : null;
  if (m.view_once) return "📷 Photo";
  if (m.kind === "voice" || m.media_kind === "voice") return "🎤 Voice message";
  if (m.kind === "image" || m.media_kind === "image") {
    return body && body !== "📷 Photo" ? `📷 ${body}` : "📷 Photo";
  }
  return body.length > 300 ? `${body.slice(0, 299)}…` : body || null;
}

// ---- handler --------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const userDb = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await userDb.auth.getUser();
  if (!user) return json({ error: "sign in first" }, 401);

  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) return json({ error: "push not configured" }, 503);
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(raw);
  } catch {
    return json({ error: "push not configured" }, 503);
  }

  let input: { type?: string; call_id?: string; message_id?: string };
  try {
    input = await req.json();
  } catch {
    return json({ error: "bad body" }, 400);
  }

  const db = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
  let to: string;
  let data: Record<string, string>;
  let android: Record<string, unknown>;

  if (input.type === "call" || input.type === "call_cancel") {
    if (!input.call_id) return json({ error: "call_id required" }, 400);
    const { data: call } = await db.from("calls")
      .select("id, caller, callee, kind, status")
      .eq("id", input.call_id)
      .maybeSingle();
    if (!call || call.caller !== user.id) return json({ error: "not your call" }, 403);
    if (input.type === "call" && call.status !== "ringing") return json({ sent: 0 });
    to = call.callee;
    if (input.type === "call") {
      const { data: p } = await db.from("profiles").select("full_name").eq("id", user.id).maybeSingle();
      data = {
        type: "call",
        call_id: call.id,
        caller_id: call.caller,
        caller_name: p?.full_name || "Family member",
        kind: call.kind,
        sent_at: String(Date.now()),
      };
      // Rings for 40 s on the caller's side; a later delivery is useless.
      android = { priority: "HIGH", ttl: "40s" };
    } else {
      data = { type: "call_cancel", call_id: call.id };
      android = { priority: "HIGH", ttl: "60s" };
    }
  } else if (input.type === "dm") {
    if (!input.message_id) return json({ error: "message_id required" }, 400);
    const { data: m } = await db.from("direct_messages")
      .select("id, sender_id, recipient_id, body, kind, view_once, media_kind")
      .eq("id", input.message_id)
      .maybeSingle();
    if (!m || m.sender_id !== user.id) return json({ error: "not your message" }, 403);
    const text = dmText(m);
    if (!text) return json({ sent: 0 });
    const { data: p } = await db.from("profiles").select("full_name").eq("id", user.id).maybeSingle();
    to = m.recipient_id;
    data = {
      type: "dm",
      message_id: m.id,
      sender_id: m.sender_id,
      title: p?.full_name || "Family member",
      body: text,
      poke: m.kind === "poke" ? "1" : "0",
    };
    android = { priority: "HIGH" };
  } else {
    return json({ error: "unknown type" }, 400);
  }

  const { data: rows } = await db.from("push_tokens").select("token").eq("user_id", to);
  const tokens = (rows ?? []).map((r) => r.token as string);
  // Call trace (see call_debug); chat pushes are not traced.
  const trace = (detail: string) =>
    input.call_id
      ? db.from("call_debug").insert({
        call_id: input.call_id,
        user_id: user.id,
        event: `server_${input.type}`,
        detail: detail.slice(0, 500),
      }).then(() => {}, () => {})
      : Promise.resolve();
  if (tokens.length === 0) {
    await trace("no tokens for callee");
    return json({ sent: 0 });
  }

  try {
    const { sent, dead, errors } = await send(sa, tokens, data, android);
    if (dead.length) await db.from("push_tokens").delete().in("token", dead);
    await trace(`tokens=${tokens.length} sent=${sent} dead=${dead.length} ${errors.join(" | ")}`);
    return json({ sent, removed: dead.length });
  } catch (e) {
    console.error("push", e);
    await trace(`failed: ${e}`);
    return json({ error: "push failed" }, 502);
  }
});
