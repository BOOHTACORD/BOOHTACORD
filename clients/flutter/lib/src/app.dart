import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/workspace_screen.dart';
import 'theme.dart';
import 'features/session/startup/widgets.dart';
import 'features/session/maintenance/banner.dart';
import 'features/session/maintenance/unknown_banner.dart';
import 'features/updates/banner.dart';
import 'features/updates/controller.dart';
import 'features/updates/scope.dart';
import 'features/updates/required_guard.dart';
import 'widgets/desktop_window_chrome.dart';

class BoohtacordApp extends StatelessWidget {
  BoohtacordApp({super.key, required this.state, UpdateController? updates})
    : updates = updates ?? UpdateController.disabled();
  final AppState state;
  final UpdateController updates;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => UpdateScope(
      controller: updates,
      child: MaterialApp(
        title: 'BOOHTACORD',
        debugShowCheckedModeBanner: false,
        theme: guildTheme(),
        home: DesktopWindowChrome(
          title: 'BOOHTACORD',
          child: AnimatedBuilder(
            animation: Listenable.merge([state, updates]),
            builder: (context, _) {
              final unknown =
                  !state.maintenanceKnown && state.phase != AppPhase.loading;
              final bannerVisible = unknown || state.maintenanceActive;
              final appBusy =
                  {
                    VoicePhase.joining,
                    VoicePhase.connected,
                    VoicePhase.listener,
                    VoicePhase.reconnecting,
                    VoicePhase.leaving,
                  }.contains(state.voicePhase) ||
                  {
                    ScreenSharePhase.starting,
                    ScreenSharePhase.sharing,
                    ScreenSharePhase.stopping,
                  }.contains(state.screenSharePhase);
              final content = Column(
                children: [
                  if (unknown)
                    const MaintenanceUnknownBanner()
                  else if (state.maintenanceActive)
                    const MaintenanceBanner(),
                  ClientUpdateBanner(updates: updates, appBusy: appBusy),
                  Expanded(
                    child: switch (state.phase) {
                      AppPhase.loading => const LoadingScreen(),
                      AppPhase.connectionError => ConnectionErrorScreen(
                        error: state.error,
                        onRetry: state.initialize,
                      ),
                      AppPhase.signedOut =>
                        state.resetRoute
                            ? PasswordResetScreen(state: state)
                            : AuthScreen(state: state),
                      AppPhase.ready => WorkspaceScreen(
                        state: state,
                        maintenanceBannerVisible: bannerVisible,
                        openNavigationInitially: true,
                      ),
                    },
                  ),
                ],
              );

              final body = bannerVisible
                  ? SafeArea(top: true, bottom: false, child: content)
                  : content;
              return RequiredUpdateGuard(
                updates: updates,
                appBusy: appBusy,
                child: body,
              );
            },
          ),
        ),
      ),
    ),
  );
}
