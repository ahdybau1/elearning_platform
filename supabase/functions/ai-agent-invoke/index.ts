// AI Control Plane — harnais générique d'exécution/test d'un agent (consigne #4, ADM-AI-002).
//
// Rôle : depuis l'admin, envoyer une entrée à un agent, exécuter réellement l'Edge Function qui
// l'implémente, journaliser l'exécution dans `ai_agent_runs` (entrée, sortie structurée, statut,
// durée), et renvoyer une validation structurelle de la sortie contre `output_schema`.
//
// Ne fait AUCUN eval de texte libre. N'expose aucun secret ni raisonnement interne : seulement
// l'entrée, la sortie structurée et des diagnostics.
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Validation structurelle légère et honnête (pas un validateur JSON Schema complet). */
function validateOutput(schema: any, value: any): { valid: boolean; issues: string[] } {
  const issues: string[] = [];
  if (!schema || typeof schema !== "object" || Object.keys(schema).length === 0) {
    return { valid: true, issues: ["Aucun schéma de sortie défini — validation ignorée."] };
  }
  if (schema.type === "object") {
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      issues.push("La sortie n'est pas un objet JSON.");
      return { valid: false, issues };
    }
    const required: string[] = Array.isArray(schema.required) ? schema.required : [];
    for (const key of required) {
      if (!(key in value)) issues.push(`Clé requise manquante : « ${key} ».`);
    }
    const props = schema.properties ?? {};
    for (const [key, spec] of Object.entries<any>(props)) {
      if (!(key in value) || value[key] == null) continue;
      const want = Array.isArray(spec?.type) ? spec.type : [spec?.type];
      const got = Array.isArray(value[key]) ? "array" : typeof value[key];
      const norm = got === "number" ? ["number", "integer"] : [got];
      if (spec?.type && !want.some((w: string) => norm.includes(w) || w == null)) {
        issues.push(`Type inattendu pour « ${key} » : ${got} (attendu ${want.join("|")}).`);
      }
    }
  }
  return { valid: issues.length === 0, issues };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");

  try {
    // — Auth : admin actif uniquement —
    const { data: userData } = await admin.auth.getUser(jwt);
    const authUserId = userData?.user?.id;
    const { data: adminRow } = authUserId
      ? await admin.from("admin_users").select("id, role").eq("auth_user_id", authUserId).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!adminRow) {
      return json({ error: "Accès réservé aux administrateurs actifs." }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const agentKey: string = body.agent_key ?? body.agent_id ?? "";
    const input = body.input ?? {};
    const trigger: string = ["manual_test", "workflow", "production"].includes(body.trigger)
      ? body.trigger
      : "manual_test";
    const workflowId: string | null = body.workflow_id ?? null;

    if (!agentKey) return json({ error: "Paramètre « agent_key » manquant." }, 400);

    // — Résolution agent + version courante —
    const { data: agent } = await admin
      .from("ai_agents")
      .select("id, agent_id, name, enabled, runtime")
      .eq("agent_id", agentKey)
      .maybeSingle();
    if (!agent) return json({ error: `Agent inconnu : ${agentKey}` }, 404);

    const { data: version } = await admin
      .from("ai_agent_versions")
      .select("id, version, output_schema, edge_function_name, status")
      .eq("agent_id", agent.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    // — Création de la ligne de run (status running) —
    const { data: run } = await admin
      .from("ai_agent_runs")
      .insert({
        agent_id: agent.id,
        agent_version_id: version?.id ?? null,
        agent_key: agent.agent_id,
        workflow_id: workflowId,
        trigger,
        triggered_by: adminRow.id,
        input_preview: input,
        status: "running",
      })
      .select("id")
      .single();
    const runId = run?.id;

    // Colonnes réelles de ai_agent_runs (le reste du payload de réponse est purement informatif).
    const RUN_COLS = new Set([
      "status", "error_message", "output", "output_valid", "duration_ms", "tokens_used", "cost_estimate",
    ]);
    const finish = async (payload: Record<string, unknown>) => {
      if (runId) {
        const dbPatch: Record<string, unknown> = { completed_at: new Date().toISOString() };
        for (const [k, v] of Object.entries(payload)) {
          if (RUN_COLS.has(k)) dbPatch[k] = v;
        }
        await admin.from("ai_agent_runs").update(dbPatch).eq("id", runId);
      }
      return json({ run_id: runId, ...payload });
    };

    // — Agent non exécutable : on journalise honnêtement l'échec —
    if (!agent.enabled) {
      return await finish({ status: "failed", error_message: "Agent désactivé (enabled = false).", output: null, output_valid: false });
    }
    if (agent.runtime !== "edge_function" || !version?.edge_function_name || version.edge_function_name === "gateway_native") {
      return await finish({
        status: "failed",
        error_message:
          agent.runtime === "gateway_native"
            ? "Agent défini côté Gateway FastAPI (non déployé) — hors ligne. Aucune Edge Function ne l'exécute."
            : "Aucune Edge Function n'est rattachée à cet agent.",
        output: null,
        output_valid: false,
      });
    }

    // — Invocation réelle de l'Edge Function cible, avec le JWT de l'appelant —
    const started = Date.now();
    let output: any = null;
    let httpStatus = 0;
    try {
      const resp = await fetch(`${SUPABASE_URL}/functions/v1/${version.edge_function_name}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${jwt}`,
          "apikey": ANON_KEY,
        },
        body: JSON.stringify(input),
      });
      httpStatus = resp.status;
      const text = await resp.text();
      try {
        output = JSON.parse(text);
      } catch {
        output = { _raw: text.slice(0, 4000) };
      }
    } catch (e: any) {
      return await finish({
        status: "failed",
        error_message: `Échec réseau vers ${version.edge_function_name} : ${e?.message ?? e}`,
        output: null,
        output_valid: false,
        duration_ms: Date.now() - started,
      });
    }

    const durationMs = Date.now() - started;
    const ok = httpStatus >= 200 && httpStatus < 300;
    const check = validateOutput(version.output_schema, output);
    const tokens = Number(output?._tokens ?? output?.usage?.total_tokens ?? 0) || 0;

    return await finish({
      status: ok ? "success" : "failed",
      error_message: ok ? null : `HTTP ${httpStatus} depuis ${version.edge_function_name}` + (output?.error ? ` — ${output.error}` : ""),
      output,
      output_valid: ok ? check.valid : false,
      validation_issues: check.issues,
      duration_ms: durationMs,
      tokens_used: tokens,
      edge_function: version.edge_function_name,
      agent_version: version.version,
    });
  } catch (err: any) {
    return json({ error: err?.message ?? "Erreur interne du harnais d'exécution." }, 500);
  }
});
