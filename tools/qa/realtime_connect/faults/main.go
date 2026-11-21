package main

import (
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"time"
)

func main() {
	target, err := url.Parse(os.Getenv("R2_UPSTREAM"))
	token := os.Getenv("R2_CONTROL_TOKEN")
	if err != nil || target.Scheme != "http" || !strings.HasPrefix(target.Host, "qa-client-") || len(token) != 64 {
		panic("Owned R2 configuration required")
	}
	state := newState(token)
	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.Transport = faultTransport{state: state, base: http.DefaultTransport}
	proxy.ErrorLog = log.New(io.Discard, "", 0)
	proxy.ErrorHandler = func(w http.ResponseWriter, _ *http.Request, _ error) { http.Error(w, "Owned transport fault", 503) }
	mux := http.NewServeMux()
	mux.HandleFunc("/qa-r2/control", state.control)
	mux.Handle("/", proxy)
	server := &http.Server{Addr: ":8081", Handler: mux, ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 30 * time.Second}
	if server.ListenAndServe() != nil {
		os.Exit(1)
	}
}
