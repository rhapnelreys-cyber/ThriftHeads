import { supabase } from "./supabase.js";
import { toast } from "./utils.js";

export async function getOrCreateCart(userId) {
  let { data } = await supabase.from("carts").select("id").eq("user_id", userId).maybeSingle();
  if (data) return data;
  const res = await supabase.from("carts").insert({user_id:userId}).select("id").single();
  if (res.error) throw res.error;
  return res.data;
}

export async function getCart(userId) {
  const cart = await getOrCreateCart(userId);
  return supabase.from("cart_items")
    .select("id,quantity,product_id,products(id,name,price,stock,status,product_images(storage_path,sort_order,is_primary))")
    .eq("cart_id",cart.id)
    .order("created_at",{ascending:false});
}

export async function addToCart(userId, productId, quantity=1) {
  const cart = await getOrCreateCart(userId);
  const { data: p, error: pe } = await supabase.from("products").select("stock,status").eq("id",productId).single();
  if (pe) throw pe;
  if (p.status !== "active" || p.stock < quantity) throw new Error("This item is no longer available.");
  const { data: existing } = await supabase.from("cart_items").select("id,quantity").eq("cart_id",cart.id).eq("product_id",productId).maybeSingle();
  if (existing) {
    const next = existing.quantity + quantity;
    if (next > p.stock) throw new Error("Not enough stock.");
    return supabase.from("cart_items").update({quantity:next}).eq("id",existing.id);
  }
  return supabase.from("cart_items").insert({cart_id:cart.id,product_id:productId,quantity});
}

export async function removeCartItem(id) {
  return supabase.from("cart_items").delete().eq("id",id);
}

export async function clearCart(userId) {
  const cart = await getOrCreateCart(userId);
  return supabase.from("cart_items").delete().eq("cart_id",cart.id);
}
