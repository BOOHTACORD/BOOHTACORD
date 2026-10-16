import '../native_bindings.dart';
import '../lifecycle/context.dart';
import '../lifecycle/widget.dart';

mixin AdminScreenStateDidUpdateWidgetBinding on AdminScreenStateContext {
  @override
  void didUpdateWidget(covariant AdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final section = widget.state.workspace.adminSection;
    if (section == adminSelectedAdminSection) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.state.workspace.adminSection == section &&
          adminSelectedAdminSection != section) {
        adminSelectSection(section);
      }
    });
  }
}
