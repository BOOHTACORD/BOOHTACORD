-- Initialize only when the identity table is first created. A missing row on an
-- existing deployment is corruption, never an invitation to invent a new history.
DO $$
BEGIN
  PERFORM pg_advisory_xact_lock(3360054);
  IF to_regclass('installation_identity') IS NULL THEN
    CREATE TABLE installation_identity (
      singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
      installation_id uuid NOT NULL UNIQUE,
      pseudonym_key bytea NOT NULL CHECK (octet_length(pseudonym_key)=32),
      enrollment_seed bytea NOT NULL CHECK (octet_length(enrollment_seed)=32),
      mode text NOT NULL DEFAULT 'local_only' CHECK (mode IN ('local_only','central')),
      central_endpoint text NOT NULL DEFAULT '',
      credential text NOT NULL DEFAULT '',
      enrolled boolean NOT NULL DEFAULT false,
      last_accepted_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    INSERT INTO installation_identity(singleton,installation_id,pseudonym_key,enrollment_seed)
    VALUES(true,gen_random_uuid(),uuid_send(gen_random_uuid())||uuid_send(gen_random_uuid()),uuid_send(gen_random_uuid())||uuid_send(gen_random_uuid()));
  END IF;
END $$;
