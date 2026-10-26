-- Session retention and account deletion must never be blocked by push metadata.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='notification_devices'::regclass AND conname='notification_devices_session_digest_fkey' AND confdeltype<>'c') THEN
  ALTER TABLE notification_devices DROP CONSTRAINT notification_devices_session_digest_fkey;
  ALTER TABLE notification_devices ADD CONSTRAINT notification_devices_session_digest_fkey FOREIGN KEY(session_digest) REFERENCES sessions(token_digest) ON DELETE CASCADE;
 END IF;
 IF EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='notification_attention'::regclass AND conname='notification_attention_session_digest_fkey' AND confdeltype<>'c') THEN
  ALTER TABLE notification_attention DROP CONSTRAINT notification_attention_session_digest_fkey;
  ALTER TABLE notification_attention ADD CONSTRAINT notification_attention_session_digest_fkey FOREIGN KEY(session_digest) REFERENCES sessions(token_digest) ON DELETE CASCADE;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION reclaim_deleted_notification_budget() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_TABLE_NAME='notification_deliveries' AND OLD.state IN('pending','claimed','retry') THEN
  UPDATE notification_runtime_policy SET delivery_pending=greatest(0,delivery_pending-1) WHERE singleton;
 ELSIF TG_TABLE_NAME='notification_outbox' AND OLD.state IN('pending','planning') THEN
  UPDATE notification_runtime_policy SET intent_pending=greatest(0,intent_pending-1) WHERE singleton;
 END IF;
 RETURN OLD;
END;
$$;
CREATE OR REPLACE TRIGGER notification_deleted_delivery AFTER DELETE ON notification_deliveries
 FOR EACH ROW EXECUTE FUNCTION reclaim_deleted_notification_budget();
CREATE OR REPLACE TRIGGER notification_deleted_intent AFTER DELETE ON notification_outbox
 FOR EACH ROW EXECUTE FUNCTION reclaim_deleted_notification_budget();
