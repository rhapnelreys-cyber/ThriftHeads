import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PAYMONGO_SECRET_KEY = Deno.env.get("PAYMONGO_SECRET_KEY")!;
const SITE_URL = Deno.env.get("SITE_URL")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", {headers:corsHeaders});
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization");

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } }
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) throw new Error("Unauthorized");

    const { order_id } = await req.json();
    if (!order_id) throw new Error("order_id is required");

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
    const { data: order, error } = await admin.from("orders")
      .select("id,order_number,total,currency,status,user_id")
      .eq("id", order_id).eq("user_id", user.id).single();
    if (error || !order) throw new Error("Order not found");
    if (order.status !== "pending_payment") throw new Error("Order is not payable");

    const amount = Math.round(Number(order.total) * 100);

    const payload = {
      data: {
        attributes: {
          line_items: [{
            currency: "PHP",
            amount,
            name: `ThriftHeads Order ${order.order_number}`,
            quantity: 1
          }],
          payment_method_types: ["gcash", "paymaya", "card"],
          description: `ThriftHeads ${order.order_number}`,
          success_url: `${SITE_URL}/orders.html?payment=success&order=${order.id}`,
          cancel_url: `${SITE_URL}/checkout.html?payment=cancelled&order=${order.id}`,
          send_email_receipt: false,
          show_description: true,
          show_line_items: true,
          reference_number: order.order_number
        }
      }
    };

    const response = await fetch("https://api.paymongo.com/v1/checkout_sessions", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(PAYMONGO_SECRET_KEY + ":")}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify(payload)
    });

    const result = await response.json();
    if (!response.ok) {
      console.error("PayMongo error", result);
      throw new Error(result?.errors?.[0]?.detail || "Unable to create payment session");
    }

    const session = result.data;
    const attrs = session.attributes || {};
    const { error: paymentError } = await admin.from("payments").upsert({
      order_id: order.id,
      provider: "paymongo",
      provider_checkout_session_id: session.id,
      status: "pending",
      amount: order.total,
      currency: order.currency,
      metadata: { payment_session_created: true }
    }, { onConflict: "provider,provider_checkout_session_id" });
    if (paymentError) throw paymentError;

    return new Response(JSON.stringify({
      checkout_url: attrs.checkout_url,
      session_id: session.id
    }), {headers:{...corsHeaders,"Content-Type":"application/json"}});
  } catch (e) {
    return new Response(JSON.stringify({error: e.message}), {
      status: 400, headers:{...corsHeaders,"Content-Type":"application/json"}
    });
  }
});
