package livekitcredential

import "testing"

func TestAFKCredentialCannotPublishMicrophone(t *testing.T) {
	signer, err := New(Config{URL: "wss://voice.example.test", APIKey: "key", APISecret: "secret"})
	if err != nil {
		t.Fatal(err)
	}
	credential, err := signer.IssueWithMicrophonePolicy("lease", "afk-channel", "account", "name", false)
	if err != nil {
		t.Fatal(err)
	}
	if credential.MicrophoneAllowed {
		t.Fatal("AFK credential reports microphone permission")
	}
	video := decodeClaims(t, credential.Token)["video"].(map[string]any)
	sources := video["canPublishSources"].([]any)
	if len(sources) != 2 || sources[0] != "screen_share" || sources[1] != "screen_share_audio" {
		t.Fatalf("AFK publish sources = %#v", sources)
	}
}
