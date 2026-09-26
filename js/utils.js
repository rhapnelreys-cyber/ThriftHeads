export const money = (n) => new Intl.NumberFormat("en-PH", {
  style: "currency", currency: "PHP", maximumFractionDigits: 2
}).format(Number(n || 0));

export const qs = (s, r=document) => r.querySelector(s);
export const qsa = (s, r=document) => [...r.querySelectorAll(s)];

export function escapeHtml(v="") {
  return String(v).replace(/[&<>"']/g, c => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
  }[c]));
}

export function toast(message, type="info") {
  const el = document.createElement("div");
  el.className = `fixed bottom-5 right-5 z-[100] max-w-sm rounded-xl px-4 py-3 text-sm shadow-2xl ${type==="error" ? "bg-red-600 text-white" : "bg-black text-white"}`;
  el.textContent = message;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3000);
}

export async function requireUser(supabase) {
  const { data } = await supabase.auth.getUser();
  if (!data.user) {
    location.href = `auth.html?redirect=${encodeURIComponent(location.href)}`;
    return null;
  }
  return data.user;
}
