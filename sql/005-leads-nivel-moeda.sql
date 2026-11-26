-- ═══════════════════════════════════════════════════════════════════
--  Leads: nível (A, B, C, D) e moeda do valor da proposta (BRL/USD).
--
--  Os leads que já existem ficam em BRL, que é como o CRM mostrava até
--  agora — nada muda de valor sozinho. Leads novos nascem em USD.
--  Corrija os que são em dólar (ex.: Bernardo) editando o lead.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  Pode rodar de novo sem erro (IF NOT EXISTS em tudo).
-- ═══════════════════════════════════════════════════════════════════

alter table public.leads
  add column if not exists moeda text not null default 'BRL',
  add column if not exists nivel text;

alter table public.leads alter column moeda set default 'USD';

do $$ begin
  alter table public.leads add constraint leads_moeda_chk check (moeda in ('USD','BRL'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.leads add constraint leads_nivel_chk check (nivel is null or nivel in ('A','B','C','D'));
exception when duplicate_object then null; end $$;

-- Faz a API do Supabase enxergar as colunas novas na hora.
notify pgrst, 'reload schema';

-- Confere: deve listar moeda e nivel.
select column_name, column_default
  from information_schema.columns
 where table_schema = 'public' and table_name = 'leads'
   and column_name in ('moeda','nivel');
