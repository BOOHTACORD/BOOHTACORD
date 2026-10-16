// Disposable HTTPS and websocket signaling proxy for the native Windows gate.
// It binds loopback only and never handles RTP or application media payloads.
package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"flag"
	"math/big"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"time"
)

func certificate(work string) (string, string, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return "", "", err
	}
	root := &x509.Certificate{SerialNumber: big.NewInt(337), Subject: pkix.Name{CommonName: "Owned QA337 loopback root"},
		NotBefore: time.Now().Add(-time.Minute), NotAfter: time.Now().Add(4 * time.Hour),
		IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature}
	rootDER, err := x509.CreateCertificate(rand.Reader, root, root, &key.PublicKey, key)
	if err != nil {
		return "", "", err
	}
	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return "", "", err
	}
	leaf := &x509.Certificate{SerialNumber: big.NewInt(338), DNSNames: []string{"localhost"},
		IPAddresses: []net.IP{net.ParseIP("127.0.0.1")}, NotBefore: root.NotBefore, NotAfter: root.NotAfter,
		KeyUsage: x509.KeyUsageDigitalSignature, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
	leafDER, err := x509.CreateCertificate(rand.Reader, leaf, root, &leafKey.PublicKey, key)
	if err != nil {
		return "", "", err
	}
	private, err := x509.MarshalPKCS8PrivateKey(leafKey)
	if err != nil {
		return "", "", err
	}
	certFile, keyFile := filepath.Join(work, "leaf.crt"), filepath.Join(work, "leaf.key")
	for name, data := range map[string][]byte{
		filepath.Join(work, "owned-root.crt"): pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: rootDER}),
		certFile:                              pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: leafDER}),
		keyFile:                               pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: private}),
	} {
		if err := os.WriteFile(name, data, 0600); err != nil {
			return "", "", err
		}
	}
	return certFile, keyFile, nil
}

func proxy(port string, strip bool) http.Handler {
	target, _ := url.Parse("http://127.0.0.1:" + port)
	p := httputil.NewSingleHostReverseProxy(target)
	original := p.Director
	p.Director = func(r *http.Request) {
		original(r)
		r.Header.Set("X-Forwarded-Proto", "https")
		r.Header.Set("X-Forwarded-Host", "localhost:4910")
	}
	p.ErrorHandler = func(w http.ResponseWriter, _ *http.Request, _ error) {
		http.Error(w, "Owned dependency unavailable", 503)
	}
	if strip {
		return http.StripPrefix("/qa-sfu", p)
	}
	return p
}

func main() {
	work := flag.String("work", "", "fresh owned fixture directory")
	flag.Parse()
	if *work == "" {
		os.Exit(2)
	}
	cert, key, err := certificate(*work)
	if err != nil {
		os.Exit(1)
	}
	mux := http.NewServeMux()
	mux.Handle("/api/", proxy("4911", false))
	mux.Handle("/qa-sfu", proxy("4912", true))
	mux.Handle("/qa-sfu/", proxy("4912", true))
	server := &http.Server{Addr: "127.0.0.1:4910", Handler: mux, ReadHeaderTimeout: 10 * time.Second,
		TLSConfig: &tls.Config{MinVersion: tls.VersionTLS12}}
	if server.ListenAndServeTLS(cert, key) != nil {
		os.Exit(1)
	}
}
