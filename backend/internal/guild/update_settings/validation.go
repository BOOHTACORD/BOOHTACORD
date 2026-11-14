package guildsettings

import (
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/google/uuid"
)

func Validate(input Input) (Input, error) {
	if input.ExpectedRevision < 1 || (!input.SetName && !input.SetWelcome && !input.SetAFK) {
		return Input{}, ErrInvalid
	}
	if input.SetName {
		// Reject controls before trimming; a trailing newline is invalid as well.
		if !utf8.ValidString(input.Name) {
			return Input{}, ErrInvalid
		}
		for _, r := range input.Name {
			if unicode.IsControl(r) || r == '\u2028' || r == '\u2029' {
				return Input{}, ErrInvalid
			}
		}
		input.Name = strings.TrimSpace(input.Name)
		if count := utf8.RuneCountInString(input.Name); count < 1 || count > 80 {
			return Input{}, ErrInvalid
		}
	}
	if input.SetWelcome && input.WelcomeChannelID != "" {
		id, err := uuid.Parse(input.WelcomeChannelID)
		if err != nil || id == uuid.Nil {
			return Input{}, ErrInvalid
		}
		input.WelcomeChannelID = id.String()
	}
	if input.SetAFK {
		if input.AFKChannelID == "" {
			if input.AFKTimeoutSeconds != 0 {
				return Input{}, ErrInvalid
			}
		} else {
			id, err := uuid.Parse(input.AFKChannelID)
			if err != nil || id == uuid.Nil || input.AFKTimeoutSeconds < 60 || input.AFKTimeoutSeconds > 86400 {
				return Input{}, ErrInvalid
			}
			input.AFKChannelID = id.String()
		}
	}
	return input, nil
}
