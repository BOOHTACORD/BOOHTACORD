import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminSelectSectionBinding on AdminScreenStateContext {
  @override
  void adminSelectSection(AdminSection section) {
    executeAdminSelectSection(section);
  }
}

extension AdminScreenStateAdminSelectSectionBindingAction
    on AdminScreenStateContext {
  void executeAdminSelectSection(AdminSection section) {
    widget.state.workspace.adminSection = section;
    adminMutateView(() => adminSelectedAdminSection = section);
    adminMediaRefreshTimer?.cancel();
    adminMediaRefreshTimer = null;
    if (section == AdminSection.members && adminAccounts.isEmpty) {
      adminLoadAccounts();
    }
    if (section == AdminSection.audit && adminAuditEvents.isEmpty) {
      adminLoadAudit();
    }
    if (section == AdminSection.media) {
      unawaited(adminLoadMediaMetrics());
      adminMediaRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          unawaited(adminLoadMediaMetrics());
        }
      });
    }
  }
}
