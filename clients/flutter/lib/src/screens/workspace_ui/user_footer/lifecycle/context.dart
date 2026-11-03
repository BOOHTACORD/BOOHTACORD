import '../../native_bindings.dart';

abstract class WorkspaceUserFooterContext extends StatelessWidget {
  const WorkspaceUserFooterContext({
    super.key,
    required this.state,
    this.onNavigate,
    this.compact = false,
  });
  final AppState state;
  final VoidCallback? onNavigate;
  final bool compact;
}
