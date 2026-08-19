import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CREATABLE_ROLES = ["admin_pays", "admin_contenu", "enseignant", "moderateur", "support"];

// Section 13.1 / 13.4 du CDC : avant cette fonction, "Créer un Compte Administrateur" faisait un simple
// INSERT dans admin_users SANS jamais créer de compte Supabase Auth — l'administrateur créé n'avait
// littéralement aucun moyen de se connecter (pas d'email/mot de passe attribué). Réservé au Super-admin
// uniquement ("pouvoir total et sans restriction" — §13.4), à l'exclusion du rôle super_admin lui-même
// (action trop sensible pour ce formulaire générique).
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
      .select("id, is_active, role")
      .eq("auth_user_id", callerData.user.id)
      .maybeSingle();

    if (!adminRow || !adminRow.is_active || adminRow.role !== "super_admin") {
      return new Response(
        JSON.stringify({ error: "Accès refusé : réservé au Super-administrateur" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { email, password, first_name, last_name, role } = await req.json();

    if (!email || !password || !first_name || !last_name || !role) {
      return new Response(
        JSON.stringify({
          error: "Paramètres manquants : email, password, first_name, last_name, role requis",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!CREATABLE_ROLES.includes(role)) {
      return new Response(
        JSON.stringify({ error: `Rôle invalide. Rôles autorisés : ${CREATABLE_ROLES.join(", ")}` }),
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

    const { data: newAdminRow, error: insertError } = await supabase
      .from("admin_users")
      .insert({
        auth_user_id: authUser.user.id,
        email,
        first_name,
        last_name,
        role,
        is_active: true,
      })
      .select()
      .single();

    if (insertError) {
      await supabase.auth.admin.deleteUser(authUser.user.id);
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ admin: newAdminRow }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Admin Create Admin Account Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
