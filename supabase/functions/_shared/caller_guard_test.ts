// deno test --allow-env supabase/functions/_shared/caller_guard_test.ts
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-secret-key");
const { requireAdminOrService } = await import("./caller_guard.ts");

const cors = { "Access-Control-Allow-Origin": "*" };

// Client Supabase factice : deux utilisateurs connus, dont un seul est admin actif.
function fakeSupabase() {
  const users: Record<string, string> = { "jwt-admin": "u-admin", "jwt-eleve": "u-eleve" };
  return {
    auth: {
      getUser: (token: string) =>
        Promise.resolve(users[token]
          ? { data: { user: { id: users[token] } }, error: null }
          : { data: { user: null }, error: new Error("invalid") }),
    },
    from: (_table: string) => {
      let authUserId = "";
      const q = {
        select: () => q,
        eq: (col: string, val: string) => { if (col === "auth_user_id") authUserId = val; return q; },
        maybeSingle: () => Promise.resolve({ data: authUserId === "u-admin" ? { id: "a1" } : null }),
      };
      return q;
    },
  // deno-lint-ignore no-explicit-any
  } as any;
}

function req(token?: string) {
  return new Request("http://x", { method: "POST", headers: token ? { Authorization: `Bearer ${token}` } : {} });
}

async function status(token: string | undefined, serviceOnly = false) {
  const r = await requireAdminOrService(req(token), fakeSupabase(), cors, { serviceOnly });
  return r ? r.status : 200;
}

function assertEq(a: unknown, b: unknown, msg: string) {
  if (a !== b) throw new Error(`${msg} : attendu ${b}, obtenu ${a}`);
}

Deno.test("sans jeton → 401", async () => assertEq(await status(undefined), 401, "sans jeton"));
Deno.test("jeton invalide → 401", async () => assertEq(await status("n-importe-quoi"), 401, "invalide"));
Deno.test("élève connecté → 403", async () => assertEq(await status("jwt-eleve"), 403, "élève"));
Deno.test("admin actif → autorisé", async () => assertEq(await status("jwt-admin"), 200, "admin"));
Deno.test("clé service → autorisé", async () => assertEq(await status("service-secret-key"), 200, "service"));
Deno.test("cron : admin refusé", async () => assertEq(await status("jwt-admin", true), 403, "cron admin"));
Deno.test("cron : clé service autorisée", async () => assertEq(await status("service-secret-key", true), 200, "cron service"));
