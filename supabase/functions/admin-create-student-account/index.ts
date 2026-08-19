import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Création d'un compte élève + profil depuis l'app admin (Section 3.5 du CDC : "Comptes élève").
// Le client ne peut pas faire ceci seul : créer un utilisateur Supabase Auth pour quelqu'un d'autre
// et lier accounts.auth_user_id exige service_role, jamais exposé au client — voir 01_rls_security.md.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Vérifier que l'appelant est un admin actif — un JWT valide prouve une identité, jamais un
    // rôle (voir 03_auth_flow.md). On ne fait confiance à aucune donnée envoyée par le client pour
    // ça, uniquement à admin_users résolu via service_role.
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

    // 2. Valider les paramètres
    const { email, password, first_name, last_name, phone, class_node_id, school_year } =
      await req.json();

    if (!email || !password || !first_name || !last_name || !class_node_id || !school_year) {
      return new Response(
        JSON.stringify({
          error:
            "Paramètres manquants : email, password, first_name, last_name, class_node_id, school_year requis",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Créer l'utilisateur Supabase Auth
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

    // 4. Créer la ligne accounts (liée dès la création — jamais de compte non lié, voir
    // 03_auth_flow.md)
    const { data: accountRow, error: accountError } = await supabase
      .from("accounts")
      .insert({
        auth_user_id: authUser.user.id,
        email,
        phone: phone ?? null,
        first_name,
        last_name,
      })
      .select()
      .single();

    if (accountError) {
      // Repli : supprimer l'utilisateur Auth orphelin plutôt que de le laisser sans compte lié.
      await supabase.auth.admin.deleteUser(authUser.user.id);
      return new Response(JSON.stringify({ error: accountError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 5. Créer le premier profil (classe + abonnement gratuit par défaut)
    const { data: profileRow, error: profileError } = await supabase
      .from("profiles")
      .insert({
        account_id: accountRow.id,
        class_node_id,
        school_year,
        subscription_tier: "gratuit",
        status: "actif",
      })
      .select()
      .single();

    if (profileError) {
      return new Response(
        JSON.stringify({
          error: `Compte créé mais échec de création du profil : ${profileError.message}`,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ account: accountRow, profile: profileRow }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Admin Create Student Account Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
