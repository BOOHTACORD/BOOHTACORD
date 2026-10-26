CREATE TABLE IF NOT EXISTS notification_preference_fences (
 account_id uuid NOT NULL REFERENCES notification_preferences(account_id) ON DELETE CASCADE,
 kind text NOT NULL CHECK(kind IN('ALL','DM','TEXT','CHANNEL','DIRECT_MESSAGE')),
 target uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
 changed_at timestamptz NOT NULL,
 PRIMARY KEY(account_id,kind,target)
);
-- Upgrade preserves the earlier conservative fence once, without replaying history.
INSERT INTO notification_preference_fences(account_id,kind,changed_at)
 SELECT p.account_id,'ALL',p.updated_at FROM notification_preferences p
 WHERE NOT EXISTS(SELECT 1 FROM notification_preference_fences f WHERE f.account_id=p.account_id)
 ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION fence_notification_preference_changes() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE old_settings jsonb;rule text;
BEGIN
 old_settings:=CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE OLD.settings END;
 IF TG_OP='INSERT' OR old_settings->'enabled' IS DISTINCT FROM NEW.settings->'enabled' THEN
  INSERT INTO notification_preference_fences(account_id,kind,changed_at) VALUES(NEW.account_id,'ALL',NEW.updated_at)
  ON CONFLICT(account_id,kind,target)DO UPDATE SET changed_at=EXCLUDED.changed_at;
 END IF;
 FOREACH rule IN ARRAY ARRAY['dm','text'] LOOP
  IF old_settings->rule IS DISTINCT FROM NEW.settings->rule THEN
   INSERT INTO notification_preference_fences(account_id,kind,changed_at)VALUES(NEW.account_id,upper(rule),NEW.updated_at)
   ON CONFLICT(account_id,kind,target)DO UPDATE SET changed_at=EXCLUDED.changed_at;
  END IF;
 END LOOP;
 INSERT INTO notification_preference_fences(account_id,kind,target,changed_at)
 SELECT NEW.account_id,COALESCE(a.value->>'kind',b.value->>'kind'),COALESCE(a.value->>'id',b.value->>'id')::uuid,NEW.updated_at
 FROM jsonb_array_elements(COALESCE(old_settings->'overrides','[]'::jsonb)) a(value)
 FULL JOIN jsonb_array_elements(COALESCE(NEW.settings->'overrides','[]'::jsonb)) b(value)
 ON a.value->>'kind'=b.value->>'kind' AND a.value->>'id'=b.value->>'id'
 WHERE a.value IS DISTINCT FROM b.value
 ON CONFLICT(account_id,kind,target)DO UPDATE SET changed_at=EXCLUDED.changed_at;
 DELETE FROM notification_preference_fences WHERE account_id=NEW.account_id AND kind IN('CHANNEL','DIRECT_MESSAGE') AND changed_at<now()-interval '24 hours';
 -- Bounded under the preferences row lock. Extreme churn falls back to a safe
 -- account-wide cutoff, never a historical opt-in replay or unbounded metadata.
 IF(SELECT count(*) FROM notification_preference_fences WHERE account_id=NEW.account_id)>1000 THEN
  INSERT INTO notification_preference_fences(account_id,kind,changed_at)VALUES(NEW.account_id,'ALL',NEW.updated_at)
  ON CONFLICT(account_id,kind,target)DO UPDATE SET changed_at=EXCLUDED.changed_at;
  DELETE FROM notification_preference_fences WHERE account_id=NEW.account_id AND kind IN('CHANNEL','DIRECT_MESSAGE');
 END IF;
 RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER notification_preferences_fence AFTER INSERT OR UPDATE ON notification_preferences
 FOR EACH ROW EXECUTE FUNCTION fence_notification_preference_changes();
