package tracehttp

import "go.opentelemetry.io/otel/trace"

// These route templates and names are fixed. Never derive an event name from a raw URL.
var applicationActions = map[string]string{
	"PATCH /api/v1/admin/guild-settings":                                    "app.guild.name.updated",
	"POST /api/v1/auth/register":                                            "app.auth.registered",
	"POST /api/v1/auth/login":                                               "app.auth.signed_in",
	"POST /api/v1/auth/logout":                                              "app.auth.signed_out",
	"POST /api/v1/auth/password-reset/complete":                             "app.auth.password_reset",
	"POST /api/v1/admin/password-reset-links":                               "app.admin.password_reset_link.created",
	"PATCH /api/v1/admin/accounts/{accountID}":                              "app.admin.account.updated",
	"POST /api/v1/admin/accounts/{accountID}/voice-kick":                    "app.admin.voice.kicked",
	"POST /api/v1/admin/categories":                                         "app.category.created",
	"PUT /api/v1/admin/categories/order":                                    "app.category.reordered",
	"PATCH /api/v1/admin/categories/{categoryID}":                           "app.category.renamed",
	"DELETE /api/v1/admin/categories/{categoryID}":                          "app.category.deleted",
	"POST /api/v1/admin/categories/{categoryID}/channels":                   "app.channel.created",
	"PUT /api/v1/admin/categories/{categoryID}/channels/order":              "app.channel.reordered",
	"PATCH /api/v1/admin/channels/{channelID}":                              "app.channel.renamed",
	"PATCH /api/v1/admin/channels/{channelID}/category":                     "app.channel.moved",
	"DELETE /api/v1/admin/channels/{channelID}":                             "app.channel.archived",
	"POST /api/v1/admin/voice-channels/{channelID}/close-admission":         "app.voice.admission.closed",
	"POST /api/v1/channels/{channelID}/messages":                            "app.message.sent",
	"PATCH /api/v1/channels/{channelID}/messages/{messageID}":               "app.message.edited",
	"DELETE /api/v1/channels/{channelID}/messages/{messageID}":              "app.message.deleted",
	"POST /api/v1/direct-messages":                                          "app.dm.created",
	"POST /api/v1/direct-messages/{directMessageID}/messages":               "app.dm.message.sent",
	"PATCH /api/v1/direct-messages/{directMessageID}/messages/{messageID}":  "app.dm.message.edited",
	"DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}": "app.dm.message.deleted",
	"PUT /api/v1/direct-messages/{directMessageID}/read-cursor":             "app.dm.read_cursor.advanced",
	"PUT /api/v1/channels/{channelID}/read-cursor":                          "app.channel.read_cursor.advanced",
	"POST /api/v1/channels/{channelID}/attachments":                         "app.attachment.uploaded",
	"POST /api/v1/direct-messages/{directMessageID}/attachments":            "app.dm.attachment.uploaded",
	"PATCH /api/v1/me":                                                                        "app.profile.updated",
	"POST /api/v1/me/password":                                                                "app.profile.password_changed",
	"PUT /api/v1/me/avatar":                                                                   "app.profile.avatar.changed",
	"DELETE /api/v1/me/avatar":                                                                "app.profile.avatar.deleted",
	"POST /api/v1/voice/channels/{channelID}/leases":                                          "app.voice.lease.acquired",
	"DELETE /api/v1/voice/leases/{leaseID}":                                                   "app.voice.lease.released",
	"POST /api/v1/voice/leases/{leaseID}/credential":                                          "app.voice.credential.issued",
	"PUT /api/v1/channels/{channelID}/messages/{messageID}/reactions/{emoji}":                 "app.message.reaction.added",
	"DELETE /api/v1/channels/{channelID}/messages/{messageID}/reactions/{emoji}":              "app.message.reaction.removed",
	"PUT /api/v1/direct-messages/{directMessageID}/messages/{messageID}/reactions/{emoji}":    "app.dm.message.reaction.added",
	"DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}/reactions/{emoji}": "app.dm.message.reaction.removed",
	"PUT /api/v1/admin/text-channels/{channelID}/pins/{messageID}":                            "app.message.pinned",
	"DELETE /api/v1/admin/text-channels/{channelID}/pins/{messageID}":                         "app.message.unpinned",
	"GET /api/v1/search/messages":                                                             "app.message.search.completed",
	"GET /api/v1/channels/{channelID}/search":                                                 "app.channel.search.completed",
	"GET /api/v1/direct-messages/{directMessageID}/search":                                    "app.dm.search.completed",
	"GET /api/v1/archives/text-channels/{channelID}/search":                                   "app.archive.search.completed",
	"POST /api/v1/admin/text-channels/{channelID}/readonly-archive":                           "app.channel.readonly_archive.created",
	"POST /api/v1/admin/archives/text-channels/{channelID}/restore":                           "app.channel.readonly_archive.restored",
	"PUT /api/v1/admin/accounts/{accountID}/voice-timeout":                                    "app.admin.voice.timeout.applied",
	"DELETE /api/v1/admin/accounts/{accountID}/voice-timeout":                                 "app.admin.voice.timeout.removed",
}

func recordApplicationEvent(span trace.Span, route string, status int) {
	name, known := applicationActions[route]
	if !known {
		return
	}
	recordNamedEvent(span, name, status)
}

func recordNamedEvent(span trace.Span, name string, status int) {
	switch {
	case status >= 200 && status < 300:
		span.AddEvent(name)
	case status >= 400 && status < 500:
		span.AddEvent(name + ".rejected")
	case status >= 500:
		span.AddEvent(name + ".failed")
	}
}
