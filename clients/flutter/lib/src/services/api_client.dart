import '../core/http/facade_base.dart';
import '../core/platform/session_storage.dart' as platform;
import '../features/session/authentication/facade.dart';
import '../features/session/password_reset/facade.dart';
import '../features/session/maintenance/facade.dart';
import '../features/session/own_sessions/facade.dart';
import '../features/guild/profile/facade.dart';
import '../features/admin/guild_settings/facade.dart';
import '../features/conversation/delivery/lookup_facade.dart';
import '../features/telemetry/export/facade.dart';
import '../features/media/report_metrics/facade.dart';
import '../features/screen/sender_metadata/facade.dart';
import '../features/profile/edit/facade.dart';
import '../features/profile/avatar/facade.dart';
import '../features/workspace/topology/facade.dart';
import '../features/voice/roster/facade.dart';
import '../features/admin/categories/facade.dart';
import '../features/admin/channels/facade.dart';
import '../features/admin/channel_order/facade.dart';
import '../features/admin/voice_admission/facade.dart';
import '../features/text/read_cursor/facade.dart';
import '../features/admin/audit/facade.dart';
import '../features/admin/media_metrics/facade.dart';
import '../features/admin/accounts/facade.dart';
import '../features/admin/password_reset/facade.dart';
import '../features/admin/voice_kick/facade.dart';
import '../features/admin/voice_timeout/facade.dart';
import '../features/text/history/facade.dart';
import '../features/workspace/members/facade.dart';
import '../features/direct/conversations/facade.dart';
import '../features/direct/history/facade.dart';
import '../features/search/messages/facade.dart';
import '../features/attachments/upload/facade.dart';
import '../features/attachments/download/facade.dart';
import '../features/direct/messages/facade.dart';
import '../features/direct/read_cursor/facade.dart';
import '../features/realtime/connect/facade.dart';
import '../features/text/messages/facade.dart';
import '../features/voice/leases/facade.dart';
import '../features/authorization/permissions/facade.dart';
import '../features/admin/role_permissions/facade.dart';
import '../features/admin/readiness/facade.dart';
import '../features/workspace/topology_mutations/facade.dart';

export '../core/http/api_failure.dart';
export '../features/admin/voice_admission/result.dart';

// Compatibility entrypoint: each capability owns its requests; all share one transport.
class ApiClient extends ApiFacadeBase
    with
        AuthSessionFacade,
        PasswordResetFacade,
        MaintenanceFacade,
        OwnSessionsFacade,
        GuildProfileFacade,
        GuildSettingsFacade,
        DeliveryLookupFacade,
        TelemetryExportFacade,
        ScreenMetricsReportFacade,
        ScreenProfileDescriptorFacade,
        OwnProfileFacade,
        AvatarFacade,
        TopologyFacade,
        VoiceRosterFacade,
        AdminCategoriesFacade,
        AdminChannelsFacade,
        AdminChannelOrderFacade,
        VoiceAdmissionFacade,
        TextReadCursorFacade,
        AdminAuditFacade,
        AdminMediaMetricsFacade,
        AdminAccountsFacade,
        AdminPasswordResetFacade,
        AdminVoiceKickFacade,
        AdminVoiceTimeoutFacade,
        TextHistoryFacade,
        MembersFacade,
        DirectConversationsFacade,
        DirectHistoryFacade,
        SearchMessagesFacade,
        AttachmentUploadFacade,
        AttachmentDownloadFacade,
        DirectMessagesFacade,
        DirectReadCursorFacade,
        RealtimeConnectFacade,
        TextMessagesFacade,
        VoiceLeasesFacade,
        PermissionsFacade,
        RolePermissionsFacade,
        AdminReadinessFacade,
        TopologyMutationsFacade {
  ApiClient({super.client});
  static const macOsSessionOptions = platform.macOsSessionOptions;
}
