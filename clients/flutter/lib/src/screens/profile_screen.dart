import 'dart:ui' show SemanticsRole;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../features/admin/confirmation/dialog.dart';
import '../features/session/own_sessions/panel.dart';
import '../features/updates/status_card.dart';
import '../models.dart';
import '../services/native_notifications.dart';
import '../theme.dart';
import '../widgets/authenticated_avatar.dart';
import 'workspace_ui/profile_panel_toolbar/component.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.state,
    this.onBack,
    this.onClose,
    this.onToggleNavigation,
  });
  final AppState state;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final VoidCallback? onToggleNavigation;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _titleFocus = FocusNode(debugLabel: 'profile-screen-title');
  final _displayName = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _leaving = false;
  String? _status;
  String? _profileSaveStatus;
  late ProfileSection _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.state.workspace.profileSection;
    _displayName.text = widget.state.profile?.displayName ?? '';
    _displayName.addListener(_onDisplayNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  void _onDisplayNameChanged() {
    if (!mounted) return;
    setState(() {
      _profileSaveStatus = null;
      if (_status == 'Имя профиля сохранено.') _status = null;
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedSection = widget.state.workspace.profileSection;
    final value = widget.state.profile?.displayName ?? '';
    if (!_displayName.selection.isValid && _displayName.text != value) {
      _displayName.text = value;
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _displayName.removeListener(_onDisplayNameChanged);
    _displayName.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() {
      _status = null;
      _profileSaveStatus = 'Сохраняем имя профиля…';
    });
    if (await widget.state.saveDisplayName(_displayName.text)) {
      setState(() => _profileSaveStatus = 'Имя профиля сохранено.');
    } else {
      setState(() => _profileSaveStatus = null);
    }
  }

  bool get _displayNameChanged =>
      _displayName.text != (widget.state.profile?.displayName ?? '');

  String get _displayNameSaveMessage => widget.state.profileSaving
      ? 'Сохраняем имя профиля…'
      : _displayNameChanged
      ? 'Есть несохранённые изменения'
      : _profileSaveStatus ?? 'Изменения не внесены';

  Future<void> _savePassword() async {
    setState(() => _status = null);
    if (await widget.state.updatePassword(
      _currentPassword.text,
      _newPassword.text,
    )) {
      _currentPassword.clear();
      _newPassword.clear();
      setState(() => _status = 'Пароль изменён. Другие сессии завершены.');
    }
  }

  bool get _hasUnsavedSecurityChanges {
    final savedName = widget.state.profile?.displayName ?? '';
    return _displayName.text != savedName ||
        _currentPassword.text.isNotEmpty ||
        _newPassword.text.isNotEmpty;
  }

  Future<bool> _confirmLeavingUnsavedChanges(String accountId) async {
    final confirmed = await showConfirmationDialog<bool>(
      context: context,
      cancelOn: widget.state,
      shouldCancel: () => widget.state.profile?.accountId != accountId,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text(
          'Введённое имя или пароль ещё не сохранены. '
          'Если уйти, эти данные будут потеряны. Продолжить?',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GcColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выйти без сохранения'),
          ),
        ],
      ),
    );
    return confirmed == true && widget.state.profile?.accountId == accountId;
  }

  Future<bool> _confirmLogout(String accountId) async {
    final confirmed = await showConfirmationDialog<bool>(
      context: context,
      cancelOn: widget.state,
      shouldCancel: () => widget.state.profile?.accountId != accountId,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Подтвердите выход из аккаунта'),
        content: const Text(
          'Голосовое подключение завершится, а личные данные исчезнут '
          'с этого экрана. Выйти из аккаунта?',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GcColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    return confirmed == true && widget.state.profile?.accountId == accountId;
  }

  Future<void> _requestLeave(VoidCallback leave) async {
    if (_leaving || widget.state.profileSaving) return;
    final accountId = widget.state.profile?.accountId;
    if (accountId == null) return;
    _leaving = true;
    try {
      if (_hasUnsavedSecurityChanges &&
          !await _confirmLeavingUnsavedChanges(accountId)) {
        return;
      }
      if (!mounted || widget.state.profile?.accountId != accountId) return;
      leave();
    } finally {
      _leaving = false;
    }
  }

  Future<void> _requestLogout() async {
    final accountId = widget.state.profile?.accountId;
    if (accountId == null) return;
    if (_hasUnsavedSecurityChanges &&
        !await _confirmLeavingUnsavedChanges(accountId)) {
      return;
    }
    if (!mounted || widget.state.profile?.accountId != accountId) return;
    final confirmed = await _confirmLogout(accountId);
    if (!confirmed ||
        !mounted ||
        widget.state.profile?.accountId != accountId) {
      return;
    }
    await widget.state.logout();
  }

  Future<void> _selectAvatar() async {
    setState(() => _status = null);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'Изображения',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 2 * 1024 * 1024) {
        widget.state.reportError('Изображение должно быть не больше 2 МиБ.');
        return;
      }
      final bytes = await file.readAsBytes();
      final isPng =
          bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
      final isJpeg =
          bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      if (!isPng && !isJpeg) {
        widget.state.reportError('Выберите изображение PNG или JPEG.');
        return;
      }
      if (await widget.state.uploadAvatar(
        bytes,
        isPng ? 'image/png' : 'image/jpeg',
      )) {
        if (mounted) setState(() => _status = 'Аватар обновлён.');
      }
    } catch (_) {
      if (mounted) {
        widget.state.reportError('Не удалось прочитать изображение.');
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _status = null);
    if (await widget.state.deleteAvatar()) {
      if (mounted) setState(() => _status = 'Аватар удалён.');
    }
  }

  void _selectSection(ProfileSection section) {
    if (_selectedSection == section) return;
    setState(() {
      _selectedSection = section;
      widget.state.workspace.profileSection = section;
      _status = null;
    });
    widget.state.workspace.changed();
  }

  Widget _sectionTab(String label, ProfileSection section) {
    final selected = _selectedSection == section;
    return Semantics(
      key: ValueKey('profile-tab-${section.name}'),
      label: label,
      button: true,
      selected: selected,
      role: SemanticsRole.tab,
      onTap: () => _selectSection(section),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => _selectSection(section),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? GcColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? GcColors.text : GcColors.textSecondary,
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTabs() => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
    ),
    child: SingleChildScrollView(
      key: const ValueKey('profile-tabs-scroll'),
      scrollDirection: Axis.horizontal,
      child: Semantics(
        key: const ValueKey('profile-tabs-semantics'),
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.tabBar,
        label: 'Настройки аккаунта',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectionTab('Профиль', ProfileSection.profile),
            const SizedBox(width: 8),
            _sectionTab('Безопасность', ProfileSection.security),
            const SizedBox(width: 8),
            _sectionTab('Уведомления', ProfileSection.notifications),
            const SizedBox(width: 8),
            _sectionTab('О приложении', ProfileSection.about),
          ],
        ),
      ),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    key: const ValueKey('profile-settings-panel'),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.borderSubtle),
      borderRadius: BorderRadius.circular(GcRadii.lg),
    ),
    child: child,
  );

  Widget _feedback() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_status != null)
        Semantics(
          liveRegion: true,
          child: Text(
            _status!,
            style: const TextStyle(color: GcColors.success),
          ),
        ),
      if (widget.state.error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            widget.state.error!,
            style: const TextStyle(color: GcColors.danger),
          ),
        ),
      if (widget.state.logoutError != null)
        Semantics(
          liveRegion: true,
          child: Text(
            widget.state.logoutError!,
            style: const TextStyle(color: GcColors.danger),
          ),
        ),
    ],
  );

  Widget _profileSection(OwnProfile profile) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AuthenticatedAvatar(
              state: widget.state,
              name: profile.displayName,
              avatarUrl: profile.avatarUrl,
              radius: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${profile.login} · ${profile.role == 'ADMINISTRATOR' ? 'Администратор' : 'Участник'}',
                    style: const TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: widget.state.profileSaving
                            ? null
                            : _selectAvatar,
                        child: const Text('Изменить аватар'),
                      ),
                      if (profile.avatarUrl != null)
                        TextButton(
                          onPressed: widget.state.profileSaving
                              ? null
                              : _removeAvatar,
                          child: const Text('Удалить'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          key: const ValueKey('profile-name-form-width'),
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _displayName,
                decoration: const InputDecoration(
                  labelText: 'Отображаемое имя',
                  helperText: 'Так вас видят другие участники гильдии.',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: profile.login,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Логин',
                  helperText: 'Используется для входа.',
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed:
                          widget.state.profileSaving || !_displayNameChanged
                          ? null
                          : _saveName,
                      child: Text(
                        widget.state.profileSaving
                            ? 'Сохраняем…'
                            : 'Сохранить профиль',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _displayNameSaveMessage,
                      key: const ValueKey('profile-save-status'),
                      style: const TextStyle(color: GcColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _feedback(),
      ],
    ),
  );

  Widget _securitySection(OwnProfile profile) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Изменить пароль',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _currentPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Текущий пароль'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Новый пароль'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: widget.state.profileSaving ? null : _savePassword,
            child: const Text('Обновить пароль'),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(height: 1, color: GcColors.border),
        const SizedBox(height: 32),
        const Text(
          'Выход из аккаунта',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'Голосовое подключение завершится, а личные данные исчезнут с этого экрана.',
          style: TextStyle(color: GcColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: widget.state.logoutBusy || widget.state.profileSaving
                ? null
                : _requestLogout,
            child: Text(
              widget.state.logoutBusy ? 'Выходим…' : 'Выйти из аккаунта',
            ),
          ),
        ),
        const SizedBox(height: 24),
        OwnSessionsPanel(api: widget.state.api, accountId: profile.accountId),
        const SizedBox(height: 20),
        _feedback(),
      ],
    ),
  );

  Widget _notificationsSection() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Уведомления',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Показываем общий текст нового сообщения, пока приложение неактивно. Содержимое личных сообщений не отображается.',
          style: TextStyle(color: GcColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(switch (widget.state.notificationPermission) {
            NativeNotificationPermission.unavailable =>
              'Системные уведомления недоступны.',
            NativeNotificationPermission.denied =>
              'Уведомления запрещены в настройках системы.',
            NativeNotificationPermission.granted =>
              widget.state.notificationsEnabled
                  ? 'Уведомления включены.'
                  : 'Уведомления выключены.',
          }),
        ),
        if (widget.state.notificationError != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.state.notificationError!,
              style: const TextStyle(color: GcColors.danger),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed:
                widget.state.notificationPermission ==
                    NativeNotificationPermission.unavailable
                ? null
                : widget.state.notificationsEnabled
                ? widget.state.disableNotifications
                : widget.state.enableNotifications,
            child: Text(
              widget.state.notificationsEnabled
                  ? 'Отключить уведомления'
                  : 'Включить уведомления',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _aboutSection() => _panel(child: const ClientUpdateStatusCard());

  Widget _selectedContent(OwnProfile? profile) {
    if (widget.state.profileLoading) {
      return Semantics(
        liveRegion: true,
        child: const Text('Загружаем профиль…'),
      );
    }
    if (widget.state.profileLoadError != null) {
      return Semantics(
        liveRegion: true,
        child: Text(
          widget.state.profileLoadError!,
          style: const TextStyle(color: GcColors.danger),
        ),
      );
    }
    if (profile == null) return const SizedBox.shrink();
    return switch (_selectedSection) {
      ProfileSection.profile => _profileSection(profile),
      ProfileSection.security => _securitySection(profile),
      ProfileSection.notifications => _notificationsSection(),
      ProfileSection.about => _aboutSection(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile;
    final content = ColoredBox(
      color: GcColors.content,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 720;
          final inset = compact ? 16.0 : 24.0;
          final contentWidth = (constraints.maxWidth - inset * 2)
              .clamp(0.0, 720.0)
              .toDouble();
          return ListView(
            padding: EdgeInsets.all(inset),
            children: [
              Center(
                child: SizedBox(
                  key: const ValueKey('profile-settings-content'),
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Focus(
                        key: const ValueKey('profile-screen-title-focus'),
                        focusNode: _titleFocus,
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Настройки',
                            style: TextStyle(
                              fontSize: compact
                                  ? GcTypography.pageCompact
                                  : GcTypography.page,
                              height: compact
                                  ? GcTypography.pageCompactLine /
                                        GcTypography.pageCompact
                                  : GcTypography.pageLine / GcTypography.page,
                              fontWeight: GcTypography.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ваш профиль и параметры приложения.',
                        style: TextStyle(color: GcColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      _sectionTabs(),
                      const SizedBox(height: 24),
                      _selectedContent(profile),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    final onClose = widget.onClose;
    if (onClose == null) return content;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestLeave(widget.onBack ?? onClose);
      },
      child: Column(
        children: [
          WorkspaceProfilePanelToolbar(
            onToggleNavigation: widget.onToggleNavigation,
            onBack: widget.onBack == null
                ? null
                : () => _requestLeave(widget.onBack!),
            onClose: () => _requestLeave(onClose),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
