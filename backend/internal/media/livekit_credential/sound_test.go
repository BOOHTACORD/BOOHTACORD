package livekitcredential

import "testing"

func TestJoinSoundIsMetadataOnlyAndCannotChangeAccountIdentity(t *testing.T) {
	signer, _ := New(Config{URL: "wss://voice.example.test", APIKey: "key", APISecret: "secret"})
	credential, err := signer.IssueWithSound("lease", "channel", "account", "name", "11111111-1111-4111-8111-111111111111", "2")
	if err != nil {
		t.Fatal(err)
	}
	claims := decodeClaims(t, credential.Token)
	attrs := claims["attributes"].(map[string]any)
	if claims["metadata"] != "account:account" || attrs["boohtacord.join_sound_id"] != "11111111-1111-4111-8111-111111111111" || attrs["boohtacord.join_sound_revision"] != "2" {
		t.Fatal("sound or account metadata differs")
	}
	video := claims["video"].(map[string]any)
	if video["canUpdateOwnMetadata"] == true {
		t.Fatal("client may spoof sound metadata")
	}
}
