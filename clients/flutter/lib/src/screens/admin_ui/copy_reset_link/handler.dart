import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminCopyResetLinkBinding on AdminScreenStateContext {
  @override
  Future<void> adminCopyResetLink() => executeAdminCopyResetLink();
}

extension AdminScreenStateAdminCopyResetLinkBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminCopyResetLink() async {
    final link = adminResetLink;
    if (link == null || !mounted) return;
    adminMutateView(() {
      adminAccountsStatus = null;
      adminAccountsError = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: link.url));
      if (mounted) {
        adminMutateView(() => adminAccountsStatus = 'Ссылка скопирована.');
      }
    } catch (cause) {
      if (mounted) adminMutateView(() => adminAccountsError = cause.toString());
    }
  }
}
