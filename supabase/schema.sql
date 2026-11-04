-- Run in Supabase SQL Editor. Read README before promoting initial administrator.
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', company text not null default '',
 role text not null default 'member' check (role in ('member','admin')),
 status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
 created_at timestamptz not null default now()
);
create table if not exists public.incidents (
 id uuid primary key default gen_random_uuid(),
 title text not null, summary text not null default '', location text not null default '',
 event_time timestamptz not null, severity text not null default 'medium' check (severity in ('low','medium','high','critical')),
 verification text not null default 'unverified' check (verification in ('confirmed','unverified','disputed')),
 source_name text not null, source_url text not null check (source_url ~ '^https://'),
 imo text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create or replace function public.create_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles (id,full_name,company)
 values (new.id,coalesce(new.raw_user_meta_data->>'full_name',''),coalesce(new.raw_user_meta_data->>'company',''));
 return new;
end; $$;
drop trigger if exists after_signup_profile on auth.users;
create trigger after_signup_profile after insert on auth.users for each row execute procedure public.create_profile();
create or replace function public.is_approved() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id = (select auth.uid()) and status = 'approved');
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id = (select auth.uid()) and status = 'approved' and role = 'admin');
$$;
-- Grant EXECUTE to authenticated only.
revoke all on function public.is_approved() from public, anon;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_approved() to authenticated;
grant execute on function public.is_admin() to authenticated;
alter table public.profiles enable row level security;
alter table public.incidents enable row level security;
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using (id = (select auth.uid()) or (select public.is_admin()));
-- Column-specific grants prevent members/admin clients from modifying role.
revoke update on public.profiles from authenticated;
grant update (status) on public.profiles to authenticated;
drop policy if exists profiles_admin_status on public.profiles;
create policy profiles_admin_status on public.profiles for update to authenticated using ((select public.is_admin()) and role <> 'admin') with check ((select public.is_admin()) and role <> 'admin');
drop policy if exists incidents_read on public.incidents;
create policy incidents_read on public.incidents for select to authenticated using ((select public.is_approved()));
drop policy if exists incidents_insert on public.incidents;
create policy incidents_insert on public.incidents for insert to authenticated with check ((select public.is_admin()));
drop policy if exists incidents_update on public.incidents;
create policy incidents_update on public.incidents for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists incidents_delete on public.incidents;
create policy incidents_delete on public.incidents for delete to authenticated using ((select public.is_admin()));
-- Create the first account through the app; then promote it manually in SQL Editor:
-- update public.profiles set role='admin', status='approved' where id = '<FIRST_AUTH_USER_UUID>';
