import '../native_bindings.dart';
import '../members_panel/profile_overlay.dart';

class MemberProfileTrigger extends StatelessWidget {
  const MemberProfileTrigger({
    super.key,
    required this.state,
    required this.memberId,
    required this.name,
    required this.child,
  });
  final AppState state;
  final String? memberId;
  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final id = memberId;
    if (id == null ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(id) ||
        id == state.user?.accountId) {
      return child;
    }
    return Builder(
      builder: (anchorContext) => Semantics(
        button: true,
        label: 'Открыть профиль: $name',
        child: InkWell(
          key: ValueKey('member-profile-trigger:$id'),
          onTap: () => openMemberProfileOverlay(
            context: anchorContext,
            state: state,
            memberId: id,
            anchor: () {
              final box = anchorContext.findRenderObject();
              if (box is RenderBox && box.attached) {
                return box.localToGlobal(Offset.zero) & box.size;
              }
              return Rect.zero;
            },
            onContext: (_) {},
          ),
          child: child,
        ),
      ),
    );
  }
}
