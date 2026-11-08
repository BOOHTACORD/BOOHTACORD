package main

import (
	"log"
	"net/http"
	"time"
	processor "voice-platform/backend/internal/voice/join_sound/processor"
)

func main() {
	server := &http.Server{Addr: ":8090", Handler: processor.NewWorker(processor.Processor{}), ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 5 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 15 * time.Second, MaxHeaderBytes: 4096}
	log.Fatal(server.ListenAndServe())
}
