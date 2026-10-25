package runtimeconfig

type NotificationOptions struct {
	WebEnabled          bool
	SecretKeyFile       string
	SigningKeyFile      string
	VAPIDPublicKey      string
	VAPIDPrivateKeyFile string
	VAPIDContact        string
	Namespace           string
	RelayOrigin         string
	RelayPublicKey      string
	WebPushHosts        []string
}

func notificationOptions(getenv func(string) string) NotificationOptions {
	namespace := getenv("NOTIFICATION_NAMESPACE")
	if namespace == "" {
		namespace = "production"
	}
	hosts := splitHosts(getenv("NOTIFICATION_WEB_PUSH_HOSTS"))
	if len(hosts) == 0 {
		hosts = []string{"fcm.googleapis.com", "updates.push.services.mozilla.com", "web.push.apple.com"}
	}
	return NotificationOptions{WebEnabled: getenv("NOTIFICATION_WEB_ENABLED") == "true", SecretKeyFile: getenv("NOTIFICATION_SECRET_KEY_FILE"), SigningKeyFile: getenv("NOTIFICATION_SIGNING_KEY_FILE"), VAPIDPublicKey: getenv("NOTIFICATION_VAPID_PUBLIC_KEY"), VAPIDPrivateKeyFile: getenv("NOTIFICATION_VAPID_PRIVATE_KEY_FILE"), VAPIDContact: getenv("NOTIFICATION_VAPID_CONTACT"), Namespace: namespace, RelayOrigin: getenv("NOTIFICATION_RELAY_ORIGIN"), RelayPublicKey: getenv("NOTIFICATION_RELAY_PUBLIC_KEY"), WebPushHosts: hosts}
}
