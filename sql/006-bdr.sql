-- ═══════════════════════════════════════════════════════════════════
--  Prospecção BDR: um CRM separado por BDR, estilo Trello.
--
--  • perfis        → quem é admin (Gabriel, Vinicius) e quem é BDR
--  • bdr_leads     → os cards de cada BDR (separados de "leads")
--  • bdr_relatorios→ o relatório diário de cada BDR
--  • bdr_config    → o card "LEIA COM ATENÇÃO" (script/regras)
--
--  Segurança: BDR só lê e escreve as próprias linhas. Admin vê tudo.
--  BDR NÃO enxerga leads, clientes, checks nem anexos do CRM principal
--  (políticas RESTRICTIVE — não mexem nas políticas que já existem).
--
--  IMPORTANTE: rode ANTES de criar qualquer conta de BDR. O passo 2
--  marca como admin todo usuário que existe hoje no Supabase.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  Pode rodar de novo sem erro.
-- ═══════════════════════════════════════════════════════════════════

-- 1) Perfis ----------------------------------------------------------
create table if not exists public.perfis (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  nome        text not null,
  email       text,
  papel       text not null default 'bdr' check (papel in ('admin','bdr')),
  ativo       boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 2) Quem já tem login hoje (vocês dois) vira admin.
insert into public.perfis (user_id, nome, email, papel)
select id, split_part(email, '@', 1), email, 'admin'
  from auth.users
on conflict (user_id) do nothing;

-- 3) Funções de checagem (security definer pra não dar loop no RLS).
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfis
                  where user_id = auth.uid() and papel = 'admin' and ativo);
$$;

create or replace function public.is_ativo() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfis
                  where user_id = auth.uid() and ativo);
$$;

-- Admin vincula um login (já criado) como BDR ou admin, pelo e-mail.
create or replace function public.admin_vincular_perfil(p_email text, p_nome text, p_papel text default 'bdr')
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  if not public.is_admin() then raise exception 'Apenas admin'; end if;
  select id into uid from auth.users where lower(email) = lower(trim(p_email));
  if uid is null then raise exception 'Nenhum login com o e-mail %', p_email; end if;
  insert into public.perfis (user_id, nome, email, papel, ativo)
       values (uid, p_nome, lower(trim(p_email)), coalesce(p_papel,'bdr'), true)
  on conflict (user_id) do update
       set nome = excluded.nome, papel = excluded.papel, ativo = true;
  return uid;
end $$;

alter table public.perfis enable row level security;
drop policy if exists "perfis_ler" on public.perfis;
create policy "perfis_ler" on public.perfis for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists "perfis_admin" on public.perfis;
create policy "perfis_admin" on public.perfis for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 4) Fecha o CRM principal pra quem não é admin ----------------------
--    RESTRICTIVE soma com as políticas atuais (AND). Só vale pra quem
--    está logado; o formulário da LP (anon / service role) segue igual.
drop policy if exists "so_admin" on public.leads;
create policy "so_admin" on public.leads as restrictive for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "so_admin" on public.clientes;
create policy "so_admin" on public.clientes as restrictive for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "so_admin" on public.checks_diarios;
create policy "so_admin" on public.checks_diarios as restrictive for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "lead_files_so_admin" on storage.objects;
create policy "lead_files_so_admin" on storage.objects as restrictive for all to authenticated
  using (public.is_admin() or bucket_id is distinct from 'lead-files')
  with check (public.is_admin() or bucket_id is distinct from 'lead-files');

-- 5) Cards dos BDRs --------------------------------------------------
create table if not exists public.bdr_leads (
  id          uuid primary key default gen_random_uuid(),
  bdr_id      uuid not null default auth.uid() references auth.users(id),
  empresa     text not null,
  contato     text,               -- nome do dono(a) / decisor
  telefone    text,
  email       text,
  instagram   text,
  site        text,
  nicho       text,
  cidade      text,
  stage       text not null default 'captadas',
  stage_at    timestamptz not null default now(),
  reuniao     timestamptz,
  followup    date,
  valor       numeric(12,2),
  moeda       text not null default 'USD' check (moeda in ('USD','BRL')),
  notas       text,
  activity    jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists bdr_leads_bdr_idx on public.bdr_leads (bdr_id, stage);

alter table public.bdr_leads enable row level security;
drop policy if exists "bdr_leads_dono" on public.bdr_leads;
create policy "bdr_leads_dono" on public.bdr_leads for all to authenticated
  using (public.is_admin() or (bdr_id = auth.uid() and public.is_ativo()))
  with check (public.is_admin() or (bdr_id = auth.uid() and public.is_ativo()));

-- 6) Relatório diário ------------------------------------------------
create table if not exists public.bdr_relatorios (
  id           uuid primary key default gen_random_uuid(),
  bdr_id       uuid not null default auth.uid() references auth.users(id),
  dia          date not null default current_date,
  folga        boolean not null default false,
  captadas     int not null default 0,
  abordagens   int not null default 0,
  respostas    int not null default 0,
  reunioes     int not null default 0,
  obs          text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (bdr_id, dia)
);

alter table public.bdr_relatorios enable row level security;
drop policy if exists "bdr_relatorios_dono" on public.bdr_relatorios;
create policy "bdr_relatorios_dono" on public.bdr_relatorios for all to authenticated
  using (public.is_admin() or (bdr_id = auth.uid() and public.is_ativo()))
  with check (public.is_admin() or (bdr_id = auth.uid() and public.is_ativo()));

-- 7) Card "LEIA COM ATENÇÃO" (todos leem, só admin edita) -------------
create table if not exists public.bdr_config (
  chave       text primary key,
  valor       text,
  updated_at  timestamptz not null default now()
);
insert into public.bdr_config (chave, valor) values ('instrucoes', '')
on conflict (chave) do nothing;

alter table public.bdr_config enable row level security;
drop policy if exists "bdr_config_ler" on public.bdr_config;
create policy "bdr_config_ler" on public.bdr_config for select to authenticated using (public.is_ativo());
drop policy if exists "bdr_config_admin" on public.bdr_config;
create policy "bdr_config_admin" on public.bdr_config for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 8) Realtime ---------------------------------------------------------
do $$ begin alter publication supabase_realtime add table public.bdr_leads;
exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.bdr_relatorios;
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';

-- Confere: devem aparecer você e o Vinicius como admin.
-- Se aparecer alguém que NÃO deveria ser admin, rode:
--   update public.perfis set papel = 'bdr' where email = '...';
select nome, email, papel, ativo from public.perfis order by papel, nome;

-- ── Para desfazer ───────────────────────────────────────────────────
-- drop policy "so_admin" on public.leads;
-- drop policy "so_admin" on public.clientes;
-- drop policy "so_admin" on public.checks_diarios;
-- drop policy "lead_files_so_admin" on storage.objects;
-- drop table public.bdr_relatorios, public.bdr_leads, public.bdr_config, public.perfis;
