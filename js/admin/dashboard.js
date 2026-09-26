import { supabase } from "../supabase.js";
import { money } from "../utils.js";
import { requireRole } from "../auth.js";

const auth = await requireRole(["admin","staff"]);
if (auth) {
  const [{data: sales}, {count: orders}, {count: products}] = await Promise.all([
    supabase.from("orders").select("total").in("status",["paid","processing","packed","shipped","in_transit","out_for_delivery","delivered"]),
    supabase.from("orders").select("*",{count:"exact",head:true}),
    supabase.from("products").select("*",{count:"exact",head:true}).neq("status","archived")
  ]);
  const total = (sales||[]).reduce((a,x)=>a+Number(x.total||0),0);
  document.querySelector("#sales").textContent = money(total);
  document.querySelector("#orders").textContent = orders ?? 0;
  document.querySelector("#products").textContent = products ?? 0;
}
