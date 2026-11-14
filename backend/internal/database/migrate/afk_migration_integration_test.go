package migrate

import (
	"context"
	"testing"

	"github.com/google/uuid"
)

func TestAFKMigrationIsRepeatableAndPreservesConfiguredDestination(t *testing.T) {
	db := newMigrationTestPool(t)
	ctx := context.Background()
	if err := Run(ctx, db); err != nil {
		t.Fatal("initial migrations:", err)
	}

	categoryID, channelID := uuid.NewString(), uuid.NewString()
	if _, err := db.Exec(ctx, `INSERT INTO categories(id,name,position) VALUES($1,'AFK test',0)`, categoryID); err != nil {
		t.Fatal("insert category:", err)
	}
	if _, err := db.Exec(ctx, `INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'AFK','VOICE',0)`, channelID, categoryID); err != nil {
		t.Fatal("insert AFK channel:", err)
	}
	if _, err := db.Exec(ctx, `UPDATE guild_settings SET afk_channel_id=$1,afk_timeout_seconds=300 WHERE singleton=TRUE`, channelID); err != nil {
		t.Fatal("configure AFK destination:", err)
	}
	if err := Run(ctx, db); err != nil {
		t.Fatal("repeat migrations:", err)
	}

	var gotChannel string
	var gotTimeout int
	if err := db.QueryRow(ctx, `SELECT afk_channel_id::text,afk_timeout_seconds FROM guild_settings WHERE singleton=TRUE`).Scan(&gotChannel, &gotTimeout); err != nil {
		t.Fatal("read AFK settings after repeated migrations:", err)
	}
	if gotChannel != channelID || gotTimeout != 300 {
		t.Fatalf("AFK settings after repeated migrations = (%q,%d), want (%q,300)", gotChannel, gotTimeout, channelID)
	}
}
