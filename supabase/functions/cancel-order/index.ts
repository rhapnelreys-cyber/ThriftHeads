import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok",{headers:corsHeaders});
  try {
    const auth = req.headers.get("Authorization");
    if (!auth) throw new Error("Unauthorized");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {global:{headers:{Authorization:auth}}}
    );
    const {data:{user}} = await supabase.auth.getUser();
    if (!user) throw new Error("Unauthorized");
    const {order_id} = await req.json();
    const {data: order, error} = await supabase.from("orders").select("id,status").eq("id",order_id).eq("user_id",user.id).single();
    if(error || !order) throw new Error("Order not found");
    if(order.status !== "pending_payment") throw new Error("Only unpaid orders can be cancelled here.");
    const {error: updateError} = await supabase.from("orders").update({status:"cancelled",cancelled_at:new Date().toISOString()}).eq("id",order_id);
    if(updateError) throw updateError;
    return new Response(JSON.stringify({ok:true}),{headers:{...corsHeaders,"Content-Type":"application/json"}});
  } catch(e) {
    return new Response(JSON.stringify({error:e.message}),{status:400,headers:{...corsHeaders,"Content-Type":"application/json"}});
  }
});
