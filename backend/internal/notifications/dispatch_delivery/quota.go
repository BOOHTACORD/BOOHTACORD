package dispatchdelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
)

func quota(ctx context.Context, tx pgx.Tx, sender, recipient, installation string, now time.Time) (bool, error) {
	_, err := tx.Exec(ctx, `DELETE FROM notification_dispatch_budgets WHERE (scope,subject)IN(SELECT scope,subject FROM notification_dispatch_budgets WHERE window_start<$1::timestamptz-interval '1 hour' LIMIT 16)`, now)
	if err != nil {
		return false, err
	}
	for _, q := range []struct {
		scope, id string
		limit     int
	}{{"sender", sender, 100}, {"recipient", recipient, 60}, {"installation", installation, 1000}} {
		var attempts int
		err = tx.QueryRow(ctx, `INSERT INTO notification_dispatch_budgets(scope,subject,window_start,attempts)
 SELECT $1,$2::uuid,date_trunc('minute',$3::timestamptz),1 WHERE EXISTS(SELECT 1 FROM notification_dispatch_budgets WHERE scope=$1 AND subject=$2::uuid) OR (SELECT count(*) FROM notification_dispatch_budgets)<10000
 ON CONFLICT(scope,subject)DO UPDATE SET window_start=GREATEST(notification_dispatch_budgets.window_start,EXCLUDED.window_start),
 attempts=CASE WHEN notification_dispatch_budgets.window_start>=EXCLUDED.window_start THEN LEAST(notification_dispatch_budgets.attempts+1,1001) ELSE 1 END RETURNING attempts`, q.scope, q.id, now).Scan(&attempts)
		if err == pgx.ErrNoRows {
			return false, nil
		}
		if err != nil {
			return false, err
		}
		if attempts > q.limit {
			return false, nil
		}
	}
	return true, nil
}
