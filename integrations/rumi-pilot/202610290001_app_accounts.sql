-- Apply AFTER the 19 upstream pilot migrations. Service-role only.
-- Provision a mapping only after verifying both app account and Rumi ownership.
begin;
create table public.rumi_app_accounts (
  subject_hash text primary key check(subject_hash ~ '^[a-f0-9]{64}$'),
  user_id uuid not null unique references public.rumi_users(id),
  verification_reference text not null check(length(verification_reference) between 1 and 200),
  verified_at timestamptz not null default now(),
  revoked_at timestamptz
);
create table public.rumi_app_sessions (
  session_id uuid primary key references public.rumi_sessions(id),
  subject_hash text not null references public.rumi_app_accounts(subject_hash)
);
alter table public.rumi_app_accounts enable row level security;
alter table public.rumi_app_sessions enable row level security;
revoke all on public.rumi_app_accounts,public.rumi_app_sessions from public,anon,authenticated;
grant select,insert,update,delete on public.rumi_app_accounts,public.rumi_app_sessions to service_role;

create function public.rumi_app_ready(p_subject_hash text) returns jsonb
language sql security invoker set search_path=public,pg_temp as $$
  select jsonb_build_object('status',case when exists(
    select 1 from rumi_app_accounts where subject_hash=p_subject_hash and revoked_at is null
  ) then 'ready' else 'account_link_required' end);
$$;
create function public.rumi_app_open_session(p_subject_hash text,p_agent text,p_token_hash text,p_conversation text) returns jsonb
language plpgsql security invoker set search_path=public,pg_temp as $$
declare a rumi_app_accounts; s rumi_sessions; u rumi_users;
begin
  select * into a from rumi_app_accounts where subject_hash=p_subject_hash and revoked_at is null for update;
  if not found then return jsonb_build_object('status','account_link_required'); end if;
  if (select count(*) from rumi_sessions live join rumi_app_sessions x on x.session_id=live.id
    where x.subject_hash=p_subject_hash and live.closed_at is null and live.expires_at>now())>=3 then
    return jsonb_build_object('status','session_limit');
  end if;
  if p_token_hash !~ '^[a-f0-9]{64}$' or length(p_agent) not between 1 and 200
    or p_conversation !~ '^app:[a-f0-9-]{36}$' then raise exception 'Invalid session'; end if;
  insert into rumi_sessions(conversation_id,agent_id,user_id,direction,identity_status,token_hash,expires_at)
    values(p_conversation,p_agent,a.user_id,'preview','verified',p_token_hash,now()+interval '30 minutes') returning * into s;
  insert into rumi_app_sessions(session_id,subject_hash) values(s.id,p_subject_hash);
  select * into u from rumi_users where id=a.user_id;
  return jsonb_build_object('status','ok','user_id',u.id,'session_id',s.id,
    'memory_consent',u.memory_consent,'state_version',u.memory_version,
    'memory_brief',case when u.memory_consent='granted' then u.memory_brief else '{}'::jsonb end,
    'conversation_plan',case when u.memory_consent='granted' then u.conversation_plan else '{}'::jsonb end);
end $$;
-- The provider conversation ID is learned on the server's authenticated socket,
-- never accepted from a phone or a model. This lets signed post-call jobs find it.
create function public.rumi_app_bind_conversation(p_token_hash text,p_conversation text) returns jsonb
language plpgsql security invoker set search_path=public,pg_temp as $$
begin
  if p_conversation !~ '^conv_[A-Za-z0-9_-]{1,180}$' then raise exception 'Invalid conversation'; end if;
  update rumi_sessions s set conversation_id=p_conversation
    from rumi_app_sessions x,rumi_app_accounts a
    where s.token_hash=p_token_hash and s.id=x.session_id and a.subject_hash=x.subject_hash
      and a.revoked_at is null and a.user_id=s.user_id and s.closed_at is null and s.expires_at>now()
      and (s.conversation_id like 'app:%' or s.conversation_id=p_conversation);
  if not found then raise exception 'Session unavailable'; end if;
  return jsonb_build_object('status','ok');
end $$;
create function public.rumi_app_session_state(p_token_hash text) returns jsonb
language sql security invoker set search_path=public,pg_temp as $$
  select jsonb_build_object('status','active','memory_consent',u.memory_consent)
    from rumi_sessions s join rumi_app_sessions x on x.session_id=s.id
    join rumi_app_accounts a on a.subject_hash=x.subject_hash and a.user_id=s.user_id
    join rumi_users u on u.id=s.user_id
    where s.token_hash=p_token_hash and a.revoked_at is null
      and s.closed_at is null and s.expires_at>now();
$$;
create function public.rumi_app_close_session(p_token_hash text) returns void
language sql security invoker set search_path=public,pg_temp as $$
  update rumi_sessions set closed_at=now() where token_hash=p_token_hash
    and id in(select session_id from rumi_app_sessions);
$$;
-- Revoking/replacing a mapping invalidates every previously issued tool session.
create function public.rumi_app_revoke_sessions() returns trigger
language plpgsql security invoker set search_path=public,pg_temp as $$
begin
  if new.user_id<>old.user_id then
    raise exception 'Account ownership is immutable; reconcile identity before provisioning a new subject';
  end if;
  if new.revoked_at is not null then
    update rumi_sessions set closed_at=now() where id in(
      select session_id from rumi_app_sessions where subject_hash=old.subject_hash);
  end if;
  return new;
end $$;
create trigger rumi_app_revocation before update on rumi_app_accounts
for each row execute function rumi_app_revoke_sessions();
revoke all on function public.rumi_app_ready(text),public.rumi_app_open_session(text,text,text,text),
  public.rumi_app_bind_conversation(text,text),public.rumi_app_session_state(text),public.rumi_app_close_session(text),public.rumi_app_revoke_sessions() from public,anon,authenticated;
grant execute on function public.rumi_app_ready(text),public.rumi_app_open_session(text,text,text,text),
  public.rumi_app_bind_conversation(text,text),public.rumi_app_session_state(text),public.rumi_app_close_session(text) to service_role;
commit;
