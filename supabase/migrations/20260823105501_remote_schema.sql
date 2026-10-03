-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

-- NOTE: `db pull` emitted `DROP EXTENSION pg_net;` here because the dev project
-- happens not to have pg_net enabled. That is an incidental environment
-- difference, not part of the application schema, and dropping it on a
-- project that does have it enabled fails (and would break webhook/HTTP
-- features we may want in Phase 5/6). Intentionally omitted.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;

CREATE FUNCTION public.bump_usage (
  p_field  text,
  p_amount integer DEFAULT 1
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'bump_usage: not authenticated';
  end if;
  if p_field not in ('voice_seconds_used', 'suggestions_used', 'leads_viewed') then
    raise exception 'bump_usage: unknown field %', p_field;
  end if;
  if p_amount < 0 then
    raise exception 'bump_usage: amount must not be negative';
  end if;

  insert into public.usage_counters (owner_id) values (v_uid)
  on conflict (owner_id) do nothing;

  -- New month: zero everything before applying this bump.
  update public.usage_counters
     set period_start       = date_trunc('month', now())::date,
         voice_seconds_used = 0,
         suggestions_used   = 0,
         leads_viewed       = 0
   where owner_id = v_uid
     and period_start < date_trunc('month', now())::date;

  if p_field = 'voice_seconds_used' then
    update public.usage_counters set voice_seconds_used = voice_seconds_used + p_amount
     where owner_id = v_uid;
  elsif p_field = 'suggestions_used' then
    update public.usage_counters set suggestions_used = suggestions_used + p_amount
     where owner_id = v_uid;
  else
    update public.usage_counters set leads_viewed = leads_viewed + p_amount
     where owner_id = v_uid;
  end if;
end
$function$;

GRANT ALL ON FUNCTION public.bump_usage(text, integer) TO anon;

GRANT ALL ON FUNCTION public.bump_usage(text, integer) TO authenticated;

GRANT ALL ON FUNCTION public.bump_usage(text, integer) TO service_role;

CREATE FUNCTION public.next_document_reference (
  p_kind text
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_uid    uuid := auth.uid();
  v_prefix text;
  v_number integer;
begin
  if v_uid is null then
    raise exception 'next_document_reference: not authenticated';
  end if;
  if p_kind not in ('quote', 'invoice') then
    raise exception 'next_document_reference: unknown kind %', p_kind;
  end if;

  insert into public.quote_settings (owner_id) values (v_uid)
  on conflict (owner_id) do nothing;

  if p_kind = 'quote' then
    update public.quote_settings
       set next_quote_number = next_quote_number + 1
     where owner_id = v_uid
    returning prefix, next_quote_number - 1 into v_prefix, v_number;
  else
    update public.quote_settings
       set next_invoice_number = next_invoice_number + 1
     where owner_id = v_uid
    returning prefix, next_invoice_number - 1 into v_prefix, v_number;
  end if;

  return coalesce(nullif(v_prefix, ''),
                  case when p_kind = 'quote' then 'Q' else 'INV' end)
         || '-' || lpad(v_number::text, 4, '0');
end
$function$;

GRANT ALL ON FUNCTION public.next_document_reference(text) TO anon;

GRANT ALL ON FUNCTION public.next_document_reference(text) TO authenticated;

GRANT ALL ON FUNCTION public.next_document_reference(text) TO service_role;

CREATE FUNCTION public.notifications_only_read_flag()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  -- The service role legitimately rewrites these rows; only fence the client.
  if auth.role() = 'service_role' then
    return new;
  end if;
  if new.id is distinct from old.id
     or new.owner_id is distinct from old.owner_id
     or new.type is distinct from old.type
     or new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.payload is distinct from old.payload
     or new.created_at is distinct from old.created_at then
    raise exception 'notifications: only read and read_at may be changed';
  end if;
  return new;
end
$function$;

GRANT ALL ON FUNCTION public.notifications_only_read_flag() TO anon;

GRANT ALL ON FUNCTION public.notifications_only_read_flag() TO authenticated;

GRANT ALL ON FUNCTION public.notifications_only_read_flag() TO service_role;

CREATE FUNCTION public.profiles_guard_server_columns()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;
  if new.verification_status is distinct from old.verification_status then
    raise exception 'profiles: verification_status is set by the server';
  end if;
  if new.account_status is distinct from old.account_status then
    raise exception 'profiles: account_status is set by the server';
  end if;
  if new.deletion_requested_at is distinct from old.deletion_requested_at
     or new.deletion_scheduled_at is distinct from old.deletion_scheduled_at then
    raise exception 'profiles: deletion timestamps are set by the server';
  end if;
  return new;
end
$function$;

GRANT ALL ON FUNCTION public.profiles_guard_server_columns() TO anon;

GRANT ALL ON FUNCTION public.profiles_guard_server_columns() TO authenticated;

GRANT ALL ON FUNCTION public.profiles_guard_server_columns() TO service_role;

CREATE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'pg_catalog'
  AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

GRANT ALL ON FUNCTION public.rls_auto_enable() TO anon;

GRANT ALL ON FUNCTION public.rls_auto_enable() TO authenticated;

GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;

CREATE FUNCTION public.touch_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.updated_at = now();
  return new;
end
$function$;

GRANT ALL ON FUNCTION public.touch_updated_at() TO anon;

GRANT ALL ON FUNCTION public.touch_updated_at() TO authenticated;

GRANT ALL ON FUNCTION public.touch_updated_at() TO service_role;

CREATE TABLE public.customers (
  id                uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id          uuid                     NOT NULL,
  name              text                     NOT NULL,
  email             text,
  phone             text,
  company           text,
  notes             text,
  address_line1     text,
  address_line2     text,
  city              text,
  county            text,
  postcode          text,
  formatted_address text,
  latitude          double precision,
  longitude         double precision,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.customers
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customers
  ADD CONSTRAINT customers_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.customers
  ADD CONSTRAINT customers_pkey PRIMARY KEY (id);

GRANT ALL ON public.customers TO anon;

GRANT ALL ON public.customers TO authenticated;

GRANT ALL ON public.customers TO service_role;

CREATE INDEX idx_customers_owner_name ON public.customers (owner_id, name);

CREATE INDEX idx_customers_owner ON public.customers (owner_id);

CREATE TRIGGER touch_customers
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes customers" ON public.customers
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts customers" ON public.customers
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads customers" ON public.customers
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates customers" ON public.customers
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.document_shares (
  token            text                     NOT NULL,
  owner_id         uuid                     NOT NULL,
  quote_id         uuid,
  invoice_id       uuid,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  viewed_at        timestamp with time zone,
  responded_at     timestamp with time zone,
  responded_action text,
  deleted_at       timestamp with time zone
);

ALTER TABLE public.document_shares
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.document_shares
  ADD CONSTRAINT document_shares_exactly_one CHECK (((quote_id IS NOT NULL)::integer + (invoice_id IS NOT NULL)::integer) = 1);

ALTER TABLE public.document_shares
  ADD CONSTRAINT document_shares_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.document_shares
  ADD CONSTRAINT document_shares_pkey PRIMARY KEY (token);

ALTER TABLE public.document_shares
  ADD CONSTRAINT document_shares_responded_action_check CHECK (responded_action = ANY (ARRAY['accepted'::text, 'rejected'::text]));

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON public.document_shares TO anon;

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON public.document_shares TO authenticated;

GRANT ALL ON public.document_shares TO service_role;

CREATE INDEX idx_document_shares_quote ON public.document_shares (quote_id);

CREATE INDEX idx_document_shares_owner ON public.document_shares (owner_id);

CREATE INDEX idx_document_shares_invoice ON public.document_shares (invoice_id);

CREATE POLICY "owner reads document_shares" ON public.document_shares
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE TABLE public.fcm_tokens (
  owner_id     uuid                     NOT NULL,
  token        text                     NOT NULL,
  platform     text,
  device_id    text,
  last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
  created_at   timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.fcm_tokens
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.fcm_tokens
  ADD CONSTRAINT fcm_tokens_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.fcm_tokens
  ADD CONSTRAINT fcm_tokens_pkey PRIMARY KEY (owner_id, token);

ALTER TABLE public.fcm_tokens
  ADD CONSTRAINT fcm_tokens_platform_check CHECK (platform = ANY (ARRAY['android'::text, 'ios'::text]));

GRANT ALL ON public.fcm_tokens TO anon;

GRANT ALL ON public.fcm_tokens TO authenticated;

GRANT ALL ON public.fcm_tokens TO service_role;

CREATE INDEX idx_fcm_tokens_owner ON public.fcm_tokens (owner_id);

CREATE POLICY "owner deletes fcm_tokens" ON public.fcm_tokens
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts fcm_tokens" ON public.fcm_tokens
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads fcm_tokens" ON public.fcm_tokens
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates fcm_tokens" ON public.fcm_tokens
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.invoice_attachments (
  id                     uuid                     DEFAULT gen_random_uuid() NOT NULL,
  invoice_id             uuid                     NOT NULL,
  sort_order             integer                  DEFAULT 0 NOT NULL,
  kind                   text                     NOT NULL,
  tool_asset_id          uuid,
  title                  text                     DEFAULT ''::text NOT NULL,
  description            text                     DEFAULT ''::text NOT NULL,
  body                   text,
  url                    text,
  storage_path           text,
  file_name              text,
  mime_type              text,
  size_bytes             bigint                   DEFAULT 0 NOT NULL,
  thumbnail_url          text,
  thumbnail_storage_path text,
  created_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.invoice_attachments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.invoice_attachments
  ADD CONSTRAINT invoice_attachments_kind_check CHECK (kind = ANY (ARRAY['note'::text, 'photo'::text, 'video'::text, 'file'::text]));

ALTER TABLE public.invoice_attachments
  ADD CONSTRAINT invoice_attachments_pkey PRIMARY KEY (id);

GRANT ALL ON public.invoice_attachments TO anon;

GRANT ALL ON public.invoice_attachments TO authenticated;

GRANT ALL ON public.invoice_attachments TO service_role;

CREATE INDEX idx_invoice_attachments_invoice ON public.invoice_attachments (invoice_id, sort_order);

CREATE INDEX idx_invoice_attachments_tool_asset ON public.invoice_attachments (tool_asset_id);

CREATE TABLE public.invoice_labour_lines (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  invoice_id uuid                     NOT NULL,
  sort_order integer                  DEFAULT 0 NOT NULL,
  staff_id   uuid,
  staff_name text                     NOT NULL,
  pay_type   text                     DEFAULT 'day'::text NOT NULL,
  rate_type  text                     DEFAULT 'standard'::text NOT NULL,
  rate       numeric(12,2)            DEFAULT 0 NOT NULL,
  quantity   numeric(10,2)            DEFAULT 0 NOT NULL,
  line_total numeric(12,2)            GENERATED ALWAYS AS (GREATEST((rate * quantity), (0)::numeric)) STORED,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.invoice_labour_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.invoice_labour_lines
  ADD CONSTRAINT invoice_labour_lines_pay_type_check CHECK (pay_type = ANY (ARRAY['day'::text, 'hour'::text]));

ALTER TABLE public.invoice_labour_lines
  ADD CONSTRAINT invoice_labour_lines_pkey PRIMARY KEY (id);

ALTER TABLE public.invoice_labour_lines
  ADD CONSTRAINT invoice_labour_lines_rate_type_check CHECK (rate_type = ANY (ARRAY['standard'::text, 'weekend'::text, 'emergency'::text, 'sociable'::text]));

GRANT ALL ON public.invoice_labour_lines TO anon;

GRANT ALL ON public.invoice_labour_lines TO authenticated;

GRANT ALL ON public.invoice_labour_lines TO service_role;

CREATE INDEX idx_invoice_labour_lines_invoice ON public.invoice_labour_lines (invoice_id, sort_order);

CREATE INDEX idx_invoice_labour_lines_staff ON public.invoice_labour_lines (staff_id);

CREATE TABLE public.invoice_lines (
  id              uuid                     DEFAULT gen_random_uuid() NOT NULL,
  invoice_id      uuid                     NOT NULL,
  sort_order      integer                  DEFAULT 0 NOT NULL,
  kind            text                     NOT NULL,
  pricing_item_id uuid,
  item_name       text                     NOT NULL,
  item_code       text,
  rate            numeric(12,2)            DEFAULT 0 NOT NULL,
  unit_markup     numeric(12,2)            DEFAULT 0 NOT NULL,
  discount        numeric(5,2)             DEFAULT 0 NOT NULL,
  quantity        integer                  DEFAULT 1 NOT NULL,
  line_total      numeric(12,2)            GENERATED ALWAYS AS
    (GREATEST((((rate + unit_markup) * (quantity)::numeric) * ((1)::numeric - (discount / (100)::numeric))), (0)::numeric)) STORED,
  created_at      timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.invoice_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.invoice_lines
  ADD CONSTRAINT invoice_lines_discount_check CHECK (discount >= 0::numeric AND discount <= 100::numeric);

ALTER TABLE public.invoice_lines
  ADD CONSTRAINT invoice_lines_kind_check CHECK (kind = ANY (ARRAY['service'::text, 'material'::text]));

ALTER TABLE public.invoice_lines
  ADD CONSTRAINT invoice_lines_pkey PRIMARY KEY (id);

GRANT ALL ON public.invoice_lines TO anon;

GRANT ALL ON public.invoice_lines TO authenticated;

GRANT ALL ON public.invoice_lines TO service_role;

CREATE INDEX idx_invoice_lines_pricing_item ON public.invoice_lines (pricing_item_id);

CREATE INDEX idx_invoice_lines_invoice ON public.invoice_lines (invoice_id, sort_order);

CREATE TABLE public.invoice_terms (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  invoice_id uuid                     NOT NULL,
  sort_order integer                  DEFAULT 0 NOT NULL,
  term_id    uuid,
  name       text                     NOT NULL,
  details    text                     DEFAULT ''::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.invoice_terms
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.invoice_terms
  ADD CONSTRAINT invoice_terms_pkey PRIMARY KEY (id);

GRANT ALL ON public.invoice_terms TO anon;

GRANT ALL ON public.invoice_terms TO authenticated;

GRANT ALL ON public.invoice_terms TO service_role;

CREATE INDEX idx_invoice_terms_term ON public.invoice_terms (term_id);

CREATE INDEX idx_invoice_terms_invoice ON public.invoice_terms (invoice_id, sort_order);

CREATE TABLE public.invoices (
  id                uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id          uuid                     NOT NULL,
  reference         text                     NOT NULL,
  title             text                     DEFAULT ''::text NOT NULL,
  status            text                     DEFAULT 'draft'::text NOT NULL,
  invoice_date      date                     DEFAULT CURRENT_DATE NOT NULL,
  due_date          date                     NOT NULL,
  total             numeric(12,2)            DEFAULT 0 NOT NULL,
  customer_id       uuid,
  customer_snapshot jsonb,
  payment_method    text                     DEFAULT 'cash'::text NOT NULL,
  bank_snapshot     jsonb,
  share_token       text,
  sent_at           timestamp with time zone,
  viewed_at         timestamp with time zone,
  paid_at           timestamp with time zone,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY "owner deletes invoice_attachments" ON public.invoice_attachments
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_attachments.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner inserts invoice_attachments" ON public.invoice_attachments
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_attachments.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner reads invoice_attachments" ON public.invoice_attachments
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_attachments.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner updates invoice_attachments" ON public.invoice_attachments
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_attachments.invoice_id) AND (i.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_attachments.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner deletes invoice_labour_lines" ON public.invoice_labour_lines
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_labour_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner inserts invoice_labour_lines" ON public.invoice_labour_lines
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_labour_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner reads invoice_labour_lines" ON public.invoice_labour_lines
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_labour_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner updates invoice_labour_lines" ON public.invoice_labour_lines
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_labour_lines.invoice_id) AND (i.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_labour_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner deletes invoice_lines" ON public.invoice_lines
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner inserts invoice_lines" ON public.invoice_lines
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner reads invoice_lines" ON public.invoice_lines
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner updates invoice_lines" ON public.invoice_lines
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_lines.invoice_id) AND (i.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_lines.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner deletes invoice_terms" ON public.invoice_terms
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_terms.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner inserts invoice_terms" ON public.invoice_terms
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_terms.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner reads invoice_terms" ON public.invoice_terms
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_terms.invoice_id) AND (i.owner_id = auth.uid())))));

CREATE POLICY "owner updates invoice_terms" ON public.invoice_terms
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_terms.invoice_id) AND (i.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.invoices i
  WHERE ((i.id = invoice_terms.invoice_id) AND (i.owner_id = auth.uid())))));

ALTER TABLE public.invoices
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.invoices
  ADD CONSTRAINT invoices_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;

ALTER TABLE public.invoices
  ADD CONSTRAINT invoices_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.invoices
  ADD CONSTRAINT invoices_payment_method_check CHECK (payment_method = ANY (ARRAY['cash'::text, 'bank_deposit'::text]));

ALTER TABLE public.invoices
  ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);

ALTER TABLE public.document_shares
  ADD CONSTRAINT document_shares_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;

ALTER TABLE public.invoice_attachments
  ADD CONSTRAINT invoice_attachments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;

ALTER TABLE public.invoice_labour_lines
  ADD CONSTRAINT invoice_labour_lines_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;

ALTER TABLE public.invoice_lines
  ADD CONSTRAINT invoice_lines_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;

ALTER TABLE public.invoice_terms
  ADD CONSTRAINT invoice_terms_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;

ALTER TABLE public.invoices
  ADD CONSTRAINT invoices_status_check CHECK (status = ANY (ARRAY['draft'::text, 'sent'::text, 'paid'::text, 'overdue'::text, 'cancelled'::text]));

GRANT ALL ON public.invoices TO anon;

GRANT ALL ON public.invoices TO authenticated;

GRANT ALL ON public.invoices TO service_role;

CREATE INDEX idx_invoices_owner_due ON public.invoices (owner_id, due_date);

CREATE UNIQUE INDEX uq_invoices_owner_reference ON public.invoices (owner_id, reference);

CREATE INDEX idx_invoices_owner_status ON public.invoices (owner_id, status);

CREATE INDEX idx_invoices_customer ON public.invoices (customer_id);

CREATE INDEX idx_invoices_owner ON public.invoices (owner_id);

CREATE INDEX idx_invoices_owner_date ON public.invoices (owner_id, invoice_date DESC);

CREATE TRIGGER touch_invoices
  BEFORE UPDATE ON public.invoices
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes invoices" ON public.invoices
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts invoices" ON public.invoices
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads invoices" ON public.invoices
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates invoices" ON public.invoices
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.job_attachments (
  id                     uuid                     DEFAULT gen_random_uuid() NOT NULL,
  job_id                 uuid                     NOT NULL,
  sort_order             integer                  DEFAULT 0 NOT NULL,
  kind                   text                     NOT NULL,
  tool_asset_id          uuid,
  title                  text                     DEFAULT ''::text NOT NULL,
  description            text                     DEFAULT ''::text NOT NULL,
  body                   text,
  url                    text,
  storage_path           text,
  file_name              text,
  mime_type              text,
  size_bytes             bigint                   DEFAULT 0 NOT NULL,
  thumbnail_url          text,
  thumbnail_storage_path text,
  created_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.job_attachments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.job_attachments
  ADD CONSTRAINT job_attachments_kind_check CHECK (kind = ANY (ARRAY['note'::text, 'photo'::text, 'video'::text, 'file'::text]));

ALTER TABLE public.job_attachments
  ADD CONSTRAINT job_attachments_pkey PRIMARY KEY (id);

GRANT ALL ON public.job_attachments TO anon;

GRANT ALL ON public.job_attachments TO authenticated;

GRANT ALL ON public.job_attachments TO service_role;

CREATE INDEX idx_job_attachments_job ON public.job_attachments (job_id, sort_order);

CREATE INDEX idx_job_attachments_tool_asset ON public.job_attachments (tool_asset_id);

CREATE TABLE public.job_expenses (
  id                    uuid                     DEFAULT gen_random_uuid() NOT NULL,
  job_id                uuid                     NOT NULL,
  title                 text                     NOT NULL,
  amount                numeric(12,2)            DEFAULT 0 NOT NULL,
  expense_date          date                     DEFAULT CURRENT_DATE NOT NULL,
  description           text                     DEFAULT ''::text NOT NULL,
  receipt_tool_asset_id uuid,
  receipt_snapshot      jsonb,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.job_expenses
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.job_expenses
  ADD CONSTRAINT job_expenses_pkey PRIMARY KEY (id);

GRANT ALL ON public.job_expenses TO anon;

GRANT ALL ON public.job_expenses TO authenticated;

GRANT ALL ON public.job_expenses TO service_role;

CREATE INDEX idx_job_expenses_job ON public.job_expenses (job_id, expense_date DESC);

CREATE INDEX idx_job_expenses_receipt ON public.job_expenses (receipt_tool_asset_id);

CREATE TRIGGER touch_job_expenses
  BEFORE UPDATE ON public.job_expenses
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TABLE public.job_links (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  job_id     uuid                     NOT NULL,
  quote_id   uuid,
  invoice_id uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.job_links
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.job_links
  ADD CONSTRAINT job_links_exactly_one CHECK (((quote_id IS NOT NULL)::integer + (invoice_id IS NOT NULL)::integer) = 1);

ALTER TABLE public.job_links
  ADD CONSTRAINT job_links_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;

ALTER TABLE public.job_links
  ADD CONSTRAINT job_links_pkey PRIMARY KEY (id);

GRANT ALL ON public.job_links TO anon;

GRANT ALL ON public.job_links TO authenticated;

GRANT ALL ON public.job_links TO service_role;

CREATE INDEX idx_job_links_invoice ON public.job_links (invoice_id);

CREATE UNIQUE INDEX uq_job_links_quote ON public.job_links (job_id, quote_id)
  WHERE quote_id IS NOT NULL;

CREATE UNIQUE INDEX uq_job_links_invoice ON public.job_links (job_id, invoice_id)
  WHERE invoice_id IS NOT NULL;

CREATE INDEX idx_job_links_quote ON public.job_links (quote_id);

CREATE INDEX idx_job_links_job ON public.job_links (job_id);

CREATE TABLE public.job_time_entries (
  id               uuid                     DEFAULT gen_random_uuid() NOT NULL,
  job_id           uuid                     NOT NULL,
  started_at       timestamp with time zone NOT NULL,
  ended_at         timestamp with time zone NOT NULL,
  duration_seconds integer                  GENERATED ALWAYS AS (GREATEST((EXTRACT(epoch FROM (ended_at - started_at)))::integer, 0)) STORED,
  created_at       timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.job_time_entries
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.job_time_entries
  ADD CONSTRAINT job_time_entries_ordered CHECK (ended_at >= started_at);

ALTER TABLE public.job_time_entries
  ADD CONSTRAINT job_time_entries_pkey PRIMARY KEY (id);

GRANT ALL ON public.job_time_entries TO anon;

GRANT ALL ON public.job_time_entries TO authenticated;

GRANT ALL ON public.job_time_entries TO service_role;

CREATE INDEX idx_job_time_entries_job ON public.job_time_entries (job_id, started_at DESC);

CREATE TABLE public.jobs (
  id                uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id          uuid                     NOT NULL,
  reference         text                     NOT NULL,
  title             text                     DEFAULT ''::text NOT NULL,
  description       text                     DEFAULT ''::text NOT NULL,
  status            text                     DEFAULT 'draft'::text NOT NULL,
  start_date        date                     DEFAULT CURRENT_DATE NOT NULL,
  customer_id       uuid,
  customer_snapshot jsonb,
  clock_in_at       timestamp with time zone,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY "owner deletes job_attachments" ON public.job_attachments
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_attachments.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner inserts job_attachments" ON public.job_attachments
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_attachments.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner reads job_attachments" ON public.job_attachments
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_attachments.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner updates job_attachments" ON public.job_attachments
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_attachments.job_id) AND (j.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_attachments.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner deletes job_expenses" ON public.job_expenses
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_expenses.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner inserts job_expenses" ON public.job_expenses
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_expenses.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner reads job_expenses" ON public.job_expenses
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_expenses.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner updates job_expenses" ON public.job_expenses
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_expenses.job_id) AND (j.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_expenses.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner deletes job_links" ON public.job_links
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_links.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner inserts job_links" ON public.job_links
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_links.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner reads job_links" ON public.job_links
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_links.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner updates job_links" ON public.job_links
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_links.job_id) AND (j.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_links.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner deletes job_time_entries" ON public.job_time_entries
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_time_entries.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner inserts job_time_entries" ON public.job_time_entries
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_time_entries.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner reads job_time_entries" ON public.job_time_entries
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_time_entries.job_id) AND (j.owner_id = auth.uid())))));

CREATE POLICY "owner updates job_time_entries" ON public.job_time_entries
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_time_entries.job_id) AND (j.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.jobs j
  WHERE ((j.id = job_time_entries.job_id) AND (j.owner_id = auth.uid())))));

ALTER TABLE public.jobs
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;

ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);

ALTER TABLE public.job_attachments
  ADD CONSTRAINT job_attachments_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;

ALTER TABLE public.job_expenses
  ADD CONSTRAINT job_expenses_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;

ALTER TABLE public.job_links
  ADD CONSTRAINT job_links_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;

ALTER TABLE public.job_time_entries
  ADD CONSTRAINT job_time_entries_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;

ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_status_check CHECK (status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'cancelled'::text]));

GRANT ALL ON public.jobs TO anon;

GRANT ALL ON public.jobs TO authenticated;

GRANT ALL ON public.jobs TO service_role;

CREATE INDEX idx_jobs_owner_start ON public.jobs (owner_id, start_date DESC);

CREATE INDEX idx_jobs_running ON public.jobs (owner_id)
  WHERE clock_in_at IS NOT NULL;

CREATE INDEX idx_jobs_customer ON public.jobs (customer_id);

CREATE INDEX idx_jobs_owner ON public.jobs (owner_id);

CREATE INDEX idx_jobs_owner_status ON public.jobs (owner_id, status);

CREATE TRIGGER touch_jobs
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes jobs" ON public.jobs
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts jobs" ON public.jobs
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads jobs" ON public.jobs
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates jobs" ON public.jobs
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.journal_entries (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id      uuid                     NOT NULL,
  title         text                     NOT NULL,
  entry_date    date                     NOT NULL,
  all_day       boolean                  DEFAULT true NOT NULL,
  start_at      timestamp with time zone,
  end_at        timestamp with time zone,
  customer_id   uuid,
  customer_name text,
  location      text,
  notes         text,
  created_at    timestamp with time zone DEFAULT now() NOT NULL,
  updated_at    timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.journal_entries
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.journal_entries
  ADD CONSTRAINT journal_entries_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;

ALTER TABLE public.journal_entries
  ADD CONSTRAINT journal_entries_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.journal_entries
  ADD CONSTRAINT journal_entries_pkey PRIMARY KEY (id);

GRANT ALL ON public.journal_entries TO anon;

GRANT ALL ON public.journal_entries TO authenticated;

GRANT ALL ON public.journal_entries TO service_role;

CREATE INDEX idx_journal_entries_owner ON public.journal_entries (owner_id);

CREATE INDEX idx_journal_entries_customer ON public.journal_entries (customer_id);

CREATE INDEX idx_journal_entries_owner_date ON public.journal_entries (owner_id, entry_date);

CREATE TRIGGER touch_journal_entries
  BEFORE UPDATE ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes journal_entries" ON public.journal_entries
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts journal_entries" ON public.journal_entries
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads journal_entries" ON public.journal_entries
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates journal_entries" ON public.journal_entries
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.notifications (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id   uuid                     NOT NULL,
  type       text                     DEFAULT 'general'::text NOT NULL,
  title      text                     DEFAULT ''::text NOT NULL,
  body       text                     DEFAULT ''::text NOT NULL,
  read       boolean                  DEFAULT false NOT NULL,
  read_at    timestamp with time zone,
  payload    jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.notifications
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.notifications TO anon;

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON public.notifications TO authenticated;

GRANT ALL ON public.notifications TO service_role;

CREATE INDEX idx_notifications_unread ON public.notifications (owner_id)
  WHERE read = false;

CREATE INDEX idx_notifications_owner ON public.notifications (owner_id, created_at DESC);

CREATE TRIGGER notifications_guard_columns
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notifications_only_read_flag();

CREATE POLICY "owner marks notifications read" ON public.notifications
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads notifications" ON public.notifications
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE TABLE public.pricing_items (
  id          uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id    uuid                     NOT NULL,
  kind        text                     NOT NULL,
  name        text                     NOT NULL,
  unit_cost   numeric(12,2)            DEFAULT 0 NOT NULL,
  unit_markup numeric(12,2)            DEFAULT 0 NOT NULL,
  item_code   text,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.pricing_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.pricing_items
  ADD CONSTRAINT pricing_items_kind_check CHECK (kind = ANY (ARRAY['service'::text, 'material'::text]));

ALTER TABLE public.pricing_items
  ADD CONSTRAINT pricing_items_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.pricing_items
  ADD CONSTRAINT pricing_items_pkey PRIMARY KEY (id);

ALTER TABLE public.invoice_lines
  ADD CONSTRAINT invoice_lines_pricing_item_id_fkey FOREIGN KEY (pricing_item_id) REFERENCES public.pricing_items(id) ON DELETE SET NULL;

GRANT ALL ON public.pricing_items TO anon;

GRANT ALL ON public.pricing_items TO authenticated;

GRANT ALL ON public.pricing_items TO service_role;

CREATE INDEX idx_pricing_items_owner ON public.pricing_items (owner_id);

CREATE INDEX idx_pricing_items_owner_kind ON public.pricing_items (owner_id, kind);

CREATE TRIGGER touch_pricing_items
  BEFORE UPDATE ON public.pricing_items
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes pricing_items" ON public.pricing_items
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts pricing_items" ON public.pricing_items
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads pricing_items" ON public.pricing_items
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates pricing_items" ON public.pricing_items
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.profiles (
  id                      uuid                     NOT NULL,
  email                   text,
  account_type            text                     DEFAULT 'tradesman'::text NOT NULL,
  verification_status     text,
  account_status          text                     DEFAULT 'active'::text NOT NULL,
  details                 jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  created_at              timestamp with time zone DEFAULT now() NOT NULL,
  updated_at              timestamp with time zone DEFAULT now() NOT NULL,
  first_name              text,
  last_name               text,
  phone                   text,
  profile_image_url       text,
  date_of_birth           date,
  bio                     text,
  introduction_bio        text,
  currency                text                     DEFAULT 'GBP'::text NOT NULL,
  work_status             text,
  links                   text[],
  trade                   text[],
  address_line1           text,
  address_line2           text,
  city                    text,
  county                  text,
  postcode                text,
  formatted_address       text,
  latitude                double precision,
  longitude               double precision,
  last_address_updated_at timestamp with time zone,
  company_name            text,
  companies_house_number  text,
  company_email           text,
  company_landline        text,
  company_website         text,
  company_logo_url        text,
  vat_registered          boolean                  DEFAULT false NOT NULL,
  vat_number              text,
  bank_name               text,
  bank_account_number     text,
  bank_sort_code          text,
  push_enabled            boolean                  DEFAULT true NOT NULL,
  email_enabled           boolean                  DEFAULT true NOT NULL,
  sms_enabled             boolean                  DEFAULT true NOT NULL,
  deletion_requested_at   timestamp with time zone,
  deletion_scheduled_at   timestamp with time zone
);

ALTER TABLE public.profiles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_account_status_check CHECK (account_status = ANY (ARRAY['active'::text, 'disabled'::text, 'deletion_pending'::text]));

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_account_type_check CHECK (account_type = ANY (ARRAY['tradesman'::text, 'business'::text, 'customer'::text]));

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_verification_status_check CHECK (verification_status = ANY (ARRAY['waiting'::text, 'verified'::text, 'unverified'::text, 'rejected'::text]));

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_work_status_check CHECK (work_status = ANY (ARRAY['available'::text, 'busy'::text, 'offline'::text]));

GRANT ALL ON public.profiles TO anon;

GRANT ALL ON public.profiles TO authenticated;

GRANT ALL ON public.profiles TO service_role;

CREATE INDEX idx_profiles_onboarding ON public.profiles (id)
  WHERE first_name IS NOT NULL AND phone IS NOT NULL AND postcode IS NOT NULL;

CREATE TRIGGER profiles_guard_server_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.profiles_guard_server_columns();

CREATE TRIGGER touch_profiles
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "Users can delete own profile" ON public.profiles
  FOR DELETE
  USING ((auth.uid() = id));

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE
  USING ((auth.uid() = id))
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT
  USING ((auth.uid() = id));

CREATE TABLE public.quote_attachments (
  id                     uuid                     DEFAULT gen_random_uuid() NOT NULL,
  quote_id               uuid                     NOT NULL,
  sort_order             integer                  DEFAULT 0 NOT NULL,
  kind                   text                     NOT NULL,
  tool_asset_id          uuid,
  title                  text                     DEFAULT ''::text NOT NULL,
  description            text                     DEFAULT ''::text NOT NULL,
  body                   text,
  url                    text,
  storage_path           text,
  file_name              text,
  mime_type              text,
  size_bytes             bigint                   DEFAULT 0 NOT NULL,
  thumbnail_url          text,
  thumbnail_storage_path text,
  created_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.quote_attachments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.quote_attachments
  ADD CONSTRAINT quote_attachments_kind_check CHECK (kind = ANY (ARRAY['note'::text, 'photo'::text, 'video'::text, 'file'::text]));

ALTER TABLE public.quote_attachments
  ADD CONSTRAINT quote_attachments_pkey PRIMARY KEY (id);

GRANT ALL ON public.quote_attachments TO anon;

GRANT ALL ON public.quote_attachments TO authenticated;

GRANT ALL ON public.quote_attachments TO service_role;

CREATE INDEX idx_quote_attachments_quote ON public.quote_attachments (quote_id, sort_order);

CREATE INDEX idx_quote_attachments_tool_asset ON public.quote_attachments (tool_asset_id);

CREATE TABLE public.quote_labour_lines (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  quote_id   uuid                     NOT NULL,
  sort_order integer                  DEFAULT 0 NOT NULL,
  staff_id   uuid,
  staff_name text                     NOT NULL,
  pay_type   text                     DEFAULT 'day'::text NOT NULL,
  rate_type  text                     DEFAULT 'standard'::text NOT NULL,
  rate       numeric(12,2)            DEFAULT 0 NOT NULL,
  quantity   numeric(10,2)            DEFAULT 0 NOT NULL,
  line_total numeric(12,2)            GENERATED ALWAYS AS (GREATEST((rate * quantity), (0)::numeric)) STORED,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.quote_labour_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.quote_labour_lines
  ADD CONSTRAINT quote_labour_lines_pay_type_check CHECK (pay_type = ANY (ARRAY['day'::text, 'hour'::text]));

ALTER TABLE public.quote_labour_lines
  ADD CONSTRAINT quote_labour_lines_pkey PRIMARY KEY (id);

ALTER TABLE public.quote_labour_lines
  ADD CONSTRAINT quote_labour_lines_rate_type_check CHECK (rate_type = ANY (ARRAY['standard'::text, 'weekend'::text, 'emergency'::text, 'sociable'::text]));

GRANT ALL ON public.quote_labour_lines TO anon;

GRANT ALL ON public.quote_labour_lines TO authenticated;

GRANT ALL ON public.quote_labour_lines TO service_role;

CREATE INDEX idx_quote_labour_lines_staff ON public.quote_labour_lines (staff_id);

CREATE INDEX idx_quote_labour_lines_quote ON public.quote_labour_lines (quote_id, sort_order);

CREATE TABLE public.quote_lines (
  id              uuid                     DEFAULT gen_random_uuid() NOT NULL,
  quote_id        uuid                     NOT NULL,
  sort_order      integer                  DEFAULT 0 NOT NULL,
  kind            text                     NOT NULL,
  pricing_item_id uuid,
  item_name       text                     NOT NULL,
  item_code       text,
  rate            numeric(12,2)            DEFAULT 0 NOT NULL,
  unit_markup     numeric(12,2)            DEFAULT 0 NOT NULL,
  discount        numeric(5,2)             DEFAULT 0 NOT NULL,
  quantity        integer                  DEFAULT 1 NOT NULL,
  line_total      numeric(12,2)            GENERATED ALWAYS AS
    (GREATEST((((rate + unit_markup) * (quantity)::numeric) * ((1)::numeric - (discount / (100)::numeric))), (0)::numeric)) STORED,
  created_at      timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.quote_lines
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.quote_lines
  ADD CONSTRAINT quote_lines_discount_check CHECK (discount >= 0::numeric AND discount <= 100::numeric);

ALTER TABLE public.quote_lines
  ADD CONSTRAINT quote_lines_kind_check CHECK (kind = ANY (ARRAY['service'::text, 'material'::text]));

ALTER TABLE public.quote_lines
  ADD CONSTRAINT quote_lines_pkey PRIMARY KEY (id);

ALTER TABLE public.quote_lines
  ADD CONSTRAINT quote_lines_pricing_item_id_fkey FOREIGN KEY (pricing_item_id) REFERENCES public.pricing_items(id) ON DELETE SET NULL;

GRANT ALL ON public.quote_lines TO anon;

GRANT ALL ON public.quote_lines TO authenticated;

GRANT ALL ON public.quote_lines TO service_role;

CREATE INDEX idx_quote_lines_pricing_item ON public.quote_lines (pricing_item_id);

CREATE INDEX idx_quote_lines_quote ON public.quote_lines (quote_id, sort_order);

CREATE TABLE public.quote_settings (
  owner_id             uuid                     NOT NULL,
  auto_generate_number boolean                  DEFAULT true NOT NULL,
  prefix               text                     DEFAULT ''::text NOT NULL,
  next_quote_number    integer                  DEFAULT 1 NOT NULL,
  next_invoice_number  integer                  DEFAULT 1 NOT NULL,
  created_at           timestamp with time zone DEFAULT now() NOT NULL,
  updated_at           timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.quote_settings
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.quote_settings
  ADD CONSTRAINT quote_settings_next_invoice_number_check CHECK (next_invoice_number > 0);

ALTER TABLE public.quote_settings
  ADD CONSTRAINT quote_settings_next_quote_number_check CHECK (next_quote_number > 0);

ALTER TABLE public.quote_settings
  ADD CONSTRAINT quote_settings_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.quote_settings
  ADD CONSTRAINT quote_settings_pkey PRIMARY KEY (owner_id);

GRANT ALL ON public.quote_settings TO anon;

GRANT ALL ON public.quote_settings TO authenticated;

GRANT ALL ON public.quote_settings TO service_role;

CREATE TRIGGER touch_quote_settings
  BEFORE UPDATE ON public.quote_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes quote_settings" ON public.quote_settings
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts quote_settings" ON public.quote_settings
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads quote_settings" ON public.quote_settings
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates quote_settings" ON public.quote_settings
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.quote_terms (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  quote_id   uuid                     NOT NULL,
  sort_order integer                  DEFAULT 0 NOT NULL,
  term_id    uuid,
  name       text                     NOT NULL,
  details    text                     DEFAULT ''::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.quote_terms
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.quote_terms
  ADD CONSTRAINT quote_terms_pkey PRIMARY KEY (id);

GRANT ALL ON public.quote_terms TO anon;

GRANT ALL ON public.quote_terms TO authenticated;

GRANT ALL ON public.quote_terms TO service_role;

CREATE INDEX idx_quote_terms_term ON public.quote_terms (term_id);

CREATE INDEX idx_quote_terms_quote ON public.quote_terms (quote_id, sort_order);

CREATE TABLE public.quotes (
  id                uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id          uuid                     NOT NULL,
  reference         text                     NOT NULL,
  title             text                     DEFAULT ''::text NOT NULL,
  status            text                     DEFAULT 'draft'::text NOT NULL,
  quote_date        date                     DEFAULT CURRENT_DATE NOT NULL,
  expiry            text                     DEFAULT 'days14'::text NOT NULL,
  total             numeric(12,2)            DEFAULT 0 NOT NULL,
  customer_id       uuid,
  customer_snapshot jsonb,
  share_token       text,
  sent_at           timestamp with time zone,
  viewed_at         timestamp with time zone,
  responded_at      timestamp with time zone,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL
);

CREATE POLICY "owner deletes quote_attachments" ON public.quote_attachments
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_attachments.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner inserts quote_attachments" ON public.quote_attachments
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_attachments.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner reads quote_attachments" ON public.quote_attachments
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_attachments.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner updates quote_attachments" ON public.quote_attachments
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_attachments.quote_id) AND (q.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_attachments.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner deletes quote_labour_lines" ON public.quote_labour_lines
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_labour_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner inserts quote_labour_lines" ON public.quote_labour_lines
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_labour_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner reads quote_labour_lines" ON public.quote_labour_lines
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_labour_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner updates quote_labour_lines" ON public.quote_labour_lines
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_labour_lines.quote_id) AND (q.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_labour_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner deletes quote_lines" ON public.quote_lines
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner inserts quote_lines" ON public.quote_lines
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner reads quote_lines" ON public.quote_lines
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner updates quote_lines" ON public.quote_lines
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_lines.quote_id) AND (q.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_lines.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner deletes quote_terms" ON public.quote_terms
  FOR DELETE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_terms.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner inserts quote_terms" ON public.quote_terms
  FOR INSERT
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_terms.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner reads quote_terms" ON public.quote_terms
  FOR SELECT
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_terms.quote_id) AND (q.owner_id = auth.uid())))));

CREATE POLICY "owner updates quote_terms" ON public.quote_terms
  FOR UPDATE
  USING ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_terms.quote_id) AND (q.owner_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.quotes q
  WHERE ((q.id = quote_terms.quote_id) AND (q.owner_id = auth.uid())))));

ALTER TABLE public.quotes
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_expiry_check CHECK (expiry = ANY (ARRAY['days7'::text, 'days14'::text, 'days28'::text, 'days90'::text, 'none'::text]));

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_pkey PRIMARY KEY (id);

ALTER TABLE public.document_shares
  ADD CONSTRAINT document_shares_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id) ON DELETE CASCADE;

ALTER TABLE public.job_links
  ADD CONSTRAINT job_links_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id) ON DELETE CASCADE;

ALTER TABLE public.quote_attachments
  ADD CONSTRAINT quote_attachments_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id) ON DELETE CASCADE;

ALTER TABLE public.quote_labour_lines
  ADD CONSTRAINT quote_labour_lines_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id) ON DELETE CASCADE;

ALTER TABLE public.quote_lines
  ADD CONSTRAINT quote_lines_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id) ON DELETE CASCADE;

ALTER TABLE public.quote_terms
  ADD CONSTRAINT quote_terms_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.quotes(id) ON DELETE CASCADE;

ALTER TABLE public.quotes
  ADD CONSTRAINT quotes_status_check CHECK (status = ANY (ARRAY['draft'::text, 'sent'::text, 'accepted'::text, 'rejected'::text]));

GRANT ALL ON public.quotes TO anon;

GRANT ALL ON public.quotes TO authenticated;

GRANT ALL ON public.quotes TO service_role;

CREATE INDEX idx_quotes_owner ON public.quotes (owner_id);

CREATE INDEX idx_quotes_customer ON public.quotes (customer_id);

CREATE INDEX idx_quotes_owner_status ON public.quotes (owner_id, status);

CREATE INDEX idx_quotes_owner_date ON public.quotes (owner_id, quote_date DESC);

CREATE UNIQUE INDEX uq_quotes_owner_reference ON public.quotes (owner_id, reference);

CREATE TRIGGER touch_quotes
  BEFORE UPDATE ON public.quotes
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes quotes" ON public.quotes
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts quotes" ON public.quotes
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads quotes" ON public.quotes
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates quotes" ON public.quotes
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.staff (
  id               uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id         uuid                     NOT NULL,
  name             text                     NOT NULL,
  email            text,
  phone            text,
  default_pay_type text                     DEFAULT 'day'::text NOT NULL,
  rate             numeric(12,2)            DEFAULT 0 NOT NULL,
  weekend_rate     numeric(12,2)            DEFAULT 0 NOT NULL,
  emergency_rate   numeric(12,2)            DEFAULT 0 NOT NULL,
  sociable_rate    numeric(12,2)            DEFAULT 0 NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.staff
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.staff
  ADD CONSTRAINT staff_default_pay_type_check CHECK (default_pay_type = ANY (ARRAY['day'::text, 'hour'::text]));

ALTER TABLE public.staff
  ADD CONSTRAINT staff_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.staff
  ADD CONSTRAINT staff_pkey PRIMARY KEY (id);

ALTER TABLE public.invoice_labour_lines
  ADD CONSTRAINT invoice_labour_lines_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(id) ON DELETE SET NULL;

ALTER TABLE public.quote_labour_lines
  ADD CONSTRAINT quote_labour_lines_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(id) ON DELETE SET NULL;

GRANT ALL ON public.staff TO anon;

GRANT ALL ON public.staff TO authenticated;

GRANT ALL ON public.staff TO service_role;

CREATE INDEX idx_staff_owner ON public.staff (owner_id);

CREATE TRIGGER touch_staff
  BEFORE UPDATE ON public.staff
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes staff" ON public.staff
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts staff" ON public.staff
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads staff" ON public.staff
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates staff" ON public.staff
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.subscriptions (
  owner_id                uuid                     NOT NULL,
  status                  text                     DEFAULT 'expired'::text NOT NULL,
  plan_type               text                     DEFAULT 'standard'::text NOT NULL,
  billing_cycle           text                     DEFAULT 'monthly'::text NOT NULL,
  provider                text,
  name                    text,
  price                   numeric(12,2)            DEFAULT 0 NOT NULL,
  product_id              text,
  original_transaction_id text,
  stripe_subscription_id  text,
  stripe_customer_id      text,
  auto_renew              boolean                  DEFAULT true NOT NULL,
  cancel_at_period_end    boolean                  DEFAULT false NOT NULL,
  current_period_start    timestamp with time zone,
  current_period_end      timestamp with time zone,
  metadata                jsonb,
  created_at              timestamp with time zone DEFAULT now() NOT NULL,
  updated_at              timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.subscriptions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_billing_cycle_check CHECK (billing_cycle = ANY (ARRAY['monthly'::text, 'yearly'::text]));

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (owner_id);

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_plan_type_check CHECK (plan_type = ANY (ARRAY['standard'::text, 'plus'::text, 'advance'::text, 'vip'::text]));

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_provider_check CHECK (provider = ANY (ARRAY['apple'::text, 'google'::text, 'stripe'::text, 'trial'::text]));

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_status_check CHECK (status = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text, 'trial'::text, 'pending'::text]));

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON public.subscriptions TO anon;

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON public.subscriptions TO authenticated;

GRANT ALL ON public.subscriptions TO service_role;

CREATE INDEX idx_subscriptions_transaction ON public.subscriptions (original_transaction_id);

CREATE TRIGGER touch_subscriptions
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner reads subscription" ON public.subscriptions
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE TABLE public.term_library (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id   uuid                     NOT NULL,
  name       text                     NOT NULL,
  details    text                     DEFAULT ''::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.term_library
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.term_library
  ADD CONSTRAINT term_library_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.term_library
  ADD CONSTRAINT term_library_pkey PRIMARY KEY (id);

ALTER TABLE public.invoice_terms
  ADD CONSTRAINT invoice_terms_term_id_fkey FOREIGN KEY (term_id) REFERENCES public.term_library(id) ON DELETE SET NULL;

ALTER TABLE public.quote_terms
  ADD CONSTRAINT quote_terms_term_id_fkey FOREIGN KEY (term_id) REFERENCES public.term_library(id) ON DELETE SET NULL;

GRANT ALL ON public.term_library TO anon;

GRANT ALL ON public.term_library TO authenticated;

GRANT ALL ON public.term_library TO service_role;

CREATE INDEX idx_term_library_owner ON public.term_library (owner_id);

CREATE TRIGGER touch_term_library
  BEFORE UPDATE ON public.term_library
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes term_library" ON public.term_library
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts term_library" ON public.term_library
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads term_library" ON public.term_library
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates term_library" ON public.term_library
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.todos (
  id           uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id     uuid                     NOT NULL,
  title        text                     NOT NULL,
  notes        text,
  due_at       timestamp with time zone,
  completed    boolean                  DEFAULT false NOT NULL,
  completed_at timestamp with time zone,
  tag_color    integer,
  created_at   timestamp with time zone DEFAULT now() NOT NULL,
  updated_at   timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.todos
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.todos
  ADD CONSTRAINT todos_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.todos
  ADD CONSTRAINT todos_pkey PRIMARY KEY (id);

GRANT ALL ON public.todos TO anon;

GRANT ALL ON public.todos TO authenticated;

GRANT ALL ON public.todos TO service_role;

CREATE INDEX idx_todos_owner_open ON public.todos (owner_id, completed, due_at);

CREATE INDEX idx_todos_owner ON public.todos (owner_id);

CREATE TRIGGER touch_todos
  BEFORE UPDATE ON public.todos
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes todos" ON public.todos
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts todos" ON public.todos
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads todos" ON public.todos
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates todos" ON public.todos
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.tool_assets (
  id                     uuid                     DEFAULT gen_random_uuid() NOT NULL,
  owner_id               uuid                     NOT NULL,
  kind                   text                     NOT NULL,
  title                  text                     DEFAULT ''::text NOT NULL,
  description            text                     DEFAULT ''::text NOT NULL,
  body                   text,
  url                    text,
  storage_path           text,
  file_name              text,
  mime_type              text,
  size_bytes             bigint                   DEFAULT 0 NOT NULL,
  thumbnail_url          text,
  thumbnail_storage_path text,
  created_at             timestamp with time zone DEFAULT now() NOT NULL,
  updated_at             timestamp with time zone DEFAULT now() NOT NULL
);

ALTER PUBLICATION supabase_realtime ADD TABLE public.customers,
  TABLE public.invoices,
  TABLE public.jobs,
  TABLE public.journal_entries,
  TABLE public.notifications,
  TABLE public.pricing_items, TABLE public.profiles, TABLE public.quotes, TABLE public.staff, TABLE public.subscriptions, TABLE public.todos, TABLE public.tool_assets;

ALTER TABLE public.tool_assets
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tool_assets
  ADD CONSTRAINT tool_assets_kind_check CHECK (kind = ANY (ARRAY['note'::text, 'photo'::text, 'video'::text, 'file'::text]));

ALTER TABLE public.tool_assets
  ADD CONSTRAINT tool_assets_kind_shape CHECK (kind = 'note'::text AND storage_path IS NULL OR kind <> 'note'::text AND storage_path IS NOT NULL);

ALTER TABLE public.tool_assets
  ADD CONSTRAINT tool_assets_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.tool_assets
  ADD CONSTRAINT tool_assets_pkey PRIMARY KEY (id);

ALTER TABLE public.invoice_attachments
  ADD CONSTRAINT invoice_attachments_tool_asset_id_fkey FOREIGN KEY (tool_asset_id) REFERENCES public.tool_assets(id) ON DELETE SET NULL;

ALTER TABLE public.job_attachments
  ADD CONSTRAINT job_attachments_tool_asset_id_fkey FOREIGN KEY (tool_asset_id) REFERENCES public.tool_assets(id) ON DELETE SET NULL;

ALTER TABLE public.job_expenses
  ADD CONSTRAINT job_expenses_receipt_tool_asset_id_fkey FOREIGN KEY (receipt_tool_asset_id) REFERENCES public.tool_assets(id) ON DELETE SET NULL;

ALTER TABLE public.quote_attachments
  ADD CONSTRAINT quote_attachments_tool_asset_id_fkey FOREIGN KEY (tool_asset_id) REFERENCES public.tool_assets(id) ON DELETE SET NULL;

GRANT ALL ON public.tool_assets TO anon;

GRANT ALL ON public.tool_assets TO authenticated;

GRANT ALL ON public.tool_assets TO service_role;

CREATE INDEX idx_tool_assets_owner_kind ON public.tool_assets (owner_id, kind, created_at DESC);

CREATE INDEX idx_tool_assets_owner ON public.tool_assets (owner_id);

CREATE TRIGGER touch_tool_assets
  BEFORE UPDATE ON public.tool_assets
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner deletes tool_assets" ON public.tool_assets
  FOR DELETE
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner inserts tool_assets" ON public.tool_assets
  FOR INSERT
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "owner reads tool_assets" ON public.tool_assets
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE POLICY "owner updates tool_assets" ON public.tool_assets
  FOR UPDATE
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE TABLE public.usage_counters (
  owner_id           uuid                     NOT NULL,
  period_start       date                     DEFAULT (date_trunc('month'::text, now()))::date NOT NULL,
  voice_seconds_used integer                  DEFAULT 0 NOT NULL,
  suggestions_used   integer                  DEFAULT 0 NOT NULL,
  leads_viewed       integer                  DEFAULT 0 NOT NULL,
  created_at         timestamp with time zone DEFAULT now() NOT NULL,
  updated_at         timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.usage_counters
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.usage_counters
  ADD CONSTRAINT usage_counters_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.usage_counters
  ADD CONSTRAINT usage_counters_pkey PRIMARY KEY (owner_id);

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON public.usage_counters TO anon;

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON public.usage_counters TO authenticated;

GRANT ALL ON public.usage_counters TO service_role;

CREATE TRIGGER touch_usage_counters
  BEFORE UPDATE ON public.usage_counters
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "owner reads usage_counters" ON public.usage_counters
  FOR SELECT
  USING ((auth.uid() = owner_id));

CREATE VIEW public.invoices_with_derived WITH (security_invoker=true) AS SELECT id,
    owner_id,
    reference,
    title,
    status,
    invoice_date,
    due_date,
    total,
    customer_id,
    customer_snapshot,
    payment_method,
    bank_snapshot,
    share_token,
    sent_at,
    viewed_at,
    paid_at,
    created_at,
    updated_at,
    ((status = 'sent'::text) AND (due_date < CURRENT_DATE)) AS is_overdue
   FROM public.invoices i;

GRANT ALL ON public.invoices_with_derived TO anon;

GRANT ALL ON public.invoices_with_derived TO authenticated;

GRANT ALL ON public.invoices_with_derived TO service_role;

CREATE VIEW public.usage_summary WITH (security_invoker=true) AS SELECT id AS owner_id,
    ( SELECT count(*) AS count
           FROM public.customers c
          WHERE (c.owner_id = p.id)) AS customer_count,
    ( SELECT count(*) AS count
           FROM public.staff s
          WHERE (s.owner_id = p.id)) AS staff_count,
    ( SELECT count(*) AS count
           FROM public.pricing_items i
          WHERE (i.owner_id = p.id)) AS pricing_item_count,
    ( SELECT count(*) AS count
           FROM public.quotes q
          WHERE (q.owner_id = p.id)) AS quote_count,
    ( SELECT count(*) AS count
           FROM public.invoices v
          WHERE (v.owner_id = p.id)) AS invoice_count,
    ( SELECT count(*) AS count
           FROM public.jobs j
          WHERE (j.owner_id = p.id)) AS job_count,
    ( SELECT count(*) AS count
           FROM public.tool_assets t
          WHERE ((t.owner_id = p.id) AND (t.kind = 'photo'::text))) AS photo_count,
    ( SELECT count(*) AS count
           FROM public.tool_assets t
          WHERE ((t.owner_id = p.id) AND (t.kind = 'video'::text))) AS video_count,
    ( SELECT count(*) AS count
           FROM public.tool_assets t
          WHERE ((t.owner_id = p.id) AND (t.kind = 'file'::text))) AS file_count,
    ( SELECT count(*) AS count
           FROM public.tool_assets t
          WHERE ((t.owner_id = p.id) AND (t.kind = 'note'::text))) AS note_count
   FROM public.profiles p;

GRANT ALL ON public.usage_summary TO anon;

GRANT ALL ON public.usage_summary TO authenticated;

GRANT ALL ON public.usage_summary TO service_role;

CREATE EVENT TRIGGER ensure_rls
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION public.rls_auto_enable();
