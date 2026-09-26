begin;

create extension if not exists pgcrypto;
create extension if not exists citext;

do $$ begin create type public.user_role as enum ('customer','staff','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.product_condition as enum ('new_with_tags','new_without_tags','excellent','very_good','good','fair'); exception when duplicate_object then null; end $$;
do $$ begin create type public.product_status as enum ('draft','active','reserved','sold','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type public.order_status as enum ('pending_payment','paid','processing','packed','shipped','in_transit','out_for_delivery','delivered','cancelled','refunded'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_status as enum ('pending','paid','failed','cancelled','refunded','partially_refunded'); exception when duplicate_object then null; end $$;
do $$ begin create type public.shipment_status as enum ('pending','label_created','picked_up','sorting','in_transit','arrived_at_hub','out_for_delivery','delivered','exception','returned'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 email citext, first_name text, last_name text, phone text, avatar_url text,
 role public.user_role not null default 'customer', is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,email,first_name,last_name)
 values(new.id,new.email,nullif(new.raw_user_meta_data->>'first_name',''),nullif(new.raw_user_meta_data->>'last_name',''))
 on conflict(id) do update set email=excluded.email;
 return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create table if not exists public.addresses(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 label text not null default 'Home', recipient_name text not null, phone text not null,
 line1 text not null, line2 text, barangay text, city text not null, province text not null,
 postal_code text not null, country text not null default 'PH', is_default boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index if not exists uq_default_address on public.addresses(user_id) where is_default=true;

create table if not exists public.categories(
 id uuid primary key default gen_random_uuid(), name text not null, slug citext unique not null,
 description text, image_url text, sort_order integer not null default 0, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.products(
 id uuid primary key default gen_random_uuid(), category_id uuid references public.categories(id) on delete set null,
 sku text unique not null, name text not null, slug citext unique not null, description text, brand text,
 size text, color text, condition public.product_condition not null default 'very_good',
 price numeric(12,2) not null check(price>=0), compare_at_price numeric(12,2),
 currency char(3) not null default 'PHP', stock integer not null default 1 check(stock>=0),
 status public.product_status not null default 'draft', is_featured boolean not null default false,
 is_one_of_one boolean not null default true, weight_grams integer, metadata jsonb not null default '{}',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), sold_at timestamptz
);

create table if not exists public.product_images(
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
 storage_path text not null, alt_text text, sort_order integer not null default 0, is_primary boolean not null default false,
 created_at timestamptz not null default now()
);
create unique index if not exists uq_primary_image on public.product_images(product_id) where is_primary=true;

create table if not exists public.wishlist(
 user_id uuid not null references public.profiles(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(user_id,product_id)
);

create table if not exists public.carts(
 id uuid primary key default gen_random_uuid(), user_id uuid unique references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.cart_items(
 id uuid primary key default gen_random_uuid(), cart_id uuid not null references public.carts(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade, quantity integer not null check(quantity>0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(cart_id,product_id)
);

create table if not exists public.orders(
 id uuid primary key default gen_random_uuid(), order_number text unique not null,
 user_id uuid not null references public.profiles(id) on delete restrict,
 status public.order_status not null default 'pending_payment',
 subtotal numeric(12,2) not null check(subtotal>=0), shipping_fee numeric(12,2) not null default 0 check(shipping_fee>=0),
 discount numeric(12,2) not null default 0, total numeric(12,2) not null check(total>=0), currency char(3) not null default 'PHP',
 recipient_name text not null, phone text not null, shipping_address jsonb not null, customer_note text,
 payment_due_at timestamptz, paid_at timestamptz, shipped_at timestamptz, delivered_at timestamptz, cancelled_at timestamptz,
 metadata jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.order_items(
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null, product_name text not null, sku text, product_image text,
 quantity integer not null check(quantity>0), unit_price numeric(12,2) not null check(unit_price>=0),
 line_total numeric(12,2) not null check(line_total>=0), metadata jsonb not null default '{}', created_at timestamptz not null default now()
);

create table if not exists public.order_status_history(
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 status public.order_status not null, title text, description text, created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now()
);

create table if not exists public.payments(
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete restrict,
 provider text not null default 'paymongo', provider_payment_id text, provider_checkout_session_id text,
 status public.payment_status not null default 'pending', amount numeric(12,2) not null check(amount>0),
 currency char(3) not null default 'PHP', payment_method text, paid_at timestamptz,
 raw_event_id text, metadata jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index if not exists uq_payment_provider_id on public.payments(provider,provider_payment_id) where provider_payment_id is not null;
create unique index if not exists uq_payment_checkout on public.payments(provider,provider_checkout_session_id) where provider_checkout_session_id is not null;
create unique index if not exists uq_payment_event on public.payments(provider,raw_event_id) where raw_event_id is not null;

create table if not exists public.shipments(
 id uuid primary key default gen_random_uuid(), order_id uuid unique not null references public.orders(id) on delete cascade,
 courier text, service text, tracking_number text, status public.shipment_status not null default 'pending',
 shipped_at timestamptz, estimated_delivery_at timestamptz, delivered_at timestamptz,
 metadata jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.tracking_events(
 id uuid primary key default gen_random_uuid(), shipment_id uuid not null references public.shipments(id) on delete cascade,
 status public.shipment_status not null, title text not null, description text, location text,
 occurred_at timestamptz not null default now(), provider_event_id text, metadata jsonb not null default '{}'
);

create or replace function public.is_admin_or_staff() returns boolean language sql stable security definer set search_path=public as $$
select exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','staff') and is_active=true)
$$;

create or replace function public.create_order_from_cart(p_address_id uuid,p_shipping_fee numeric default 0,p_customer_note text default null)
returns table(order_id uuid,order_number text,total numeric)
language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); cid uuid; oid uuid; onum text; sub numeric(12,2):=0; addr jsonb; i record; p record;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 select id into cid from public.carts where user_id=uid;
 if cid is null then raise exception 'Cart not found'; end if;
 select jsonb_build_object('id',id,'label',label,'recipient_name',recipient_name,'phone',phone,'line1',line1,'line2',line2,'barangay',barangay,'city',city,'province',province,'postal_code',postal_code,'country',country)
 into addr from public.addresses where id=p_address_id and user_id=uid;
 if addr is null then raise exception 'Shipping address not found'; end if;
 for i in select product_id,quantity from public.cart_items where cart_id=cid order by product_id loop
   select * into p from public.products where id=i.product_id for update;
   if not found or p.status<>'active' or p.stock<i.quantity then raise exception 'Product unavailable or insufficient stock'; end if;
   sub:=sub+(p.price*i.quantity);
 end loop;
 insert into public.orders(user_id,order_number,subtotal,shipping_fee,total,recipient_name,phone,shipping_address,customer_note,payment_due_at)
 values(uid,'TH-'||to_char(now(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),sub,p_shipping_fee,sub+p_shipping_fee,addr->>'recipient_name',addr->>'phone',addr,p_customer_note,now()+interval '30 minutes')
 returning id,order_number into oid,onum;
 for i in
   select ci.product_id,ci.quantity,p.name,p.sku,p.price,
     (select storage_path from public.product_images x where x.product_id=p.id order by x.is_primary desc,x.sort_order limit 1) img
   from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=cid order by ci.product_id
 loop
   update public.products set stock=stock-i.quantity,status=case when stock-i.quantity=0 then 'sold'::public.product_status else status end,sold_at=case when stock-i.quantity=0 then now() else sold_at end where id=i.product_id;
   insert into public.order_items(order_id,product_id,product_name,sku,product_image,quantity,unit_price,line_total)
   values(oid,i.product_id,i.name,i.sku,i.img,i.quantity,i.price,i.price*i.quantity);
 end loop;
 insert into public.order_status_history(order_id,status,title,description,created_by) values(oid,'pending_payment','Order placed','Order created and awaiting payment.',uid);
 delete from public.cart_items where cart_id=cid;
 return query select oid,onum,sub+p_shipping_fee;
end $$;

revoke all on function public.create_order_from_cart(uuid,numeric,text) from public,anon,authenticated;
grant execute on function public.create_order_from_cart(uuid,numeric,text) to authenticated;

-- RLS
alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.wishlist enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.payments enable row level security;
alter table public.shipments enable row level security;
alter table public.tracking_events enable row level security;

-- Profiles
create policy "profiles own read" on public.profiles for select using(auth.uid()=id or public.is_admin_or_staff());
create policy "profiles own update" on public.profiles for update using(auth.uid()=id or public.is_admin_or_staff()) with check(auth.uid()=id or public.is_admin_or_staff());

-- Addresses
create policy "addresses own all" on public.addresses for all using(auth.uid()=user_id or public.is_admin_or_staff()) with check(auth.uid()=user_id or public.is_admin_or_staff());

-- Public catalog
create policy "public read active categories" on public.categories for select using(is_active=true or public.is_admin_or_staff());
create policy "admin manage categories" on public.categories for all using(public.is_admin_or_staff()) with check(public.is_admin_or_staff());

create policy "public read active products" on public.products for select using(status='active' or public.is_admin_or_staff());
create policy "admin manage products" on public.products for all using(public.is_admin_or_staff()) with check(public.is_admin_or_staff());

create policy "public read product images" on public.product_images for select using(
 exists(select 1 from public.products p where p.id=product_id and (p.status='active' or public.is_admin_or_staff()))
);
create policy "admin manage product images" on public.product_images for all using(public.is_admin_or_staff()) with check(public.is_admin_or_staff());

-- User data
create policy "wishlist own" on public.wishlist for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "carts own" on public.carts for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "cart items own" on public.cart_items for all using(exists(select 1 from public.carts c where c.id=cart_id and c.user_id=auth.uid())) with check(exists(select 1 from public.carts c where c.id=cart_id and c.user_id=auth.uid()));

create policy "orders own read" on public.orders for select using(auth.uid()=user_id or public.is_admin_or_staff());
create policy "orders admin update" on public.orders for update using(public.is_admin_or_staff()) with check(public.is_admin_or_staff());

create policy "order items own read" on public.order_items for select using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_admin_or_staff())));
create policy "order history own read" on public.order_status_history for select using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_admin_or_staff())));

create policy "payments own read" on public.payments for select using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_admin_or_staff())));
create policy "shipments own read" on public.shipments for select using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_admin_or_staff())));
create policy "tracking own read" on public.tracking_events for select using(exists(select 1 from public.shipments s join public.orders o on o.id=s.order_id where s.id=shipment_id and (o.user_id=auth.uid() or public.is_admin_or_staff())));

-- Storage
insert into storage.buckets(id,name,public) values('product-images','product-images',true)
on conflict(id) do update set public=true;

create policy "public product image read" on storage.objects for select using(bucket_id='product-images');
create policy "admin product image upload" on storage.objects for insert with check(bucket_id='product-images' and public.is_admin_or_staff());
create policy "admin product image update" on storage.objects for update using(bucket_id='product-images' and public.is_admin_or_staff());
create policy "admin product image delete" on storage.objects for delete using(bucket_id='product-images' and public.is_admin_or_staff());

commit;
