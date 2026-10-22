SELECT count(*),
       count(*) FILTER (WHERE created_at >= $1 AND created_at <= $3),
       count(*) FILTER (WHERE created_at >= $2 AND created_at < $1),
       (SELECT count(*) FROM user_daily_activity
        WHERE activity_day = ($1::timestamptz AT TIME ZONE 'Europe/Moscow')::date),
       (SELECT count(*) FROM user_daily_activity
        WHERE activity_day = ($2::timestamptz AT TIME ZONE 'Europe/Moscow')::date),
       (SELECT started_at FROM user_activity_collection WHERE singleton)
FROM users
WHERE NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=users.id)
