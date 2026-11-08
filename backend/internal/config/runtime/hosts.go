package runtimeconfig

import (
	"net/http"
	"strings"
)

func splitHosts(raw string) []string {
	var result []string
	for _, value := range strings.Split(raw, ",") {
		if host := strings.TrimSpace(value); host != "" {
			result = append(result, host)
		}
	}
	return result
}
func publicHost(raw string) []string {
	request, err := http.NewRequest(http.MethodGet, raw, nil)
	if err != nil || request.URL.Hostname() == "" {
		return nil
	}
	return []string{request.URL.Hostname()}
}
