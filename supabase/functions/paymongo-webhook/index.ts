import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("PAYMONGO_WEBHOOK_SECRET")!;

async function verifySignature(rawBody: string, signature: string) {
  // PayMongo webhook signature formats can change. Configure the secret and
  // verify against the exact signing scheme shown in your current PayMongo
  // dashboard/API documentation before enabling live money movement.
  // This function intentionally fails closed rather than accepting unsigned events.
  if (!signature || !WEBHOOK_SECRET) return false;
  // HMAC-SHA256 fallback verifier for common webhook signing setups.
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(WEBHOOK_SECRET),
    {name:"HMAC",hash:"SHA-256"}, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected = Array.from(new Uint8Array(sig)).map(b=>b.toString(16).padStart(2,"0")).join("");
  const supplied = signature.replace(/^sha256=/i,"").trim();
  return supplied === expected;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed",{status:405});
  const raw = await req.text();
  const signature = req.headers.get("Paymongo-Signature") || req.headers.get("X-PayMongo-Signature") || "";
  if (!(await verifySignature(raw, signature))) {
    return new Response("Invalid webhook signature",{status:401});
  }

  try {
    const event = JSON.parse(raw);
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
    const eventId = event?.data?.id || event?.id || crypto.randomUUID();
    const type = event?.data?.attributes?.type || event?.type || "";
    const attrs = event?.data?.attributes?.data?.attributes || event?.data?.attributes || {};
    const sessionId = attrs?.checkout_session_id || attrs?.checkout_session?.id || event?.data?.attributes?.data?.id;

    if (!sessionId) return new Response(JSON.stringify({ok:true,ignored:true}),{status:200});

    const { data: payment } = await admin.from("payments")
      .select("id,order_id,amount,status")
      .eq("provider","paymongo")
      .eq("provider_checkout_session_id",sessionId)
      .maybeSingle();

    if (!payment) return new Response(JSON.stringify({ok:true,unmatched:true}),{status:200});

    const paid = /paid|succeeded|completed|checkout_session.payment.paid/i.test(type);

    await admin.from("payments").update({
      status: paid ? "paid" : "pending",
      raw_event_id: eventId,
      paid_at: paid ? new Date().toISOString() : null,
      metadata: { event_type:type }
    }).eq("id",payment.id);

    if (paid) {
      await admin.rpc("mark_order_paid", {
        p_order_id: payment.order_id,
        p_provider_payment_id: sessionId,
        p_provider_checkout_session_id: sessionId,
        p_payment_method: "paymongo"
      });
    }

    return new Response(JSON.stringify({ok:true}),{status:200});
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({error:e.message}),{status:500});
  }
});
