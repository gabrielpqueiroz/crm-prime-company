-- ═══════════════════════════════════════════════════════════════════
--  Arquiva os leads da operação antiga (Brasil) sem apagar nada.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  É reversível: o UPDATE do final desfaz.
-- ═══════════════════════════════════════════════════════════════════

-- 1) Coluna de arquivo. IF NOT EXISTS deixa rodar de novo sem erro.
alter table public.leads
  add column if not exists arquivado boolean not null default false;

-- 2) Marca TUDO que existe hoje como legado.
--    A partir daqui, lead novo entra com arquivado = false (o default),
--    então só os antigos saem do funil.
update public.leads
   set arquivado = true,
       campanha  = coalesce(nullif(campanha, ''), 'Legado BR')
 where arquivado = false;

-- 3) Índice: o funil passa a filtrar por esta coluna em toda carga.
create index if not exists leads_arquivado_idx
  on public.leads (arquivado);

-- 4) Confere o resultado.
select arquivado, count(*) as total
  from public.leads
 group by arquivado;

-- ── Para desfazer ───────────────────────────────────────────────────
-- update public.leads set arquivado = false;
