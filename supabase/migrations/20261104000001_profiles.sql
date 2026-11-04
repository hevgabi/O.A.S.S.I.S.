-- Migration 1: profiles
-- Provisioned Student and Admin profiles. No password column: passwords live in
-- the authentication provider (Supabase Auth). A profile is mapped to its auth
-- account by the school email.

create table public.profiles (
  profile_id     uuid        primary key default gen_random_uuid(),
  email          text        not null unique,
  role           varchar(10) not null
                 check (role in ('student', 'admin')),
  account_status varchar(16) not null default 'provisioned'
                 check (account_status in ('provisioned', 'active', 'disabled')),
  activated_at   timestamptz,
  created_at     timestamptz not null default now(),
  constraint profiles_email_lowercase check (email = lower(email)),
  constraint profiles_email_not_blank  check (length(btrim(email)) > 0),
  constraint profiles_provisioned_not_activated
    check (account_status <> 'provisioned' or activated_at is null)
);

comment on table public.profiles is
  'Authorized Student/Admin profiles. Visitors never have a profile.';
