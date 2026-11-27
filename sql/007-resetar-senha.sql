-- ═══════════════════════════════════════════════════════════════════
--  Admin define uma senha nova para um BDR (ou outro usuário) direto
--  pelo CRM, em Prospecção BDR → Equipe → "Nova senha".
--  Também confirma o e-mail, caso o login ainda estivesse pendente.
--
--  Rode no Supabase → SQL Editor → New query → Run.
--  Pode rodar de novo sem erro.
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.admin_resetar_senha(p_user uuid, p_senha text)
returns void language plpgsql security definer
set search_path = public, extensions, auth as $$
begin
  if not public.is_admin() then raise exception 'Apenas admin'; end if;
  if length(coalesce(p_senha, '')) between 0 and 5 then
    raise exception 'A senha precisa de pelo menos 6 caracteres';
  end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_senha, extensions.gen_salt('bf')),
         email_confirmed_at = coalesce(email_confirmed_at, now()),
         updated_at = now()
   where id = p_user;
  if not found then raise exception 'Usuário não encontrado'; end if;
end $$;

revoke execute on function public.admin_resetar_senha(uuid, text) from public, anon;
grant execute on function public.admin_resetar_senha(uuid, text) to authenticated;

notify pgrst, 'reload schema';

-- Confere: deve listar a função.
select proname from pg_proc where proname = 'admin_resetar_senha';
