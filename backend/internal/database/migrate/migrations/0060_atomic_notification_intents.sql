CREATE OR REPLACE FUNCTION create_notification_intent() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
 target uuid; event_kind text; installation uuid; policy_epoch bigint;
 grace integer; ttl integer; sender_limit integer; attempts integer; inserted uuid;
 budget_window timestamptz := date_trunc('minute',now());
BEGIN
 IF TG_TABLE_NAME='messages' THEN
  IF NEW.kind<>'USER' THEN RETURN NEW; END IF;
  target:=NEW.channel_id; event_kind:='TEXT';
 ELSE
  target:=NEW.direct_message_id; event_kind:='DM';
 END IF;
 UPDATE notification_runtime_policy SET intent_pending=intent_pending+1
 WHERE singleton AND operator_enabled AND NOT kill_switch AND intent_pending<max_intents
 AND NEW.created_at+make_interval(secs=>ttl_seconds)>now() AND NEW.created_at<=now()+interval '5 seconds'
 RETURNING epoch,grace_seconds,ttl_seconds,sender_per_minute INTO policy_epoch,grace,ttl,sender_limit;
 IF NOT FOUND THEN
  UPDATE notification_runtime_policy SET dropped_intents=dropped_intents+1
  WHERE singleton AND operator_enabled AND NOT kill_switch;
  RETURN NEW;
 END IF;
 -- This singleton lock also bounds admission to the finite sender budget map.
 DELETE FROM notification_sender_budgets WHERE account_id IN(
  SELECT account_id FROM notification_sender_budgets WHERE window_start<now()-interval '1 hour'
  ORDER BY window_start LIMIT 1);
 INSERT INTO notification_sender_budgets(account_id,window_start,attempts)
 SELECT NEW.author_id,budget_window,1
 WHERE EXISTS(SELECT 1 FROM notification_sender_budgets WHERE account_id=NEW.author_id)
    OR (SELECT count(*) FROM notification_sender_budgets)<10000
 ON CONFLICT(account_id) DO UPDATE SET window_start=budget_window,
 attempts=CASE WHEN notification_sender_budgets.window_start=budget_window THEN LEAST(notification_sender_budgets.attempts+1,sender_limit+1) ELSE 1 END
 RETURNING notification_sender_budgets.attempts INTO attempts;
 IF NOT FOUND OR attempts>sender_limit THEN
  UPDATE notification_runtime_policy SET intent_pending=intent_pending-1,dropped_intents=dropped_intents+1,budget_drops=budget_drops+1 WHERE singleton;
  RETURN NEW;
 END IF;
 SELECT installation_id INTO installation FROM installation_identity WHERE singleton;
 IF installation IS NULL THEN
  UPDATE notification_runtime_policy SET intent_pending=intent_pending-1,dropped_intents=dropped_intents+1 WHERE singleton;
  RETURN NEW;
 END IF;
 INSERT INTO notification_outbox(installation_id,message_id,conversation_id,kind,author_id,mention_user_ids,created_at,expires_at,due_at,epoch)
 VALUES(installation,NEW.id,target,event_kind,NEW.author_id,NEW.mention_user_ids,NEW.created_at,NEW.created_at+make_interval(secs=>ttl),NEW.created_at+make_interval(secs=>grace),policy_epoch)
 ON CONFLICT(kind,message_id) DO NOTHING RETURNING id INTO inserted;
 IF inserted IS NULL THEN
  UPDATE notification_runtime_policy SET intent_pending=intent_pending-1 WHERE singleton;
 ELSE
  INSERT INTO notification_counters(metric,reason,transport,value)VALUES('intent_created','none','none',1)
  ON CONFLICT(metric,reason,transport)DO UPDATE SET value=notification_counters.value+1;
 END IF;
 RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER message_notification_intent AFTER INSERT ON messages
 FOR EACH ROW EXECUTE FUNCTION create_notification_intent();
CREATE OR REPLACE TRIGGER direct_message_notification_intent AFTER INSERT ON direct_message_messages
 FOR EACH ROW EXECUTE FUNCTION create_notification_intent();
