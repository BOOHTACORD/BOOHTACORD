import '../native_bindings.dart';
import 'context.dart';
import '../handler_bindings.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.state,
    this.onToggleNavigation,
    this.onClose,
  });
  final AppState state;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onClose;
  @override
  State<AdminScreen> createState() => AdminScreenState();
}

class AdminScreenState extends AdminScreenStateContext
    with
        AdminScreenStateAdminBusyBinding,
        AdminScreenStateAdminStatusBinding,
        AdminScreenStateAdminErrorBinding,
        AdminScreenStateAdminVisibleAdminAccountsBinding,
        AdminScreenStateInitStateBinding,
        AdminScreenStateDidUpdateWidgetBinding,
        AdminScreenStateDisposeBinding,
        AdminScreenStateAdminOnTopologyMutationChangedBinding,
        AdminScreenStateDidChangeAppLifecycleStateBinding,
        AdminScreenStateAdminLoadMediaMetricsBinding,
        AdminScreenStateAdminCreateCategoryBinding,
        AdminScreenStateAdminLoadAuditBinding,
        AdminScreenStateAdminPickAuditDateBinding,
        AdminScreenStateAdminAuditFiltersBinding,
        AdminScreenStateAdminLoadAccountsBinding,
        AdminScreenStateAdminSaveAccountBinding,
        AdminScreenStateAdminCreateResetLinkBinding,
        AdminScreenStateAdminKickVoiceParticipantBinding,
        AdminScreenStateAdminCopyResetLinkBinding,
        AdminScreenStateAdminSelectSectionBinding,
        AdminScreenStateAdminCreateChannelBinding,
        AdminScreenStateAdminRenameCategoryBinding,
        AdminScreenStateAdminRenameChannelBinding,
        AdminScreenStateAdminSaveChannelDescriptionBinding,
        AdminScreenStateAdminDeleteCategoryBinding,
        AdminScreenStateAdminReorderCategoryBinding,
        AdminScreenStateAdminReorderChannelBinding,
        AdminScreenStateAdminMoveChannelBinding,
        AdminScreenStateAdminArchiveTextChannelBinding,
        AdminScreenStateAdminCloseVoiceAdmissionBinding,
        AdminScreenStateAdminAdminContentInsetBinding,
        AdminScreenStateAdminAdminSectionHeaderPaddingBinding,
        AdminScreenStateAdminAdminSectionListPaddingBinding,
        AdminScreenStateBuildBinding,
        AdminScreenStateAdminSectionBinding,
        AdminScreenStateAdminBuildMediaPanelBinding,
        AdminScreenStateAdminBuildAuditPanelBinding,
        AdminScreenStateAdminBuildMembersPanelBinding,
        AdminScreenStateAdminAdminLoadingStateBinding,
        AdminScreenStateAdminBuildAdminAccountCardBinding,
        AdminScreenStateAdminBuildAdminAccountDesktopRowBinding,
        AdminScreenStateAdminBuildAdminAccountCompactCardBinding,
        AdminScreenStateAdminBuildAccountConflictCardBinding,
        AdminScreenStateAdminDraftChangedBinding,
        AdminScreenStateAdminAccountSummaryBinding,
        AdminScreenStateAdminAdminAccessBadgeBinding,
        AdminScreenStateAdminAdminMemberAvatarColorBinding,
        AdminScreenStateAdminAdminMemberInitialsBinding,
        AdminScreenStateAdminBuildResetLinkCardBinding,
        AdminScreenStateAdminAuditDateBinding {}
