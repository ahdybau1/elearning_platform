// Tuteur IA élève (§8 du cahier des charges) — proxy vers Google Gemini (palier gratuit), pour que
// la clé API ne soit jamais exposée dans le bundle Flutter web (voir student_app/
// ai_tutor_chat_screen.dart). Choix Gemini explicitement demandé par l'utilisateur : "totalement
// gratuit", palier temporaire en attendant un agent IA propriétaire construit ultérieurement (voir
// mémoire projet_ai_tutor_backend_choice).
import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { message, subject_name, class_name, history } = await req.json();

    if (!message || typeof message !== "string" || message.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Message manquant." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!GEMINI_API_KEY) {
      // Jamais de réponse simulée en secours (voir 06_ai_pipeline.md) : une erreur claire côté
      // client vaut mieux qu'une fausse réussite.
      return new Response(
        JSON.stringify({ error: "Le Tuteur IA n'est pas encore configuré (clé Gemini absente côté serveur)." }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const systemPrompt = `Tu es un tuteur pédagogique bienveillant pour un(e) élève de ${class_name ?? "l'enseignement secondaire"}, en ${subject_name ?? "toutes matières"}.
Règles strictes :
- Maïeutique uniquement : guide l'élève pas à pas vers la réponse, ne donne JAMAIS directement la solution finale d'un exercice.
- Reste toujours dans le programme officiel de sa classe, sans bloquer totalement le hors-programme si l'élève insiste.
- Explique les erreurs (le "pourquoi"), jamais un simple "faux".
- Public mineur : langage toujours approprié, aucun sujet inapproprié, refuse poliment et détourne vers l'aide scolaire si l'élève dévie du cadre pédagogique.
- Réponses courtes et claires, en français, formules mathématiques entre $...$ si besoin.
- Tu es un outil d'aide, jamais une autorité absolue : encourage à vérifier avec son professeur en cas de doute.`;

    const contents = [];
    if (Array.isArray(history)) {
      for (const turn of history.slice(-10)) {
        contents.push({
          role: turn.sender === "ai" ? "model" : "user",
          parts: [{ text: String(turn.text ?? "") }],
        });
      }
    }
    contents.push({ role: "user", parts: [{ text: message }] });

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents,
          generationConfig: { maxOutputTokens: 800 },
        }),
      }
    );

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error("Gemini API error:", geminiRes.status, errText);
      return new Response(
        JSON.stringify({ error: "Le Tuteur IA est momentanément indisponible (quota atteint ou erreur du fournisseur)." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiData = await geminiRes.json();
    const reply = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const tokensUsed = geminiData.usageMetadata?.totalTokenCount ?? 0;

    if (!reply) {
      return new Response(
        JSON.stringify({ error: "Le Tuteur IA n'a pas pu générer de réponse. Réessayez avec une question différente." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      await supabase.from("ai_agent_calls").insert({
        agent_type: "student_tutor_chat",
        provider: "gemini",
        tokens_used: tokensUsed,
        cost_estimate: 0,
      });
    } catch (insertErr) {
      console.error("Échec d'enregistrement ai_agent_calls:", insertErr);
    }

    return new Response(JSON.stringify({ reply }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("AI Tutor Chat Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
