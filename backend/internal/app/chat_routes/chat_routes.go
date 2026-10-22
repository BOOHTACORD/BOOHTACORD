package chatroutes

import (
	"net/http"
	messageevents "voice-platform/backend/internal/chat/create_text_message/realtime"
	support "voice-platform/backend/internal/support/contact"

	"github.com/jackc/pgx/v5/pgxpool"
	advancedirectmessagereadcursor "voice-platform/backend/internal/chat/advance_direct_message_read_cursor"
	advancedirectmessagereadcursorapi "voice-platform/backend/internal/chat/advance_direct_message_read_cursor/api"
	advancedirectmessagereadcursorpostgres "voice-platform/backend/internal/chat/advance_direct_message_read_cursor/postgres"
	createtextmessage "voice-platform/backend/internal/chat/create_text_message"
	messageapi "voice-platform/backend/internal/chat/create_text_message/api"
	messagepostgres "voice-platform/backend/internal/chat/create_text_message/postgres"
	deletedirectmessage "voice-platform/backend/internal/chat/delete_direct_message"
	deletedirectmessageapi "voice-platform/backend/internal/chat/delete_direct_message/api"
	deletedirectmessagepostgres "voice-platform/backend/internal/chat/delete_direct_message/postgres"
	deletedirectmessagerealtime "voice-platform/backend/internal/chat/delete_direct_message/realtime"
	deletetextmessage "voice-platform/backend/internal/chat/delete_text_message"
	deletehandler "voice-platform/backend/internal/chat/delete_text_message/api"
	deletepostgres "voice-platform/backend/internal/chat/delete_text_message/postgres"
	deletetextmessagerealtime "voice-platform/backend/internal/chat/delete_text_message/realtime"
	editdirectmessage "voice-platform/backend/internal/chat/edit_direct_message"
	editdirectmessageapi "voice-platform/backend/internal/chat/edit_direct_message/api"
	editdirectmessagepostgres "voice-platform/backend/internal/chat/edit_direct_message/postgres"
	editdirectmessagerealtime "voice-platform/backend/internal/chat/edit_direct_message/realtime"
	edittextmessage "voice-platform/backend/internal/chat/edit_text_message"
	edithandler "voice-platform/backend/internal/chat/edit_text_message/api"
	editpostgres "voice-platform/backend/internal/chat/edit_text_message/postgres"
	edittextmessagerealtime "voice-platform/backend/internal/chat/edit_text_message/realtime"
	listdirectmessagecandidates "voice-platform/backend/internal/chat/list_direct_message_candidates"
	listdirectmessagecandidatesapi "voice-platform/backend/internal/chat/list_direct_message_candidates/api"
	listdirectmessagecandidatespostgres "voice-platform/backend/internal/chat/list_direct_message_candidates/postgres"
	listdirectmessagehistory "voice-platform/backend/internal/chat/list_direct_message_history"
	listdirectmessagehistoryapi "voice-platform/backend/internal/chat/list_direct_message_history/api"
	listdirectmessagehistorypostgres "voice-platform/backend/internal/chat/list_direct_message_history/postgres"
	listdirectmessages "voice-platform/backend/internal/chat/list_direct_messages"
	listdirectmessagesapi "voice-platform/backend/internal/chat/list_direct_messages/api"
	listdirectmessagespostgres "voice-platform/backend/internal/chat/list_direct_messages/postgres"
	listmymentions "voice-platform/backend/internal/chat/list_my_mentions"
	listmymentionsapi "voice-platform/backend/internal/chat/list_my_mentions/api"
	listmymentionspostgres "voice-platform/backend/internal/chat/list_my_mentions/postgres"
	listtextmessages "voice-platform/backend/internal/chat/list_text_messages"
	listhandler "voice-platform/backend/internal/chat/list_text_messages/api"
	listpostgres "voice-platform/backend/internal/chat/list_text_messages/postgres"
	opendirectmessage "voice-platform/backend/internal/chat/open_direct_message"
	directmessageapi "voice-platform/backend/internal/chat/open_direct_message/api"
	directmessagepostgres "voice-platform/backend/internal/chat/open_direct_message/postgres"
	searchdirectmessagehistory "voice-platform/backend/internal/chat/search_direct_message_history"
	searchdirectmessagehistoryapi "voice-platform/backend/internal/chat/search_direct_message_history/api"
	searchdirectmessagehistorypostgres "voice-platform/backend/internal/chat/search_direct_message_history/postgres"
	searchmessages "voice-platform/backend/internal/chat/search_messages"
	searchmessagesapi "voice-platform/backend/internal/chat/search_messages/api"
	searchmessagespostgres "voice-platform/backend/internal/chat/search_messages/postgres"
	searchtextmessages "voice-platform/backend/internal/chat/search_text_messages"
	searchtextmessagesapi "voice-platform/backend/internal/chat/search_text_messages/api"
	searchtextmessagespostgres "voice-platform/backend/internal/chat/search_text_messages/postgres"
	senddirectmessage "voice-platform/backend/internal/chat/send_direct_message"
	senddirectmessageapi "voice-platform/backend/internal/chat/send_direct_message/api"
	senddirectmessagepostgres "voice-platform/backend/internal/chat/send_direct_message/postgres"
	senddirectmessagerealtime "voice-platform/backend/internal/chat/send_direct_message/realtime"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	resolvedirectmessagerecipientspostgres "voice-platform/backend/internal/realtime/resolve_direct_message_recipients/postgres"
)

func ConfigureChatRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, events *eventhub.Hub) {
	mux.Handle("POST /api/v1/support/consent", sessionapi.Require(sessions)(support.ConsentHandler(support.New(database))))
	configureDeliveryRoutes(mux, database, sessions)
	service := createtextmessage.New(messagepostgres.New(messagepostgres.NewPoolDatabase(database)))
	editService := edittextmessage.New(editpostgres.New(editpostgres.NewPoolDatabase(database)))
	deleteService := deletetextmessage.New(deletepostgres.New(deletepostgres.NewPoolDatabase(database)))
	listService := listtextmessages.New(listpostgres.New(listpostgres.NewPoolDatabase(database)))
	textMessageSearch := searchtextmessages.New(searchtextmessagespostgres.New(searchtextmessagespostgres.NewPoolDatabase(database)))
	directMessageService := opendirectmessage.New(directmessagepostgres.New(directmessagepostgres.NewPoolDatabase(database)))
	directMessageCandidates := listdirectmessagecandidates.New(listdirectmessagecandidatespostgres.New(listdirectmessagecandidatespostgres.NewPoolDatabase(database)))
	directMessages := listdirectmessages.New(listdirectmessagespostgres.New(listdirectmessagespostgres.NewPoolDatabase(database)))
	directMessageSender := senddirectmessage.New(senddirectmessagepostgres.New(senddirectmessagepostgres.NewPoolDatabase(database)))
	directMessageHistory := listdirectmessagehistory.New(listdirectmessagehistorypostgres.New(listdirectmessagehistorypostgres.NewPoolDatabase(database)))
	directMessageEditor := editdirectmessage.New(editdirectmessagepostgres.New(editdirectmessagepostgres.NewPoolDatabase(database)))
	directMessageDeleter := deletedirectmessage.New(deletedirectmessagepostgres.New(deletedirectmessagepostgres.NewPoolDatabase(database)))
	directMessageRecipients := resolvedirectmessagerecipientspostgres.New(resolvedirectmessagerecipientspostgres.NewPoolDatabase(database))
	directMessageReadCursor := advancedirectmessagereadcursor.New(advancedirectmessagereadcursorpostgres.New(advancedirectmessagereadcursorpostgres.NewPoolDatabase(database)))
	directMessageSearch := searchdirectmessagehistory.New(searchdirectmessagehistorypostgres.New(searchdirectmessagehistorypostgres.NewPoolDatabase(database)))
	messageSearch := searchmessages.New(searchmessagespostgres.New(searchmessagespostgres.NewPoolDatabase(database)))
	myMentions := listmymentions.New(listmymentionspostgres.New(listmymentionspostgres.NewPoolDatabase(database)))
	creator := messageevents.New(service, events)
	mux.Handle("POST /api/v1/channels/{channelID}/messages", sessionapi.Require(sessions)(messageapi.NewHandler(creator)))
	mux.Handle("GET /api/v1/channels/{channelID}/messages", sessionapi.Require(sessions)(listhandler.NewHandler(listService)))
	mux.Handle("GET /api/v1/channels/{channelID}/search", sessionapi.Require(sessions)(searchtextmessagesapi.NewHandler(textMessageSearch)))
	mux.Handle("PATCH /api/v1/channels/{channelID}/messages/{messageID}", sessionapi.Require(sessions)(edithandler.NewHandler(edittextmessagerealtime.New(editService, events))))
	mux.Handle("DELETE /api/v1/channels/{channelID}/messages/{messageID}", sessionapi.Require(sessions)(deletehandler.NewHandler(deletetextmessagerealtime.New(deleteService, events))))
	mux.Handle("POST /api/v1/direct-messages", sessionapi.Require(sessions)(directmessageapi.NewHandler(directMessageService)))
	mux.Handle("GET /api/v1/direct-message-candidates", sessionapi.Require(sessions)(listdirectmessagecandidatesapi.NewHandler(directMessageCandidates)))
	mux.Handle("GET /api/v1/direct-messages", sessionapi.Require(sessions)(listdirectmessagesapi.NewHandler(directMessages, support.New(database))))
	mux.Handle("POST /api/v1/direct-messages/{directMessageID}/messages", sessionapi.Require(sessions)(senddirectmessageapi.NewHandler(senddirectmessagerealtime.New(directMessageSender, directMessageRecipients, events))))
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/messages", sessionapi.Require(sessions)(listdirectmessagehistoryapi.NewHandler(directMessageHistory)))
	mux.Handle("GET /api/v1/direct-messages/{directMessageID}/search", sessionapi.Require(sessions)(searchdirectmessagehistoryapi.NewHandler(directMessageSearch)))
	mux.Handle("GET /api/v1/search/messages", sessionapi.Require(sessions)(searchmessagesapi.NewHandler(messageSearch)))
	mux.Handle("GET /api/v1/mentions", sessionapi.Require(sessions)(listmymentionsapi.NewHandler(myMentions)))
	mux.Handle("PATCH /api/v1/direct-messages/{directMessageID}/messages/{messageID}", sessionapi.Require(sessions)(editdirectmessageapi.NewHandler(editdirectmessagerealtime.New(directMessageEditor, directMessageRecipients, events))))
	mux.Handle("DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}", sessionapi.Require(sessions)(deletedirectmessageapi.NewHandler(deletedirectmessagerealtime.New(directMessageDeleter, directMessageRecipients, events))))
	mux.Handle("PUT /api/v1/direct-messages/{directMessageID}/read-cursor", sessionapi.Require(sessions)(advancedirectmessagereadcursorapi.NewHandler(directMessageReadCursor)))
}
