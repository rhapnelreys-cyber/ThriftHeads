# THRIFTHEADS® — Production Ecommerce Starter

ThriftHeads is a production-oriented vanilla HTML + Tailwind CSS + JavaScript storefront backed by Supabase and PayMongo.

## Stack
- HTML5
- Tailwind CSS via CDN for the no-build static frontend
- Vanilla JavaScript ES modules
- Supabase Auth / PostgreSQL / Storage / Realtime / RLS
- Supabase Edge Functions
- PayMongo Checkout + webhook

## Important production setup
The application code is complete, but no software can safely ship with someone else's private credentials embedded in it. Before launch, set the Supabase URL/anon key in `js/config.js`, and set PayMongo/Supabase secrets in Supabase Edge Function secrets. Never put a service-role key or PayMongo secret key in browser JavaScript.

## Setup
1. Create a Supabase project.
2. Run `supabase/migrations/001_initial_schema.sql` in Supabase SQL Editor.
3. Create the `product-images` storage bucket if the migration did not create it.
4. Set `js/config.js` values:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
5. Deploy the three Edge Functions in `supabase/functions/`.
6. Set Edge Function secrets:
   - PAYMONGO_SECRET_KEY
   - PAYMONGO_WEBHOOK_SECRET
   - SITE_URL
   - SUPABASE_URL
   - SUPABASE_SERVICE_ROLE_KEY
7. In Supabase Auth, configure your production Site URL and redirect URLs.
8. Create your first account, then promote it to `admin` with a secure SQL statement from the admin setup section below.
9. Deploy the static files to Render, Netlify, Cloudflare Pages, GitHub Pages (with appropriate routing), or another static host.
10. Replace placeholder policy/contact information before public launch.

## First admin
After registering:
```sql
update public.profiles
set role = 'admin'
where email = 'YOUR-ADMIN-EMAIL@example.com';
```

Do not expose the service role key in the browser.

## Included
- Customer storefront
- Search and category filtering
- Product details
- Cart
- Auth
- Wishlist
- Checkout/order creation
- PayMongo checkout initiation
- Payment webhook handling
- Customer order history
- Order tracking timeline
- Admin dashboard
- Product CRUD/archive
- Inventory
- Orders and shipment tracking
- Sales summary
- Categories
- RLS policies
- Product image storage policies

## Before launch
Test payments in PayMongo's test/sandbox environment, test webhook delivery, test stock race conditions, configure real courier/shipping rules, publish accurate privacy/returns/terms pages, and verify tax/business requirements for your jurisdiction.
