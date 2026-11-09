-- ═══════════════════════════════════════════════════════════════════
--  Aba Operacional: check diário das campanhas de cada cliente.
--  Uma linha por cliente por dia. Check marcado = data/hora preenchida
--  (google_em / meta_em); desmarcou, volta a ser null.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  Pode rodar de novo sem erro (IF NOT EXISTS em tudo).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.checks_diarios (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.clientes(id) on delete cascade,
  dia         date not null,

  google_em   timestamptz,
  google_por  text,
  meta_em     timestamptz,
  meta_por    text,
  obs         text,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  unique (cliente_id, dia)
);

create index if not exists checks_diarios_dia_idx on public.checks_diarios (dia);

-- Mesmo modelo de acesso do CRM: só quem está logado lê e escreve.
alter table public.checks_diarios enable row level security;

drop policy if exists "checks_diarios_autenticados" on public.checks_diarios;
create policy "checks_diarios_autenticados" on public.checks_diarios
  for all to authenticated using (true) with check (true);

-- Realtime: a tela atualiza sozinha quando outra pessoa marca um check.
do $$
begin
  alter publication supabase_realtime add table public.checks_diarios;
exception when duplicate_object then null;
end $$;

-- Confere
select count(*) as checks from public.checks_diarios;

-- ── Para desfazer (apaga a tabela e todo o histórico de checks) ─────
-- drop table public.checks_diarios;
