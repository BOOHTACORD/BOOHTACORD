# Support service DELETE guard implementation plan

> **For agentic workers:** Execute these bounded steps inline; preserve historical migration 0056.

**Goal:** Close #592 by restoring ordinary DELETE without weakening the support identity/session guard.

**Architecture:** Add forward migration 0065 replacing only protect_support_service_account. Native embedded Run applies it after 0064, including upgraded installations and repeated startup. Existing immutable guard and session trigger remain.

**Tech Stack:** Go 1.26.4, pgx v5, actual disposable PostgreSQL 17.6, embedded SQL migrations.

---

### Task 1: Retained behavior regression before SQL

Create `backend/internal/database/migrate/support_service_guard_integration_test.go`.
Use newMigrationTestPool and Run, then INSERT a synthetic ordinary MEMBER.
Require UPDATE RowsAffected()==1 and DELETE RowsAffected()==1; SELECT must show the row absent.
This ordinary DELETE must fail on the unchanged historical function (actual DELETE0).
Independently require SQLSTATE42501 for support user UPDATE/DELETE and session INSERT/UPDATE.

Run from backend with TEST_DATABASE_URL bound only to the owned loopback test container:

```sh
go test -json -count=1 ./internal/database/migrate -run TestSupportServiceGuard
```

- [x] Saved actual failing DELETE0 event stream (two failures); security controls pass independently. Two earlier fixture setup errors are retained as diagnostics.

### Task 2: Add the forward repair

Create `backend/internal/database/migrate/migrations/0065_support_service_delete.sql`:

```sql
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
```

- [x] Appended the explicit function/TG_OP/RETURN OLD inventory entry; exact inventory remains required.
- [x] All three focused tests passed as part of the complete native package run, with zero skips.
- [x] A 0064 prefix upgrade and two Run replays preserve ordinary DELETE, service identity and session fences.
- [x] Full package: 9 top-level +2 subtest PASS events, zero fail/skip events.

### Task 3: Integrate and close

- [x] Recorded version170006, source/SQL/log hashes, RED/GREEN and mandatory-command mapping under evidence/qa.
- [x] Historical0056 unchanged; remaining disposable schemas0.
- [ ] Inspect status and changed sizes, stage only named source/test/plan/evidence files.
- [ ] Require actual PostgreSQL17.6 hosted gate on final PR source, merge and approved server delivery.
- [ ] Close #592 only with forward-migration/upgrade/repeat/security/cleanup proof; no public account-deletion API or device/media claim.
