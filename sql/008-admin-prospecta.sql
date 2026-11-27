-- ═══════════════════════════════════════════════════════════════════
--  Admin que também prospecta: continua admin (vê tudo) e ganha um
--  CRM de BDR próprio. Liga/desliga em Prospecção BDR → Equipe.
--
--  E "Criar login" com o e-mail de um admin deixa de rebaixá-lo pra
--  BDR: ele continua admin e só passa a prospectar também.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  Pode rodar de novo sem erro.
-- ═══════════════════════════════════════════════════════════════════

alter table public.perfis
  add column if not exists prospecta boolean not null default false;

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
       set papel     = case when perfis.papel = 'admin' then 'admin' else excluded.papel end,
           prospecta = perfis.prospecta or (perfis.papel = 'admin' and excluded.papel = 'bdr'),
           ativo     = true;
  return uid;
end $$;

notify pgrst, 'reload schema';

-- Confere. Se o Vinicius aparecer como 'bdr' (foi rebaixado ao criar
-- o login com o próprio e-mail), rode trocando o e-mail:
--   update public.perfis set papel = 'admin', prospecta = true where email = 'EMAIL_DO_VINI';
select nome, email, papel, prospecta, ativo from public.perfis order by papel, nome;
