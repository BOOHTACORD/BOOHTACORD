package supportcontact

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type Consenter interface {
	Accept(context.Context, string, int) error
}

func (s Store) Accept(ctx context.Context, actor string, version int) error {
	var accepted bool
	err := s.database.QueryRow(ctx, `WITH accepted AS (
 INSERT INTO support_public_consents(user_id,notice_version)
 SELECT $1::uuid,$2 FROM support_product_identity p CROSS JOIN support_contact_configuration c
 JOIN users u ON u.id=$1::uuid AND u.blocked_at IS NULL
 WHERE p.notice_version=$2 AND c.mode='product' AND c.support_account_id=p.account_id AND u.id<>p.account_id
 ON CONFLICT(user_id) DO UPDATE SET notice_version=excluded.notice_version,accepted_at=now() RETURNING user_id)
 SELECT EXISTS(SELECT 1 FROM accepted)`, actor, version).Scan(&accepted)
	if err != nil || !accepted {
		return ErrUnavailable
	}
	return nil
}
func ConsentHandler(service Consenter) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			w.WriteHeader(401)
			return
		}
		var body struct {
			Version int `json:"notice_version"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1024))
		decoder.DisallowUnknownFields()
		if decoder.Decode(&body) != nil || body.Version < 1 || body.Version > 1000000 || decoder.Decode(new(any)) != io.EOF {
			w.WriteHeader(400)
			return
		}
		if service.Accept(r.Context(), principal.AccountID, body.Version) != nil {
			w.WriteHeader(409)
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		w.WriteHeader(204)
	})
}
