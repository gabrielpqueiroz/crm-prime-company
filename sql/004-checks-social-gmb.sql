-- ═══════════════════════════════════════════════════════════════════
--  Aba Operacional: checks de Social Media e Google My Business.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  Pode rodar de novo sem erro (IF NOT EXISTS em tudo).
-- ═══════════════════════════════════════════════════════════════════

alter table public.checks_diarios
  add column if not exists social_em  timestamptz,
  add column if not exists social_por text,
  add column if not exists gmb_em     timestamptz,
  add column if not exists gmb_por    text;

-- Faz a API do Supabase enxergar as colunas novas na hora.
notify pgrst, 'reload schema';

-- Confere: deve listar as 4 colunas novas.
select column_name
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'checks_diarios'
   and column_name in ('social_em','social_por','gmb_em','gmb_por')
 order by column_name;

-- ── Para desfazer (apaga só os checks de Social e GMB) ──────────────
-- alter table public.checks_diarios
--   drop column social_em, drop column social_por,
--   drop column gmb_em, drop column gmb_por;
