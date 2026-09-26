import { supabase } from "./supabase.js";
import { toast } from "./utils.js";

export async function getUser() {
  const { data } = await supabase.auth.getUser();
  return data.user;
}

export async function login(email, password) {
  return supabase.auth.signInWithPassword({ email, password });
}

export async function register(email, password, firstName, lastName) {
  return supabase.auth.signUp({
    email, password,
    options: { data: { first_name: firstName, last_name: lastName } }
  });
}

export async function logout() {
  await supabase.auth.signOut();
  location.href = "index.html";
}

export async function requireRole(roles=["admin"]) {
  const user = await getUser();
  if (!user) { location.href = "../auth.html"; return null; }
  const { data: profile } = await supabase.from("profiles").select("role,is_active").eq("id", user.id).single();
  if (!profile?.is_active || !roles.includes(profile.role)) {
    document.body.innerHTML = `<main class="min-h-screen grid place-items-center p-8"><div class="text-center"><h1 class="text-3xl font-black">ACCESS DENIED</h1><p class="mt-2 text-neutral-500">You do not have permission to view this page.</p><a class="inline-block mt-6 underline" href="../index.html">Return home</a></div></main>`;
    return null;
  }
  return { user, profile };
}
