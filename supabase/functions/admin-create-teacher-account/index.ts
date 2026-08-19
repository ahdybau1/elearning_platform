import { createClient } from "npm:@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Création d'un compte enseignant (Section 5.4 / 22 du CDC) : contrairement à admin-create-student-account
// et admin-create-parent-account (déjà déployées), il n'existait encore AUCUNE fonction créant un vrai
// compte Supabase Auth pour un enseignant — la page "Enseignants & Écoles" insérait auparavant (en fait
// n'insérait même pas : les boutons étaient factices) sans jamais permettre à l'enseignant de se connecter.
// `is_active` peut être false à la création : le compte Auth existe (l'enseignant pourra un jour se
// connecter) mais `is_admin_user()` le traite comme inactif tant qu'un admin n'a pas approuvé la demande.
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

    // Section 5.4 / 22 du CDC : la création d'un compte enseignant (attribution d'un email + mot de
    // passe) est réservée au Super-admin ou à l'admin d'un pays — jamais à un admin_contenu, modérateur,
    // support, ni à un enseignant lui-même. La restriction de navigation côté Flutter n'est qu'une
    // commodité d'UX ; c'est cette vérification serveur qui fait réellement foi.
    if (!adminRow || !adminRow.is_active || !["super_admin", "admin_pays"].includes(adminRow.role)) {
      return new Response(
        JSON.stringify({
          error: "Accès refusé : la création d'un compte enseignant est réservée au Super-administrateur ou à l'admin d'un pays",
        }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { email, password, first_name, last_name, is_active } = await req.json();

    if (!email || !password || !first_name || !last_name) {
      return new Response(
        JSON.stringify({
          error: "Paramètres manquants : email, password, first_name, last_name requis",
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

    const { data: teacherRow, error: teacherError } = await supabase
      .from("admin_users")
      .insert({
        auth_user_id: authUser.user.id,
        email,
        first_name,
        last_name,
        role: "enseignant",
        is_active: is_active ?? true,
      })
      .select()
      .single();

    if (teacherError) {
      await supabase.auth.admin.deleteUser(authUser.user.id);
      return new Response(JSON.stringify({ error: teacherError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ teacher: teacherRow }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Admin Create Teacher Account Error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
