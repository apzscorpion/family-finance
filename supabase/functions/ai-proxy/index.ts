// Built-in AI for every KinPurse user, with a daily limit.
//
// The app sends {family_id, system, input, schema?, image?, model?}; this
// calls a provider with the server's keys (never shipped in the app) and
// returns {text, remaining, model}. {op: "info"} returns the member's limit,
// what's left today, the models on offer and the ones they may pick.
//
// Models are tried in order; Gemini comes last. A member's own pick is
// tried first, but only if an owner or admin approved it for them.
import { createClient } from "jsr:@supabase/supabase-js@2";

const DEFAULT_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "30");

const adminEmails = () =>
  (Deno.env.get("ADMIN_EMAILS") ?? "").split(",").map((e) => e.trim().toLowerCase()).filter(Boolean);

type Model = { id: string; label: string; vision: boolean };

// Only providers whose key is set on the server are offered.
function catalog(): Model[] {
  const out: Model[] = [];
  if (Deno.env.get("GROQ_API_KEY")) {
    out.push({ id: "groq:llama-3.3-70b-versatile", label: "Llama 3.3 70B (Groq)", vision: false });
  }
  if (Deno.env.get("OPENROUTER_API_KEY")) {
    // Low cost first: a free model, then a cheap reliable one.
    out.push({ id: "openrouter:google/gemma-4-31b-it:free", label: "Gemma 4 31B (free)", vision: true });
    out.push({ id: "openrouter:anthropic/claude-haiku-5.5", label: "Claude Haiku 5.5 (low cost)", vision: true });
  }
  if (Deno.env.get("NVIDIA_API_KEY")) {
    // NVIDIA's API catalog: free developer access, rate limited.
    out.push({ id: "nvidia:meta/llama-3.3-70b-instruct", label: "Llama 3.3 70B (NVIDIA)", vision: false });
  }
  if (Deno.env.get("OPENAI_API_KEY")) {
    out.push({ id: "openai:gpt-4o-mini", label: "GPT-4o mini (OpenAI)", vision: true });
  }
  if (Deno.env.get("GEMINI_API_KEY")) {
    out.push({ id: "gemini:gemini-3.8-flash", label: "Gemini 3.8 Flash", vision: true });
    out.push({ id: "gemini:gemini-3.5-flash-lite", label: "Gemini 3.5 Flash-Lite", vision: true });
  }
  return out;
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

async function callGemini(model: string, b: any): Promise<Response> {
  return await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": Deno.env.get("GEMINI_API_KEY") ?? "",
      },
      body: JSON.stringify({
        systemInstruction: b.system ? { parts: [{ text: String(b.system) }] } : undefined,
        contents: [{
          parts: [
            { text: String(b.input ?? "") },
            ...(b.image?.base64
              ? [{ inline_data: { mime_type: b.image.mime, data: b.image.base64 } }]
              : []),
          ],
        }],
        generationConfig: b.schema
          ? { responseMimeType: "application/json", responseSchema: b.schema, temperature: 0 }
          : { temperature: 0.4 },
      }),
    },
  );
}

const OPENAI_STYLE: Record<string, { url: string; key: string }> = {
  groq: { url: "https://api.groq.com/openai/v1/chat/completions", key: "GROQ_API_KEY" },
  openrouter: { url: "https://openrouter.ai/api/v1/chat/completions", key: "OPENROUTER_API_KEY" },
  openai: { url: "https://api.openai.com/v1/chat/completions", key: "OPENAI_API_KEY" },
  nvidia: { url: "https://integrate.api.nvidia.com/v1/chat/completions", key: "NVIDIA_API_KEY" },
};

async function callOpenAiStyle(provider: string, model: string, b: any): Promise<Response> {
  const p = OPENAI_STYLE[provider];
  const system = String(b.system ?? "") +
    (b.schema ? `\nReply with JSON only, matching this schema: ${JSON.stringify(b.schema)}` : "");
  const user = b.image?.base64
    ? [
      { type: "text", text: String(b.input ?? "") },
      { type: "image_url", image_url: { url: `data:${b.image.mime};base64,${b.image.base64}` } },
    ]
    : String(b.input ?? "");
  return await fetch(p.url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${Deno.env.get(p.key) ?? ""}`,
    },
    body: JSON.stringify({
      model,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
      temperature: b.schema ? 0 : 0.4,
      ...(b.schema ? { response_format: { type: "json_object" } } : {}),
    }),
  });
}

async function textOf(provider: string, r: Response): Promise<string> {
  const out = await r.json();
  if (provider === "gemini") {
    const parts = out?.candidates?.[0]?.content?.parts ?? [];
    return parts.map((p: any) => p?.text ?? "").join("");
  }
  return out?.choices?.[0]?.message?.content ?? "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL")!;
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return json({ error: "Sign in to use KinPurse AI." }, 401);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Bad request" }, 400);
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let membership: { ai_daily_limit: number | null; ai_models: string[] } | null = null;
  if (body.family_id) {
    const { data } = await admin.from("family_memberships")
      .select("ai_daily_limit, ai_models")
      .eq("family_id", body.family_id).eq("user_id", user.id).eq("status", "active")
      .maybeSingle();
    membership = data;
  }
  const limit = membership?.ai_daily_limit ?? DEFAULT_LIMIT;
  const allowed = membership?.ai_models ?? [];
  const models = catalog();

  const today = new Date().toISOString().slice(0, 10);

  if (body.op === "info") {
    const { data: row } = await admin.from("ai_usage").select("count")
      .eq("user_id", user.id).eq("day", today).maybeSingle();
    const used = row?.count ?? 0;
    // Family owners also see each member's use today.
    let members_used: Record<string, number> | undefined;
    if (body.family_id) {
      const { data: me } = await admin.from("family_memberships").select("role")
        .eq("family_id", body.family_id).eq("user_id", user.id).maybeSingle();
      if (me?.role === "owner") {
        const { data: ms } = await admin.from("family_memberships").select("user_id")
          .eq("family_id", body.family_id);
        const ids = (ms ?? []).map((m: any) => m.user_id);
        const { data: rows } = await admin.from("ai_usage").select("user_id, count")
          .eq("day", today).in("user_id", ids);
        members_used = Object.fromEntries((rows ?? []).map((r: any) => [r.user_id, r.count]));
      }
    }
    const isAppAdmin = adminEmails().includes((user.email ?? "").toLowerCase());
    return json({ limit, used, remaining: Math.max(0, limit - used), models, allowed, members_used, app_admin: isAppAdmin });
  }

  // App admins (ADMIN_EMAILS): every provider key and everyone's use.
  if (body.op === "admin") {
    if (!adminEmails().includes((user.email ?? "").toLowerCase())) {
      return json({ error: "Not allowed" }, 403);
    }
    const keys = ["GEMINI_API_KEY", "OPENROUTER_API_KEY", "NVIDIA_API_KEY", "GROQ_API_KEY", "OPENAI_API_KEY"]
      .filter((k) => Deno.env.get(k))
      .map((k) => ({ name: k, value: Deno.env.get(k) }));
    const { data: rows } = await admin.from("ai_usage").select("user_id, day, count")
      .gte("day", new Date(Date.now() - 6 * 864e5).toISOString().slice(0, 10))
      .order("day", { ascending: false });
    const ids = [...new Set((rows ?? []).map((r: any) => r.user_id))];
    const { data: people } = ids.length
      ? await admin.from("profiles").select("id, full_name").in("id", ids)
      : { data: [] };
    const names = Object.fromEntries((people ?? []).map((p: any) => [p.id, p.full_name]));
    return json({
      default_limit: DEFAULT_LIMIT,
      models,
      keys,
      usage: (rows ?? []).map((r: any) => ({ ...r, name: names[r.user_id] ?? "Member" })),
    });
  }

  if (String(body.input ?? "").length > 60000) {
    return json({ error: "That's too long for the free AI." }, 413);
  }
  if (limit <= 0) {
    return json({ error: "KinPurse AI is turned off for you. Ask the family owner, or add your own key in Settings → AI." }, 403);
  }

  const { data: left, error } = await admin.rpc("ai_use", { p_user: user.id, p_limit: limit });
  if (error) return json({ error: "Could not check your AI allowance." }, 500);
  if (left === -1) {
    return json({
      error: `You've used today's ${limit} free AI requests. Add your own key in Settings → AI for unlimited use.`,
      limit,
    }, 429);
  }

  // The member's approved pick first, then everything else (Gemini last).
  const pick = typeof body.model === "string" && allowed.includes(body.model)
    ? models.filter((m) => m.id === body.model)
    : [];
  const order = [...pick, ...models.filter((m) => m.id !== pick[0]?.id)]
    .filter((m) => !body.image || m.vision);

  let last = "The AI service is busy. Please try again shortly.";
  for (const m of order) {
    const i = m.id.indexOf(":");
    const provider = m.id.slice(0, i);
    const model = m.id.slice(i + 1);
    try {
      const r = provider === "gemini"
        ? await callGemini(model, body)
        : await callOpenAiStyle(provider, model, body);
      if (r.ok) {
        return json({ text: await textOf(provider, r), remaining: left, model: m.id });
      }
      last = `AI request failed (${r.status})`;
    } catch (_) {
      last = "Could not reach the AI service.";
    }
  }
  return json({ error: last }, 503);
});
