import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Création d'un compte parent depuis l'app admin (Section 2.16 du CDC : "Compte parent distinct").
// Même raisonnement que admin-create-student-account : créer un utilisateur Supabase Auth pour
// quelqu'un d'autre exige service_role, jamais exposé au client — voir 01_rls_security.md.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const callerToken = authHeader.replace(/^Bearer\s+/i, "");
    if (!callerToken) {
      return new Response(JSON.stringify({ error: "Non authentifié" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: callerData, error: callerError } = await supabase.auth.getUser(callerToken);
    if (callerError || !callerData.user) {
      return new Response(JSON.stringify({ error: "Session invalide" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: adminRow } = await supabase
      .from("admin_users")
      .select("id, is_active")
      .eq("auth_user_id", callerData.user.id)
      .maybeSingle();

    if (!adminRow || !adminRow.is_active) {
      return new Response(
        JSON.stringify({ error: "Accès refusé : réservé aux administrateurs actifs" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { email, password, first_name, last_name, phone } = await req.json();

    if (!email || !password || !first_name || !last_name || !phone) {
      return new Response(
        JSON.stringify({
          error: "Paramètres manquants : email, password, first_name, last_name, phone requis",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: authUser, error: authCreateError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authCreateError || !authUser.user) {
      return new Response(
        JSON.stringify({ error: authCreateError?.message ?? "Échec de création du compte Auth" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: parentRow, error: parentError } = await supabase
      .from("parent_accounts")
      .insert({
        auth_user_id: authUser.user.id,
        email,
        phone,
        first_name,
        last_name,
      })
      .select()
      .single();

    if (parentError) {
      await supabase.auth.admin.deleteUser(authUser.user.id);
      return new Response(JSON.stringify({ error: parentError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ parent_account: parentRow }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Admin Create Parent Account Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
