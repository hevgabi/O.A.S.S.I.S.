-- Migration 5: knowledge_entries
-- Campus information managed by Admins. Only 'published' entries are retrievable
-- by OASSIS (enforced by the access rules in migration 9/10).

create table public.knowledge_entries (
  entry_id              uuid         primary key default gen_random_uuid(),
  created_by_profile_id uuid         not null
                        references public.profiles (profile_id) on delete restrict,
  title                 varchar(200) not null check (length(btrim(title)) > 0),
  content               text         not null check (length(btrim(content)) > 0),
  publication_status    varchar(20)  not null default 'draft'
                        check (publication_status in ('draft', 'pending_approval', 'published')),
  created_at            timestamptz  not null default now(),
  updated_at            timestamptz  not null default now()
);

create index knowledge_entries_status_idx
  on public.knowledge_entries (publication_status);

-- The creator must be an Admin profile.
create function public.enforce_entry_creator_is_admin()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profiles
    where profile_id = new.created_by_profile_id and role = 'admin'
  ) then
    raise exception 'knowledge entry creator must be an Admin profile'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger knowledge_entries_creator_is_admin
  before insert or update of created_by_profile_id on public.knowledge_entries
  for each row execute function public.enforce_entry_creator_is_admin();

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger knowledge_entries_touch
  before update on public.knowledge_entries
  for each row execute function public.touch_updated_at();
