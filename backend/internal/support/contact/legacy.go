package supportcontact

import (
	"context"
	"github.com/google/uuid"
)

// ProductPair does not grant access: only a participant can learn the publication boundary.
func (s Store) ProductPair(ctx context.Context, actor, pair string) (bool, error) {
	id, err := uuid.Parse(pair)
	if err != nil || id.String() != pair {
		return false, nil
	}
	var product bool
	err = s.database.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM direct_messages dm CROSS JOIN support_product_identity p
 WHERE dm.id=$1::uuid AND $2::uuid IN(dm.participant_one_id,dm.participant_two_id)
 AND p.account_id IN(dm.participant_one_id,dm.participant_two_id))`, pair, actor).Scan(&product)
	if err != nil {
		return false, ErrUnavailable
	}
	return product, nil
}
