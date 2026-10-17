-- ═══════════════════════════════════════════════════════════════════
--  Carteira de clientes ativos: plano, recorrência, vencimento,
--  contrato e churn. Separada de "leads" — lead é oportunidade,
--  cliente é contrato. Um cliente pode apontar pro lead que o gerou.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  Pode rodar de novo sem erro (IF NOT EXISTS em tudo).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.clientes (
  id                   uuid primary key default gen_random_uuid(),
  nome                 text not null,
  empresa              text,
  telefone             text,
  email                text,

  -- Plano: um cliente pode ter vários serviços (ex.: Meta Ads + Social Media)
  servicos             text[] not null default '{}',
  valor                numeric(12,2),
  moeda                text not null default 'USD' check (moeda in ('USD','BRL')),
  canal                text,              -- por onde o cliente chegou
  forma_pagamento      text,
  dia_vencimento       smallint check (dia_vencimento between 1 and 31),

  data_inicio          date not null default current_date,
  contrato_fim         date,              -- fim da fidelidade / renovação

  status               text not null default 'ativo'
                         check (status in ('ativo','pausado','cancelado')),
  data_cancelamento    date,
  motivo_cancelamento  text,

  resp                 text,
  notas                text,
  lead_id              text,              -- lead de origem (opcional)
  files                jsonb not null default '[]'::jsonb,   -- contrato e anexos
  activity             jsonb not null default '[]'::jsonb,

  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists clientes_status_idx on public.clientes (status);

-- Mesmo modelo de acesso do CRM: só quem está logado lê e escreve.
alter table public.clientes enable row level security;

drop policy if exists "clientes_autenticados" on public.clientes;
create policy "clientes_autenticados" on public.clientes
  for all to authenticated using (true) with check (true);

-- Realtime: a tela atualiza sozinha quando outra pessoa edita.
do $$
begin
  alter publication supabase_realtime add table public.clientes;
exception when duplicate_object then null;
end $$;

-- Confere
select count(*) as clientes from public.clientes;

-- ── Para desfazer (apaga a tabela e tudo que estiver nela) ──────────
-- drop table public.clientes;
