// support-contact is a local server-owner operation; it grants no DM access.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"
	"voice-platform/backend/internal/database/pool"
	contact "voice-platform/backend/internal/support/contact"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "Support contact operation failed; verify the command and active account.")
		os.Exit(1)
	}
}
func run(args []string) error {
	if len(args) == 0 {
		return contact.ErrInvalid
	}
	command := args[0]
	flags := flag.NewFlagSet("support-contact", flag.ContinueOnError)
	account := flags.String("account-id", "", "existing active local account UUID")
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}
	if flags.NArg() != 0 || (command != "status" && command != "set" && command != "clear") || (command == "set" && *account == "") || (command != "set" && *account != "") {
		return contact.ErrInvalid
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	database, err := pool.Open(ctx, os.Getenv("DATABASE_URL"))
	if err != nil {
		return contact.ErrUnavailable
	}
	defer database.Close()
	store := contact.New(database)
	if command == "status" {
		value, err := store.Resolve(ctx, "")
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(value)
	}
	revision, err := store.Assign(ctx, *account)
	if err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(map[string]any{"revision": revision, "configured": *account != "", "prior_conversations": "unchanged"})
}
