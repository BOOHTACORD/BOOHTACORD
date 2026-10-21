// telemetry_registry requires direct private registry access; it exposes no admin HTTP API.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"path/filepath"
	"time"
	gateway "voice-platform/backend/internal/observability/central_gateway"
)

func main() {
	if run() != nil {
		fmt.Fprintln(os.Stderr, "registry operation failed")
		os.Exit(1)
	}
}
func run() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	db, err := pgxpool.New(ctx, os.Getenv("TELEMETRY_REGISTRY_DATABASE_URL"))
	if err != nil {
		return err
	}
	defer db.Close()
	if len(os.Args) == 3 && os.Args[1] == "inspect" {
		record, err := (gateway.Postgres{DB: db}).Get(ctx, os.Args[2])
		if err != nil {
			return err
		}
		fingerprint := sha256.Sum256(record.PublicKey)
		return json.NewEncoder(os.Stdout).Encode(map[string]any{"installation": record, "key_fingerprint": hex.EncodeToString(fingerprint[:]), "policy_version": 1})
	}
	if len(os.Args) == 3 && (os.Args[1] == "revoke" || os.Args[1] == "rotate") {
		id, err := uuid.Parse(os.Args[2])
		if err != nil || id.String() != os.Args[2] {
			return fmt.Errorf("invalid installation")
		}
		sql := `UPDATE telemetry_installations SET epoch=epoch+1 WHERE installation_id=$1 AND enabled`
		if os.Args[1] == "revoke" {
			sql = `UPDATE telemetry_installations SET enabled=false,epoch=epoch+1 WHERE installation_id=$1`
		}
		tag, err := db.Exec(ctx, sql, id)
		if err != nil || tag.RowsAffected() != 1 {
			return fmt.Errorf("registry update failed")
		}
		fmt.Println("registry policy updated")
		return nil
	}
	if len(os.Args) != 3 || os.Args[1] != "datasources" {
		return fmt.Errorf("expected revoke ID, rotate ID or datasources OUTPUT_DIRECTORY")
	}
	rows, err := db.Query(ctx, `SELECT installation_id::text FROM telemetry_installations ORDER BY installation_id`)
	if err != nil {
		return err
	}
	defer rows.Close()
	sources := []map[string]any{}
	for rows.Next() {
		var id string
		if rows.Scan(&id) != nil {
			return fmt.Errorf("registry read failed")
		}
		sources = append(sources, map[string]any{"name": "tempo-" + id, "uid": "t-" + id, "type": "tempo", "access": "proxy", "url": "http://gateway:8081/read/tempo/" + id, "isDefault": false, "editable": false, "jsonData": map[string]any{"httpHeaderName1": "Authorization"}, "secureJsonData": map[string]string{"httpHeaderValue1": "Bearer ${TELEMETRY_READ_TOKEN}"}})
	}
	if rows.Err() != nil {
		return rows.Err()
	}
	body, err := json.MarshalIndent(map[string]any{"apiVersion": 1, "datasources": sources}, "", "  ")
	if err != nil {
		return err
	}
	path := filepath.Join(os.Args[2], "boohtacord-installations.yaml")
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	defer file.Close()
	_, err = file.Write(body)
	return err
}
