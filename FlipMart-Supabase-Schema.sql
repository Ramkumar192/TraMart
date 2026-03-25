-- ╔══════════════════════════════════════════════════════════════╗
-- ║  FLIPMART – Supabase SQL Setup                               ║
-- ║  Paste this entire file into:                                ║
-- ║  Supabase Dashboard → SQL Editor → New Query → Run          ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ── 1. PROFILES (extends auth.users) ─────────────────────────────
create table if not exists public.profiles (
  id          uuid references auth.users(id) on delete cascade primary key,
  name        text,
  email       text,
  role        text default 'buyer' check (role in ('buyer','seller','admin')),
  phone       text,
  created_at  timestamptz default now()
);
alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);
create policy "Sellers can view buyer profiles for orders"
  on public.profiles for select using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'seller')
  );

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'role', 'buyer')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ── 2. ADDRESSES ─────────────────────────────────────────────────
create table if not exists public.addresses (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references public.profiles(id) on delete cascade not null,
  name        text not null,
  phone       text not null,
  address     text not null,
  city        text not null,
  state       text not null,
  pincode     text not null,
  type        text default 'Home' check (type in ('Home','Work','Other')),
  is_default  boolean default false,
  created_at  timestamptz default now()
);
alter table public.addresses enable row level security;
create policy "Users manage own addresses"
  on public.addresses for all using (auth.uid() = user_id);


-- ── 3. PRODUCTS ───────────────────────────────────────────────────
create table if not exists public.products (
  id          uuid default gen_random_uuid() primary key,
  seller_id   uuid references public.profiles(id) on delete set null,
  name        text not null,
  brand       text,
  category    text,
  price       numeric not null,
  mrp         numeric not null,
  rating      numeric default 4.0,
  review_count integer default 0,
  img         text,
  description text,
  emi         text,
  badge       text,
  stock       text default 'In Stock',
  specs       jsonb default '{}',
  is_active   boolean default true,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
alter table public.products enable row level security;
create policy "Anyone can view active products"
  on public.products for select using (is_active = true);
create policy "Sellers can insert products"
  on public.products for insert with check (
    auth.uid() = seller_id and
    exists (select 1 from public.profiles where id = auth.uid() and role = 'seller')
  );
create policy "Sellers can update own products"
  on public.products for update using (
    auth.uid() = seller_id and
    exists (select 1 from public.profiles where id = auth.uid() and role = 'seller')
  );
create policy "Sellers can delete own products"
  on public.products for delete using (
    auth.uid() = seller_id and
    exists (select 1 from public.profiles where id = auth.uid() and role = 'seller')
  );


-- ── 4. ORDERS ─────────────────────────────────────────────────────
create table if not exists public.orders (
  id            uuid default gen_random_uuid() primary key,
  user_id       uuid references public.profiles(id) on delete set null,
  user_name     text,
  user_email    text,
  items         jsonb not null default '[]',
  address       jsonb not null default '{}',
  payment       text default 'cod',
  status        text default 'placed'
                check (status in ('placed','confirmed','packed','shipped','out','delivered','cancelled')),
  total         numeric not null,
  tracking_steps jsonb default '[]',
  notes         text,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);
alter table public.orders enable row level security;
create policy "Buyers can view own orders"
  on public.orders for select using (auth.uid() = user_id);
create policy "Buyers can insert orders"
  on public.orders for insert with check (auth.uid() = user_id);
create policy "Sellers can view all orders"
  on public.orders for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('seller','admin'))
  );
create policy "Sellers can update orders"
  on public.orders for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('seller','admin'))
  );

-- Auto-update updated_at
create or replace function public.update_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger orders_updated_at before update on public.orders
  for each row execute procedure public.update_updated_at();
create trigger products_updated_at before update on public.products
  for each row execute procedure public.update_updated_at();


-- ── 5. SEED PRODUCTS (optional demo data) ─────────────────────────
-- Run this block only if you want demo products without a seller account
-- (set seller_id to null or a known seller UUID)

insert into public.products (name, brand, category, price, mrp, rating, review_count, img, description, emi, badge, specs) values
('Samsung Galaxy S24 Ultra 5G','Samsung','Mobiles',89999,109999,4.6,4521,'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=400&q=80','6.8" Dynamic AMOLED 2X, 200MP Camera, Snapdragon 8 Gen 3, S Pen.','₹7,500/mo','Bestseller','{"Display":"6.8\" QHD+ AMOLED","RAM":"12 GB","Storage":"256 GB","Battery":"5000 mAh","Camera":"200+12+10+10 MP"}'),
('Apple iPhone 15 Pro Max','Apple','Mobiles',134900,149900,4.8,8234,'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400&q=80','Titanium design, A17 Pro chip, 48MP camera, 4K ProRes video.','₹11,242/mo','Top Rated','{"Display":"6.7\" Super Retina XDR","RAM":"8 GB","Storage":"256 GB","Battery":"4422 mAh","Camera":"48+12+12 MP"}'),
('OnePlus 12R 5G','OnePlus','Mobiles',39999,49999,4.4,2100,'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=400&q=80','Snapdragon 8 Gen 1, 100W SUPERVOOC, 120Hz AMOLED.','₹3,333/mo',null,'{"Display":"6.74\" AMOLED","RAM":"8 GB","Storage":"128 GB","Battery":"5400 mAh"}'),
('Dell XPS 15 (2024) Laptop','Dell','Laptops',129990,159990,4.5,987,'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=400&q=80','Intel i7-13700H, RTX 4060, 16GB RAM, 4K OLED display.','₹10,833/mo','Best Value','{"Processor":"Intel i7-13700H","RAM":"16 GB DDR5","Storage":"512 GB NVMe","Display":"15.6\" 4K OLED","GPU":"RTX 4060"}'),
('Apple MacBook Air M3','Apple','Laptops',114900,119900,4.9,3421,'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400&q=80','M3 chip, 8GB RAM, 256GB SSD, 18-hour battery.','₹9,575/mo',null,'{"Processor":"Apple M3","RAM":"8 GB","Storage":"256 GB SSD","Display":"13.6\" Liquid Retina","Battery":"18 hours"}'),
('Sony Bravia 55" 4K Google TV','Sony','TVs',79990,99990,4.6,1543,'https://images.unsplash.com/photo-1593784991095-a205069470b6?w=400&q=80','Google TV, Dolby Vision & Atmos, TRILUMINOS PRO.','₹6,666/mo','Deal of Day','{"Size":"55 inch","Resolution":"4K UHD","HDR":"Dolby Vision/HDR10","OS":"Google TV"}'),
('LG C3 48" OLED Smart TV','LG','TVs',89999,120000,4.7,876,'https://images.unsplash.com/photo-1567690187548-f07b1d7bf5a9?w=400&q=80','OLED evo panel, α9 AI Gen6 Processor, ThinQ AI.','₹7,500/mo',null,'{"Size":"48 inch","Panel":"OLED evo","Resolution":"4K UHD","Sound":"40W"}'),
('Levi''s Men 511 Slim Jeans','Levi''s','Men Fashion',1999,3999,4.2,5672,'https://images.unsplash.com/photo-1542272454315-4c01d7abdf4a?w=400&q=80','Stretch denim, slim fit, signature 5-pocket styling.',null,'50% Off','{"Fabric":"98% Cotton 2% Elastane","Fit":"Slim","Waist":"28-40"}'),
('Nike Air Max 270','Nike','Men Fashion',11995,14995,4.5,3456,'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&q=80','Max Air heel unit, engineered mesh upper.',null,null,'{"Material":"Engineered Mesh","Sole":"Rubber","Usage":"Lifestyle"}'),
('Dyson V15 Detect Absolute','Dyson','Appliances',49990,64990,4.7,2341,'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&q=80','Laser dust detection, HEPA filtration, 60-min runtime.',null,'Premium Pick','{"Suction":"230 AW","Runtime":"60 min","Filter":"HEPA"}'),
('Instant Pot Duo 7-in-1 6Qt','Instant Pot','Home & Kitchen',7999,12999,4.5,8901,'https://images.unsplash.com/photo-1585515320310-259814833e62?w=400&q=80','Pressure cooker, slow cook, rice cooker, 13 programs.','₹667/mo',null,'{"Capacity":"6 Quart","Programs":"13","Power":"1000 W"}'),
('Atomic Habits – James Clear','Penguin','Books',299,499,4.8,15234,'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400&q=80','Build good habits & break bad ones. #1 NYT Bestseller.',null,'Bestseller','{"Author":"James Clear","Pages":"320","Publisher":"Penguin"}'),
('boAt Rockerz 550 Headphone','boAt','Electronics',1999,4990,4.2,12345,'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&q=80','40H playback, 50mm drivers, BT 5.0, IPX5.',null,'60% Off','{"Battery":"40 Hours","Drivers":"50 mm","BT":"Bluetooth 5.0"}'),
('Noise ColorFit Pro 4 Watch','Noise','Electronics',2499,7999,4.1,18765,'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&q=80','1.72" AMOLED, SpO2, 100+ sports modes, IP68.',null,'Best Seller','{"Display":"1.72\" AMOLED","Battery":"7 Days","Waterproof":"IP68"}'),
('Decathlon Yoga Mat 6mm','Decathlon','Sports',1499,2999,4.4,4532,'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&q=80','Eco-friendly TPE, non-slip, alignment lines.',null,null,'{"Thickness":"6 mm","Material":"TPE","Size":"183x61 cm"}'),
('LEGO Classic Bricks 790pc','LEGO','Toys',2499,3499,4.7,6543,'https://images.unsplash.com/photo-1587654780291-39c9404d746b?w=400&q=80','790 bricks, open-ended creativity, ages 4+.',null,null,'{"Pieces":"790","Age":"4+ years","Theme":"Classic"}'),
('Maybelline Fit Me Foundation','Maybelline','Beauty',449,699,4.3,9876,'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400&q=80','Natural matte finish, oil-free, 40 shades, SPF 18.',null,null,'{"Type":"Liquid Foundation","Coverage":"Medium","SPF":"SPF 18"}'),
('H&M Kids Superhero T-Shirt','H&M','Kids Fashion',499,999,4.1,1234,'https://images.unsplash.com/photo-1519238263530-99bdd11df2ea?w=400&q=80','100% soft cotton, vibrant graphic print.',null,'Buy 2 Get 1','{"Fabric":"100% Cotton","Age":"4-12 years"}'),
('W Women Floral Print Kurta','W','Women Fashion',1299,2499,4.3,3210,'https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=400&q=80','Cotton blend, ethnic floral print, relaxed V-neck.',null,null,'{"Fabric":"Cotton Blend","Fit":"Regular","Neck":"V-Neck"}'),
('HP Pavilion 15 Core i5','HP','Laptops',49990,65990,4.2,1876,'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400&q=80','Intel i5-1235U, 8GB RAM, 512GB SSD, FHD IPS.','₹4,166/mo',null,'{"Processor":"Intel i5-1235U","RAM":"8 GB","Storage":"512 GB SSD"}')
on conflict do nothing;

-- ── Done! ──────────────────────────────────────────────────────────
-- Enable Realtime for orders table (optional):
-- Supabase Dashboard → Database → Replication → Enable for "orders"
