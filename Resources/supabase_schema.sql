-- ================================================================
-- DailyList — Supabase Database Setup
-- Run this entire file in your Supabase SQL Editor
-- Dashboard → SQL Editor → New Query → Paste → Run
-- ================================================================


-- ────────────────────────────────────────────────────────────────
-- 1. USER PROFILES
--    Extends Supabase auth.users with app-specific profile data.
-- ────────────────────────────────────────────────────────────────

create table if not exists public.user_profiles (
    id                      uuid primary key references auth.users(id) on delete cascade,
    email                   text,
    display_name            text,
    daily_reminder_enabled  boolean not null default true,
    daily_reminder_time     text    not null default '08:00',
    created_at              timestamptz not null default now()
);

-- Auto-create a profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
    insert into public.user_profiles (id, email, display_name)
    values (
        new.id,
        new.email,
        new.raw_user_meta_data->>'display_name'
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();


-- ────────────────────────────────────────────────────────────────
-- 2. TODO ITEMS
-- ────────────────────────────────────────────────────────────────

create table if not exists public.todo_items (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null references auth.users(id) on delete cascade,
    title            text not null,
    notes            text,
    list_date        date not null,                 -- the day this item lives on
    deadline         timestamptz,                   -- optional hard deadline
    reminder_offset  integer,                       -- minutes before deadline
    recurrence       text not null default 'once',  -- once|daily|weekdays|weekends|weekly|biweekly|monthly
    status           text not null default 'pending', -- pending|done|obe
    completed_at     timestamptz,
    template_id      uuid references public.todo_items(id) on delete set null,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);

-- Keep updated_at current automatically
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists todo_items_updated_at on public.todo_items;
create trigger todo_items_updated_at
    before update on public.todo_items
    for each row execute function public.set_updated_at();

-- Indexes for common queries
create index if not exists idx_todo_items_user_id    on public.todo_items(user_id);
create index if not exists idx_todo_items_list_date  on public.todo_items(list_date);
create index if not exists idx_todo_items_template   on public.todo_items(template_id);
create index if not exists idx_todo_items_user_date  on public.todo_items(user_id, list_date);


-- ────────────────────────────────────────────────────────────────
-- 3. ROW-LEVEL SECURITY (RLS)
--    Each user can only see and modify their own data.
-- ────────────────────────────────────────────────────────────────

alter table public.user_profiles enable row level security;
alter table public.todo_items    enable row level security;

-- user_profiles policies
create policy "Users can view own profile"
    on public.user_profiles for select
    using (auth.uid() = id);

create policy "Users can update own profile"
    on public.user_profiles for update
    using (auth.uid() = id);

create policy "Users can insert own profile"
    on public.user_profiles for insert
    with check (auth.uid() = id);

-- todo_items policies
create policy "Users can view own items"
    on public.todo_items for select
    using (auth.uid() = user_id);

create policy "Users can insert own items"
    on public.todo_items for insert
    with check (auth.uid() = user_id);

create policy "Users can update own items"
    on public.todo_items for update
    using (auth.uid() = user_id);

create policy "Users can delete own items"
    on public.todo_items for delete
    using (auth.uid() = user_id);


-- ────────────────────────────────────────────────────────────────
-- 4. REALTIME
--    Enable real-time broadcasts for todo_items so changes on
--    one device instantly appear on others.
-- ────────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.todo_items;


-- ────────────────────────────────────────────────────────────────
-- Done! Your database is ready.
-- ────────────────────────────────────────────────────────────────
