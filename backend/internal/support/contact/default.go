package supportcontact

import "context"

// UseProduct changes only the entry point; previous local conversations remain private.
func (s Store) UseProduct(ctx context.Context) (int64, error) {
	var revision int64
	err := s.database.QueryRow(ctx, `WITH configured AS (
 UPDATE support_contact_configuration SET mode='product',support_account_id=p.account_id,revision=revision+1,updated_at=now()
 FROM support_product_identity p WHERE support_contact_configuration.singleton=true RETURNING revision,support_account_id
 ),audited AS (
 INSERT INTO audit_events(event_type,target_user_id,metadata)
 SELECT 'SUPPORT_CONTACT_CHANGED',support_account_id,jsonb_build_object('revision',revision,'enabled',true,'mode','product')
 FROM configured RETURNING id)
 SELECT revision FROM configured WHERE EXISTS(SELECT 1 FROM audited)`).Scan(&revision)
	if err != nil {
		return 0, ErrUnavailable
	}
	return revision, nil
}
