import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateInitStateBinding on AdminScreenStateContext {
  @override
  void initState() {
    super.initState();
    executeAdminInitState();
  }
}

extension AdminScreenStateInitStateBindingAction on AdminScreenStateContext {
  void executeAdminInitState() {
    adminSelectedAdminSection = widget.state.workspace.adminSection;
    adminTopologyMutations = AdminTopologyMutationController(
      api: widget.state.api,
      topologyProvider: () => widget.state.topology,
      refreshTopology: widget.state.refreshTopology,
      confirm: (confirmation) {
        final accountId = widget.state.session.user?.accountId;
        return showConfirmationDialog<bool>(
          context: context,
          cancelOn: widget.state,
          shouldCancel: () =>
              widget.state.session.user?.accountId != accountId ||
              !(confirmation.stillCurrent?.call() ?? true),
          builder: (dialogContext) => AlertDialog(
            title: Text(confirmation.title),
            content: Text(confirmation.content),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmation.confirmLabel),
              ),
            ],
          ),
        );
      },
    )..addListener(adminOnTopologyMutationChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        adminTitleFocus.requestFocus();
        adminLoadAccounts();
        if (adminSelectedAdminSection != AdminSection.members) {
          adminSelectSection(adminSelectedAdminSection);
        }
      }
    });
  }
}
