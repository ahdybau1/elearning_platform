// AI Control Plane — exécuteur de workflow multi-agents (consigne #4 : « suivre les workflows
// impliquant plusieurs agents, avec leur progression, leurs étapes et leurs erreurs » + reprise).
//
// Séquentiel. Chaque étape appelle un agent via la même logique que `ai-agent-invoke` (Edge
// Function réelle rattachée). En cas d'échec d'une étape, le workflow s'arrête en statut 'failed'
// et reste **reprenable** : un appel avec `resume_id` relance à partir de la première étape non
// réussie. Aucun eval de texte libre.
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
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, "Content-Type": "application/json" } });

async function runStep(
  jwt: string,
  workflowId: string,
  adminId: string,
  agentKey: string,
): Promise<{ ok: boolean; runId: string | null; error: string | null; output: unknown }> {
  const { data: agent } = await admin
    .from("ai_agents")
    .select("id, enabled, runtime")
    .eq("agent_id", agentKey)
    .maybeSingle();
  const { data: version } = agent
    ? await admin
        .from("ai_agent_versions")
        .select("id, version, edge_function_name")
        .eq("agent_id", agent.id)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle()
    : { data: null };

  const { data: run } = await admin
    .from("ai_agent_runs")
    .insert({
      agent_id: agent?.id ?? null,
      agent_version_id: version?.id ?? null,
      agent_key: agentKey,
      workflow_id: workflowId,
      trigger: "workflow",
      triggered_by: adminId,
      status: "running",
    })
    .select("id")
    .single();
  const runId = run?.id ?? null;

  const fail = async (msg: string) => {
    if (runId) {
      await admin.from("ai_agent_runs").update({
        status: "failed", error_message: msg, output_valid: false, completed_at: new Date().toISOString(),
      }).eq("id", runId);
    }
    return { ok: false, runId, error: msg, output: null };
  };

  if (!agent || !agent.enabled) return await fail("Agent inconnu ou désactivé.");
  if (agent.runtime !== "edge_function" || !version?.edge_function_name || version.edge_function_name === "gateway_native") {
    return await fail(
      agent.runtime === "gateway_native"
        ? "Agent défini côté Gateway FastAPI (non déployé) — hors ligne."
        : "Aucune Edge Function rattachée à cet agent.",
    );
  }

  // Contexte du workflow = entrée de l'étape (les étapes de démo lisent lesson_id / text depuis là).
  const { data: wf } = await admin.from("ai_workflows").select("context").eq("id", workflowId).maybeSingle();
  const input = (wf?.context ?? {}) as Record<string, unknown>;

  const started = Date.now();
  let output: any = null;
  let httpStatus = 0;
  try {
    const resp = await fetch(`${SUPABASE_URL}/functions/v1/${version.edge_function_name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${jwt}`, "apikey": ANON_KEY },
      body: JSON.stringify(input),
    });
    httpStatus = resp.status;
    const t = await resp.text();
    try { output = JSON.parse(t); } catch { output = { _raw: t.slice(0, 2000) }; }
  } catch (e: any) {
    return await fail(`Échec réseau vers ${version.edge_function_name} : ${e?.message ?? e}`);
  }

  const ok = httpStatus >= 200 && httpStatus < 300 && !output?.error;
  if (runId) {
    await admin.from("ai_agent_runs").update({
      status: ok ? "success" : "failed",
      error_message: ok ? null : (output?.error ?? `HTTP ${httpStatus}`),
      output, output_valid: ok, duration_ms: Date.now() - started,
      completed_at: new Date().toISOString(),
    }).eq("id", runId);
  }
  return { ok, runId, error: ok ? null : (output?.error ?? `HTTP ${httpStatus}`), output };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");

  try {
    const { data: userData } = await admin.auth.getUser(jwt);
    const { data: adminRow } = userData?.user?.id
      ? await admin.from("admin_users").select("id").eq("auth_user_id", userData.user.id).eq("is_active", true).maybeSingle()
      : { data: null };
    if (!adminRow) return json({ error: "Accès réservé aux administrateurs actifs." }, 403);

    const body = await req.json().catch(() => ({}));
    const resumeId: string | null = body.resume_id ?? null;

    let workflowId: string;
    let stepRows: { step_index: number; agent_key: string; title: string; status: string }[];

    if (resumeId) {
      const { data: wf } = await admin.from("ai_workflows").select("id, status").eq("id", resumeId).maybeSingle();
      if (!wf) return json({ error: "Workflow introuvable." }, 404);
      workflowId = wf.id;
      const { data: steps } = await admin
        .from("ai_workflow_steps").select("step_index, agent_key, title, status")
        .eq("workflow_id", workflowId).order("step_index");
      stepRows = steps ?? [];
      await admin.from("ai_workflows").update({ status: "running", error_message: null }).eq("id", workflowId);
    } else {
      const workflowKey: string = body.workflow_key ?? "custom_pipeline";
      const title: string = body.title ?? "Pipeline multi-agents";
      const context: Record<string, unknown> = body.context ?? {};
      const steps: { agent_key: string; title: string }[] = Array.isArray(body.steps) ? body.steps : [];
      if (steps.length === 0) return json({ error: "Aucune étape fournie." }, 400);

      const { data: wf } = await admin.from("ai_workflows").insert({
        workflow_key: workflowKey, title, status: "running", progress_pct: 0,
        context, started_by: adminRow.id,
      }).select("id").single();
      workflowId = wf!.id;
      await admin.from("ai_workflow_steps").insert(
        steps.map((s, i) => ({ workflow_id: workflowId, step_index: i, agent_key: s.agent_key, title: s.title, status: "pending" })),
      );
      stepRows = steps.map((s, i) => ({ step_index: i, agent_key: s.agent_key, title: s.title, status: "pending" }));
    }

    const total = stepRows.length;
    let done = stepRows.filter((s) => s.status === "success").length;

    for (const step of stepRows) {
      if (step.status === "success") continue;
      await admin.from("ai_workflow_steps").update({ status: "running", started_at: new Date().toISOString() })
        .eq("workflow_id", workflowId).eq("step_index", step.step_index);

      const r = await runStep(jwt, workflowId, adminRow.id, step.agent_key);

      await admin.from("ai_workflow_steps").update({
        status: r.ok ? "success" : "failed",
        run_id: r.runId, error_message: r.error, completed_at: new Date().toISOString(),
      }).eq("workflow_id", workflowId).eq("step_index", step.step_index);

      if (!r.ok) {
        await admin.from("ai_workflows").update({
          status: "failed", error_message: `Étape ${step.step_index + 1} (${step.title}) : ${r.error}`,
          progress_pct: Math.round((done / total) * 100),
        }).eq("id", workflowId);
        return json({ workflow_id: workflowId, status: "failed", completed_steps: done, total_steps: total, failed_step: step.step_index, error: r.error });
      }
      done++;
      await admin.from("ai_workflows").update({ progress_pct: Math.round((done / total) * 100) }).eq("id", workflowId);
    }

    await admin.from("ai_workflows").update({ status: "completed", progress_pct: 100, error_message: null }).eq("id", workflowId);
    return json({ workflow_id: workflowId, status: "completed", completed_steps: done, total_steps: total });
  } catch (err: any) {
    return json({ error: err?.message ?? "Erreur interne de l'exécuteur de workflow." }, 500);
  }
});
