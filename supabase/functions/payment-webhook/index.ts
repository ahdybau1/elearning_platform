import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Aucun secret de repli en dur : configuration manquante = échec explicite au démarrage plutôt
// qu'une valeur par défaut connue de tous (voir 04_payment_webhook_security.md).
const WEBHOOK_SECRET = Deno.env.get("PAYMENT_WEBHOOK_SECRET");
if (!WEBHOOK_SECRET) {
  throw new Error("PAYMENT_WEBHOOK_SECRET manquant — configuration incomplète.");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

async function computeHmacSha256(secret: string, data: string): Promise<Uint8Array> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signatureBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(data));
  return new Uint8Array(signatureBuffer);
}

function hexToBytes(hex: string): Uint8Array | null {
  if (hex.length % 2 !== 0 || !/^[0-9a-fA-F]*$/.test(hex)) return null;
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

// Comparaison à temps constant sur les octets (pas de `===` sur des chaînes hex, qui fuit la
// position du premier octet différent — voir 04_payment_webhook_security.md).
function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

async function verifyHmacSha256(secret: string, data: string, providedHexSignature: string): Promise<boolean> {
  try {
    const providedBytes = hexToBytes(providedHexSignature);
    if (!providedBytes) return false;
    const expectedBytes = await computeHmacSha256(secret, data);
    return timingSafeEqual(expectedBytes, providedBytes);
  } catch (_) {
    return false;
  }
}

async function logAnomaly(issueType: string, transactionId: string | null, notes: string) {
  try {
    await supabase.from("payment_reconciliation").insert({
      transaction_id: transactionId ?? "00000000-0000-0000-0000-000000000001",
      issue_type: issueType,
      notes,
      status: "pending",
    });
  } catch (err) {
    console.error("Impossible de journaliser l'anomalie webhook:", err);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const signature = req.headers.get("x-webhook-signature");
    const rawBody = await req.text();

    // Une requête sans signature valide est toujours rejetée — aucune exception (Section 32.1 du
    // CDC / 04_payment_webhook_security.md).
    if (!signature) {
      console.warn("Webhook paiement reçu sans header de signature — rejeté.");
      return new Response(JSON.stringify({ error: "Signature manquante" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isValid = await verifyHmacSha256(WEBHOOK_SECRET!, rawBody, signature);
    if (!isValid) {
      console.warn("Signature HMAC invalide reçue pour le webhook paiement.");
      return new Response(JSON.stringify({ error: "Signature HMAC invalide" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload = JSON.parse(rawBody);
    const {
      transaction_id,
      aggregator_ref,
      status, // 'success', 'successful', 'failed', 'pending'
      operator,
      phone_number,
      amount,
    } = payload;

    console.log(`Traitement Webhook Paiement : Transaction=${transaction_id}, Statut=${status}`);

    if (!transaction_id) {
      await logAnomaly("missing_transaction_id", null, `Webhook sans transaction_id. Payload: ${rawBody}`);
      return new Response(JSON.stringify({ error: "transaction_id manquant" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Récupérer la transaction d'origine AVANT toute mise à jour — le webhook ne doit jamais
    // faire confiance aveuglément à transaction_id + amount fournis par l'agrégateur.
    const { data: existingTx, error: fetchError } = await supabase
      .from("transactions")
      .select("id, amount, status")
      .eq("id", transaction_id)
      .maybeSingle();

    if (fetchError || !existingTx) {
      await logAnomaly(
        "orphaned_webhook",
        transaction_id,
        `Webhook orphelin reçu pour transaction_id: ${transaction_id}. Payload: ${rawBody}`
      );
      return new Response(JSON.stringify({ status: "logged_for_reconciliation" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Idempotence : un webhook déjà traité (statut terminal) ne doit pas redéclencher le cumul
    // mensuel ni aucun autre effet de bord une seconde fois.
    if (existingTx.status === "success" || existingTx.status === "failed") {
      return new Response(JSON.stringify({ status: "already_processed", transaction_id }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isSuccess = status === "successful" || status === "success";

    // 3. Cohérence du montant : un écart bascule en réconciliation manuelle plutôt que d'être
    // validé silencieusement (Section 4.3 du CDC).
    if (isSuccess && typeof amount === "number" && Number(amount) !== Number(existingTx.amount)) {
      await supabase
        .from("transactions")
        .update({
          status: "ambiguous",
          aggregator_ref: aggregator_ref,
          phone_number: phone_number,
          updated_at: new Date().toISOString(),
        })
        .eq("id", transaction_id);

      await logAnomaly(
        "amount_mismatch",
        transaction_id,
        `Montant reçu ${amount} ne correspond pas au montant attendu ${existingTx.amount}.`
      );

      return new Response(JSON.stringify({ status: "amount_mismatch_flagged", transaction_id }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Mise à jour de la transaction (le trigger PostgreSQL handle_monthly_spend_accumulation met
    // à jour le cumul mensuel automatiquement si status = 'success').
    const { error: updateError } = await supabase
      .from("transactions")
      .update({
        status: isSuccess ? "success" : "failed",
        aggregator_ref: aggregator_ref,
        phone_number: phone_number,
        updated_at: new Date().toISOString(),
      })
      .eq("id", transaction_id);

    if (updateError) {
      console.error("Erreur mise à jour transaction:", updateError);
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true, transaction_id }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Erreur d'exécution webhook:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message ?? String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
