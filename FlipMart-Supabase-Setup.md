# FlipMart – Supabase Setup Guide

## Files Included
| File | Purpose |
|------|---------|
| `index.html` | Customer-facing store |
| `seller.html` | Seller dashboard |
| `schema.sql` | Full database schema + seed data |

---

## Step 1 – Create a Supabase Project

1. Go to **https://supabase.com** → Sign in or create account
2. Click **New project** → choose your organization
3. Enter a **project name** (e.g. `flipmart`)
4. Set a strong **database password** (save this!)
5. Choose a **region** close to your users (e.g. South Asia)
6. Click **Create new project** (takes ~2 minutes)

---

## Step 2 – Run the SQL Schema

1. In your Supabase dashboard → click **SQL Editor** (left sidebar)
2. Click **New query**
3. Open `schema.sql` from this folder and paste its entire contents
4. Click **Run** (▶️)
5. You should see "Success. No rows returned" — that's correct!

This creates:
- `profiles` table (users with roles)
- `addresses` table (saved delivery addresses)
- `products` table (product catalogue)
- `orders` table (customer orders with tracking)
- All Row Level Security (RLS) policies
- Auto-create profile trigger on signup
- 20 seed products (demo data)

---

## Step 3 – Enable Realtime (for live order updates)

1. Supabase dashboard → **Database** → **Replication**
2. Under "Source" → enable toggle for **orders** table
3. This allows sellers to see new orders without refresh

---

## Step 4 – Get Your API Keys

1. Supabase dashboard → **Project Settings** (gear icon)
2. Click **API** in the left menu
3. Copy:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon public** key (long string starting with `eyJ…`)

---

## Step 5 – Paste Keys into Both Files

In **`index.html`** (around line 30):
```javascript
const SUPABASE_URL  = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

Repeat the same in **`seller.html`** (around line 25).

---

## Step 6 – Enable Email Auth

1. Supabase dashboard → **Authentication** → **Providers**
2. Ensure **Email** is enabled (it's on by default)
3. Optional: Disable "Confirm email" for easier testing:
   - **Authentication** → **Settings** → toggle off "Enable email confirmations"

---

## Step 7 – Run the App

Because Supabase JS SDK uses browser APIs, open via a local server:

**VS Code (easiest):**
- Install "Live Server" extension → right-click `index.html` → "Open with Live Server"

**Python:**
```bash
cd flipmart-supabase
python -m http.server 8000
# Open: http://localhost:8000
```

**Node.js:**
```bash
npx serve .
```

---

## How to Create a Seller Account

1. Open `index.html` → Login → **Create Account**
2. Set **Register As** = **Seller**
3. Fill in name, email, password → submit
4. Open `seller.html` → login with the same email/password

---

## Database Tables Reference

### `profiles`
Auto-created when a user signs up. Stores `name`, `email`, `role` (buyer/seller).

### `addresses`
Linked to `profiles.id`. Multiple addresses per user with type (Home/Work/Other).

### `products`
Full product catalogue. `seller_id` links to profiles. `is_active` controls visibility.

### `orders`
Stores `items` (JSON array), `address` (JSON), `payment`, `status`, and `tracking_steps` (JSON array of `{step, time, done}`).

---

## Feature Summary

### Customer (`index.html`)
- ✅ Register / Login / Logout (Supabase Auth)
- ✅ User dropdown with all navigation links
- ✅ Manage multiple delivery addresses (add/edit/delete via Supabase)
- ✅ Place orders (saved to Supabase `orders` table)
- ✅ View orders with **real-time** status updates
- ✅ Full order tracking timeline (Placed → Confirmed → Packed → Shipped → Out → Delivered)
- ✅ Product catalogue from Supabase `products` table
- ✅ Cart, Wishlist, Search, Filters

### Seller (`seller.html`)
- ✅ Seller-only login with role verification
- ✅ Dashboard: revenue KPIs, bar chart, status breakdown
- ✅ Real-time order feed (new orders appear instantly)
- ✅ Update order status (triggers customer tracking update)
- ✅ Add / Edit / Delete / Activate / Deactivate products
- ✅ Analytics: monthly revenue, category breakdown, top products
