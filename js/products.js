import { supabase } from "./supabase.js";

export async function getProducts({ search="", category="", limit=48 }={}) {
  let q = supabase.from("products")
    .select("id,name,slug,sku,brand,size,color,condition,price,stock,status,is_featured,is_one_of_one,category_id,categories(name),product_images(storage_path,sort_order,is_primary)")
    .eq("status","active")
    .order("created_at",{ascending:false})
    .limit(limit);
  if (category) q = q.eq("category_id", category);
  if (search) q = q.or(`name.ilike.%${search}%,brand.ilike.%${search}%,description.ilike.%${search}%`);
  return q;
}
