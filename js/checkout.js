import { supabase } from "./supabase.js";

export async function createOrder(addressId, shippingFee, note="") {
  const { data, error } = await supabase.rpc("create_order_from_cart", {
    p_address_id: addressId, p_shipping_fee: shippingFee, p_customer_note: note || null
  });
  if (error) throw error;
  return data?.[0];
}

export async function startPayment(orderId) {
  const { data, error } = await supabase.functions.invoke("create-payment", {
    body: { order_id: orderId }
  });
  if (error) throw error;
  if (!data?.checkout_url) throw new Error("Payment checkout URL was not returned.");
  location.href = data.checkout_url;
}
