CREATE TABLE relay_policy(singleton boolean PRIMARY KEY CHECK(singleton),enabled boolean NOT NULL DEFAULT true,kill_switch boolean NOT NULL DEFAULT false,epoch bigint NOT NULL DEFAULT 1 CHECK(epoch>0),pending integer NOT NULL DEFAULT 0 CHECK(pending>=0),max_pending integer NOT NULL DEFAULT 10000 CHECK(max_pending BETWEEN 1 AND 100000));
INSERT INTO relay_policy(singleton)VALUES(true);
CREATE TABLE relay_devices(
 id uuid PRIMARY KEY,public_key bytea NOT NULL CHECK(octet_length(public_key)=32),
 namespace text NOT NULL CHECK(namespace IN('staging','production')),platform text NOT NULL CHECK(platform IN('android','ios')),
 target_kind text NOT NULL CHECK(target_kind IN('fcm_fid','fcm_token')),token_cipher bytea NOT NULL,token_hash bytea NOT NULL CHECK(octet_length(token_hash)=32),
 challenge_hash bytea CHECK(octet_length(challenge_hash)=32),challenge_until timestamptz,
 state text NOT NULL CHECK(state IN('pending','active','revoked','invalid')),generation bigint NOT NULL DEFAULT 1,
 expires_at timestamptz NOT NULL,created_at timestamptz NOT NULL,updated_at timestamptz NOT NULL,
 CHECK(challenge_until IS NOT NULL)
);
CREATE UNIQUE INDEX relay_devices_destination ON relay_devices(namespace,token_hash)WHERE state IN('pending','active');
CREATE TABLE relay_tenants(
 id uuid PRIMARY KEY,origin text NOT NULL CHECK(length(origin)<=2048),installation_id uuid NOT NULL,
 public_key bytea NOT NULL CHECK(octet_length(public_key)=32),namespace text NOT NULL CHECK(namespace IN('staging','production')),
 created_at timestamptz NOT NULL,UNIQUE(origin,installation_id,namespace)
);
CREATE TABLE relay_grants(
 id uuid PRIMARY KEY,tenant_id uuid NOT NULL REFERENCES relay_tenants(id),device_id uuid NOT NULL REFERENCES relay_devices(id),
 binding_id uuid NOT NULL,generation bigint NOT NULL CHECK(generation BETWEEN 1 AND 1000000000),
 nonce_hash bytea NOT NULL CHECK(octet_length(nonce_hash)=32),receipt bytea NOT NULL,
 state text NOT NULL DEFAULT 'active' CHECK(state IN('active','revoked','invalid')),
 expires_at timestamptz NOT NULL,created_at timestamptz NOT NULL,
 UNIQUE(tenant_id,binding_id,generation)
);
CREATE INDEX relay_grants_device ON relay_grants(device_id,state);
CREATE TABLE relay_replays(role text NOT NULL CHECK(role IN('device','tenant')),subject uuid NOT NULL,nonce uuid NOT NULL,expires_at timestamptz NOT NULL,PRIMARY KEY(role,subject,nonce));
CREATE INDEX relay_replay_expiry ON relay_replays(expires_at);
CREATE TABLE relay_budgets(scope text NOT NULL CHECK(scope IN('source','device','tenant','global')),subject text NOT NULL CHECK(length(subject)<=64),window_start timestamptz NOT NULL,attempts integer NOT NULL CHECK(attempts BETWEEN 1 AND 1001),PRIMARY KEY(scope,subject));
CREATE INDEX relay_budget_expiry ON relay_budgets(window_start);
CREATE TABLE relay_jobs(
 id uuid PRIMARY KEY,tenant_id uuid REFERENCES relay_tenants(id),grant_id uuid REFERENCES relay_grants(id),device_id uuid NOT NULL REFERENCES relay_devices(id),
 job_ref uuid NOT NULL,kind text NOT NULL CHECK(kind IN('challenge','notification')),payload_cipher bytea NOT NULL,
 request_hash bytea NOT NULL CHECK(octet_length(request_hash)=32),expires_at timestamptz NOT NULL,due_at timestamptz NOT NULL,
 epoch bigint NOT NULL,state text NOT NULL DEFAULT 'pending' CHECK(state IN('pending','claimed','retry','accepted_by_provider','delivery_unknown','permanent_failure','expired','revoked')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 6),started_at timestamptz,lease_owner uuid,lease_until timestamptz,created_at timestamptz NOT NULL,
 UNIQUE(grant_id,job_ref)
);
CREATE INDEX relay_jobs_due ON relay_jobs(due_at,id)WHERE state IN('pending','claimed','retry');
CREATE INDEX relay_jobs_retention ON relay_jobs(expires_at);
CREATE TABLE relay_counters(outcome text NOT NULL CHECK(outcome IN('accepted_by_relay','accepted_by_provider','retry','delivery_unknown','invalid_binding','permanent_failure','expired','rejected','revoked')),namespace text NOT NULL CHECK(namespace IN('staging','production')),value bigint NOT NULL CHECK(value>=0),PRIMARY KEY(outcome,namespace));
