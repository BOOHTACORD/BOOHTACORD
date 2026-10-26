package relayruntime

import (
	"errors"
	"net"
	"strconv"
)

var ErrConfiguration = errors.New("relay configuration invalid")

type Config struct {
	DatabaseURL, Address, MetricsAddress, Namespace, SecretFile, SigningFile, FCMFile, FCMProject string
	Enabled                                                                                       bool
	AndroidEnabled, IOSEnabled                                                                    bool
}

func Load(getenv func(string) string) (Config, error) {
	c := Config{DatabaseURL: getenv("RELAY_DATABASE_URL"), Address: getenv("RELAY_ADDRESS"), MetricsAddress: getenv("RELAY_METRICS_ADDRESS"), Namespace: getenv("RELAY_NAMESPACE"), SecretFile: getenv("RELAY_SECRET_KEY_FILE"), SigningFile: getenv("RELAY_SIGNING_KEY_FILE"), FCMFile: getenv("RELAY_FCM_SERVICE_ACCOUNT_FILE"), FCMProject: getenv("RELAY_FCM_PROJECT")}
	if c.Address == "" {
		c.Address = "127.0.0.1:8093"
	}
	if c.MetricsAddress == "" {
		c.MetricsAddress = "127.0.0.1:9097"
	}
	for name, target := range map[string]*bool{"RELAY_ANDROID_ENABLED": &c.AndroidEnabled, "RELAY_IOS_ENABLED": &c.IOSEnabled} {
		switch getenv(name) {
		case "", "false":
		case "true":
			*target = true
		default:
			return Config{}, ErrConfiguration
		}
	}
	switch getenv("RELAY_ENABLED") {
	case "", "false":
	case "true":
		c.Enabled = true
	default:
		return Config{}, ErrConfiguration
	}
	if c.DatabaseURL == "" || len(c.DatabaseURL) > 8192 || (c.Namespace != "staging" && c.Namespace != "production") {
		return Config{}, ErrConfiguration
	}
	for _, address := range []string{c.Address, c.MetricsAddress} {
		_, port, err := net.SplitHostPort(address)
		if err != nil {
			return Config{}, ErrConfiguration
		}
		value, err := strconv.Atoi(port)
		if err != nil || value < 1 || value > 65535 {
			return Config{}, ErrConfiguration
		}
	}
	return c, nil
}
