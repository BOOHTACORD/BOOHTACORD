-- #592: a permitted BEFORE DELETE must retain OLD, since DELETE has no NEW row.
CREATE OR REPLACE FUNCTION protect_support_service_account() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=OLD.id) THEN
  RAISE EXCEPTION 'non-interactive support peer is immutable' USING ERRCODE='42501';
 END IF;
 IF TG_OP='DELETE' THEN
  RETURN OLD;
 END IF;
 RETURN NEW;
END $$;
