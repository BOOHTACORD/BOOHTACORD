import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceUserFooter extends WorkspaceUserFooterContext
    with WorkspaceUserFooterBuildBinding {
  const WorkspaceUserFooter({
    super.key,
    required super.state,
    super.onNavigate,
    super.compact,
  });
}
