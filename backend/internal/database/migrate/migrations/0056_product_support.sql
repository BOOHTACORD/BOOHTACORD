-- ADR-029: only newly consented messages to this non-login local peer leave the guild.
ALTER TABLE support_contact_configuration ADD COLUMN IF NOT EXISTS mode text NOT NULL DEFAULT 'disabled'
 CHECK(mode IN ('product','local','disabled'));
CREATE TABLE IF NOT EXISTS support_product_identity (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 account_id uuid NOT NULL UNIQUE REFERENCES users(id),
 seed bytea NOT NULL CHECK(octet_length(seed)=32),
 notice_version integer NOT NULL DEFAULT 1 CHECK(notice_version>0),
 repository_public boolean NOT NULL DEFAULT true,
 reply_cursor bigint NOT NULL DEFAULT 0 CHECK(reply_cursor>=0)
);
DO $$
DECLARE peer uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM support_product_identity) THEN
  peer:=gen_random_uuid();
  INSERT INTO users(id,login,display_name,password_hash,role)
   VALUES(peer,'support.'||substr(replace(peer::text,'-',''),1,24),'Поддержка BOOHTACORD','!non-interactive-service-peer','MEMBER');
  INSERT INTO support_product_identity(singleton,account_id,seed)
   VALUES(true,peer,uuid_send(gen_random_uuid())||uuid_send(gen_random_uuid()));
  UPDATE support_contact_configuration SET mode=CASE
   WHEN support_account_id IS NOT NULL THEN 'local' WHEN revision=1 THEN 'product' ELSE 'disabled' END,
   support_account_id=CASE WHEN support_account_id IS NULL AND revision=1 THEN peer ELSE support_account_id END,
   revision=revision+1,updated_at=now();
 END IF;
END $$;
CREATE TABLE IF NOT EXISTS support_public_consents (
 user_id uuid PRIMARY KEY REFERENCES users(id),notice_version integer NOT NULL CHECK(notice_version>0),
 accepted_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS support_public_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),message_id uuid NOT NULL UNIQUE REFERENCES direct_message_messages(id),
 body text NOT NULL,notice_version integer NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 delivered_at timestamptz,cancelled_at timestamptz
);
CREATE INDEX IF NOT EXISTS support_public_outbox_pending_idx ON support_public_outbox(created_at)
 WHERE delivered_at IS NULL AND cancelled_at IS NULL;
CREATE TABLE IF NOT EXISTS support_public_routes (
 conversation text PRIMARY KEY CHECK(conversation ~ '^[a-f0-9]{32}$'),
 direct_message_id uuid NOT NULL UNIQUE REFERENCES direct_messages(id)
);

CREATE OR REPLACE FUNCTION protect_support_service_account() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=OLD.id) THEN
  RAISE EXCEPTION 'non-interactive support peer is immutable' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS support_service_account_guard ON users;
CREATE TRIGGER support_service_account_guard BEFORE UPDATE OR DELETE ON users
 FOR EACH ROW EXECUTE FUNCTION protect_support_service_account();

CREATE OR REPLACE FUNCTION reject_support_service_session() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=NEW.user_id) THEN
  RAISE EXCEPTION 'non-interactive support peer cannot authenticate' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS support_service_session_guard ON sessions;
CREATE TRIGGER support_service_session_guard BEFORE INSERT OR UPDATE OF user_id ON sessions
 FOR EACH ROW EXECUTE FUNCTION reject_support_service_session();

CREATE OR REPLACE FUNCTION consent_product_support_message() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE peer uuid; version integer;
BEGIN
 SELECT account_id,notice_version INTO peer,version FROM support_product_identity WHERE singleton=true;
 IF NEW.author_id<>peer AND EXISTS(SELECT 1 FROM direct_messages
  WHERE id=NEW.direct_message_id AND peer IN (participant_one_id,participant_two_id)) THEN
  IF NOT EXISTS(SELECT 1 FROM support_contact_configuration WHERE mode='product' AND support_account_id=peer)
   OR NOT EXISTS(SELECT 1 FROM support_public_consents WHERE user_id=NEW.author_id AND notice_version=version) THEN
   RAISE EXCEPTION 'public support consent required' USING ERRCODE='42501';
  END IF;
  INSERT INTO support_public_outbox(message_id,body,notice_version) VALUES(NEW.id,NEW.body,version);
 END IF;
 RETURN NEW;
END $$;
-- AFTER INSERT is inside the same transaction as message/attachment creation. No history backfill.
DROP TRIGGER IF EXISTS support_public_message_outbox ON direct_message_messages;
CREATE TRIGGER support_public_message_outbox AFTER INSERT ON direct_message_messages
 FOR EACH ROW EXECUTE FUNCTION consent_product_support_message();
