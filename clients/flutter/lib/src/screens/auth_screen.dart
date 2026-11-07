import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../app_version.dart';
import '../app_state.dart';
import '../theme.dart';
import '../features/guild/profile/name.dart';
import '../services/password_generator.dart';
import '../features/authentication/password_generation/controls.dart';
import '../features/session/authentication/password_policy.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});
  final AppState state;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _loginFocus = FocusNode(debugLabel: 'auth-login');
  final _passwordFocus = FocusNode(debugLabel: 'auth-password');
  final _passwordResetButtonFocus = FocusNode(
    debugLabel: 'auth-password-reset-link-button',
  );
  final _serverAddressButtonFocus = FocusNode(
    debugLabel: 'auth-server-address-button',
  );
  bool _register = false;
  bool _pending = false;
  bool _showPassword = false;
  bool _confirmGeneration = false;
  String? _passwordStatus;
  bool _validationAttempted = false;
  late final bool _focusLogin;

  @override
  void initState() {
    super.initState();
    _focusLogin = widget.state.focusLoginOnMount;
    widget.state.focusLoginOnMount = false;
  }

  @override
  void dispose() {
    _password.clear();
    _login.dispose();
    _password.dispose();
    _loginFocus.dispose();
    _passwordFocus.dispose();
    _passwordResetButtonFocus.dispose();
    _serverAddressButtonFocus.dispose();
    super.dispose();
  }

  void _chooseMode(bool register) {
    if (_pending) return;
    if (_register != register) {
      _password.clear();
      _showPassword = false;
      _confirmGeneration = false;
      _passwordStatus = null;
    }
    setState(() => _register = register);
    widget.state.clearError();
  }

  void _requestPasswordGeneration() {
    if (_password.text.isNotEmpty) {
      setState(() => _confirmGeneration = true);
      return;
    }
    _generatePassword();
  }

  void _generatePassword() {
    String value;
    try {
      value = SecurePasswordGenerator().generate();
    } catch (_) {
      widget.state.reportError('Не удалось безопасно сгенерировать пароль. Попробуйте ещё раз или введите его вручную.');
      return;
    }
    setState(() {
      _password.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      _showPassword = true;
      _confirmGeneration = false;
      _passwordStatus = 'Надёжный пароль сгенерирован';
    });
    widget.state.clearError();
    if (_validationAttempted) _formKey.currentState?.validate();
    _passwordFocus.requestFocus();
  }

  Future<void> _submit() async {
    if (_pending) return;
    _validationAttempted = true;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      await widget.state.authenticate(
        _login.text,
        _password.text,
        register: _register,
      );
      if (!mounted) return;
      setState(() {
        _password.clear();
        _showPassword = false;
        _passwordStatus = null;
        _confirmGeneration = false;
        _pending = false;
      });
    } catch (_) {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _usePasswordResetLink() async {
    final link = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (_) => const _PasswordResetLinkDialog(),
    );
    if (!mounted || link == null) return;
    widget.state.openPasswordResetLink(link);
  }

  Future<void> _changeServer() async {
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (_) => _ServerAddressDialog(
        initialServerUrl: widget.state.serverUrl.replaceFirst(
          RegExp(r'/api/v1$'),
          '',
        ),
      ),
    );
    if (value == null || value.isEmpty) return;
    try {
      await widget.state.setServer(value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - 48)
          .clamp(0.0, 440.0)
          .toDouble();
      final cardPadding = (constraints.maxWidth * .06)
          .clamp(24.0, 40.0)
          .toDouble();
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  key: const ValueKey('auth-card'),
                  width: cardWidth,
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: GcColors.content,
                    border: Border.all(color: GcColors.border),
                    borderRadius: BorderRadius.circular(GcRadii.lg),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 70,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'На своём сервере · одна гильдия',
                            style: TextStyle(
                              color: GcColors.muted,
                              fontSize: constraints.maxWidth <= 720 ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              height:
                                  24 / (constraints.maxWidth <= 720 ? 16 : 18),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GuildName(
                            widget.state.guildProfile.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 32 / 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Голосовые каналы, демонстрация экрана и общий чат для своей компании.',
                            style: TextStyle(
                              color: GcColors.textSecondary,
                              fontSize: 14,
                              height: 20 / 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _AuthenticationModeTabs(
                            registerSelected: _register,
                            onSelected: _chooseMode,
                          ),
                          const SizedBox(height: 24),
                          _AuthFieldLabel('Логин'),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const ValueKey('auth-login-field'),
                            controller: _login,
                            focusNode: _loginFocus,
                            autofocus: _focusLogin,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.none,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            autofillHints: const [AutofillHints.username],
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            decoration: _authFieldDecoration(),
                            validator: (value) =>
                                value != null &&
                                    RegExp(r'^[A-Za-z0-9_.-]{3,32}$')
                                        .hasMatch(value)
                                ? null
                                : 'От 3 до 32 символов: A–Z, 0–9, _, . или -',
                          ),
                          const SizedBox(height: 16),
                          _AuthFieldLabel('Пароль'),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const ValueKey('auth-password-field'),
                            controller: _password,
                            focusNode: _passwordFocus,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            decoration: _authFieldDecoration().copyWith(
                              errorMaxLines: 3,
                              suffixIcon: IconButton(
                                tooltip: _showPassword ? 'Скрыть пароль' : 'Показать пароль',
                                onPressed: _pending ? null : () => setState(() => _showPassword = !_showPassword),
                                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              ),
                            ),
                            onFieldSubmitted: (_) => _submit(),
                            onChanged: (_) => setState(() {
                              _passwordStatus = null;
                              _confirmGeneration = false;
                            }),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) return 'Введите пароль.';
                              if (!_register) return null;
                              return newPasswordError(password);
                            },
                          ),
                          if (_register)
                            PasswordGenerationControls(
                              pending: _pending,
                              confirm: _confirmGeneration,
                              status: _passwordStatus,
                              onGenerate: _requestPasswordGeneration,
                              onReplace: _generatePassword,
                              onKeep: () => setState(() => _confirmGeneration = false),
                            ),
                          if (_register) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Логин: 3–32 символа A–Z, 0–9, `_`, `.`, `-`. Пароль — от 12 до 128 символов.',
                              style: TextStyle(
                                color: GcColors.muted,
                                fontSize: 12,
                                height: 16 / 12,
                              ),
                            ),
                          ],
                          if (widget.state.error != null) ...[
                            const SizedBox(height: 8),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                widget.state.error!,
                                style: const TextStyle(
                                  color: GcColors.danger,
                                  fontSize: 12,
                                  height: 16 / 12,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _pending ? null : _submit,
                              child: Text(
                                _pending
                                    ? 'Подождите…'
                                    : _register
                                    ? 'Создать аккаунт'
                                    : 'Войти',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            focusNode: _passwordResetButtonFocus,
                            onPressed: _pending ? null : _usePasswordResetLink,
                            icon: const Icon(Icons.password_outlined, size: 18),
                            label: const Text('Есть ссылка для сброса пароля?'),
                          ),
                          TextButton.icon(
                            focusNode: _serverAddressButtonFocus,
                            onPressed: _pending ? null : _changeServer,
                            icon: const Icon(Icons.dns_outlined, size: 18),
                            label: Text(
                              widget.state.serverUrl,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            appVersionLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GcColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PasswordResetLinkDialog extends StatefulWidget {
  const _PasswordResetLinkDialog();

  @override
  State<_PasswordResetLinkDialog> createState() =>
      _PasswordResetLinkDialogState();
}

class _PasswordResetLinkDialogState extends State<_PasswordResetLinkDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).pop(),
    },
    child: AlertDialog(
      backgroundColor: GcColors.surface,
      title: const Text('Ссылка для сброса пароля'),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          maxLength: 512,
          enableIMEPersonalizedLearning: false,
          decoration: const InputDecoration(
            labelText: 'Одноразовая ссылка администратора',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Продолжить'),
        ),
      ],
    ),
  );
}

class _ServerAddressDialog extends StatefulWidget {
  const _ServerAddressDialog({required this.initialServerUrl});

  final String initialServerUrl;

  @override
  State<_ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<_ServerAddressDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialServerUrl,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).pop(),
    },
    child: AlertDialog(
      backgroundColor: GcColors.surface,
      title: const Text('Сервер гильдии'),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'HTTPS-адрес',
            hintText: 'https://guild.example.com',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

class _AuthenticationModeTabs extends StatelessWidget {
  const _AuthenticationModeTabs({
    required this.registerSelected,
    required this.onSelected,
  });

  final bool registerSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('auth-mode-tablist-semantics'),
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.tabBar,
    label: 'Действие с аккаунтом',
    child: Container(
      key: const ValueKey('auth-mode-switcher'),
      padding: const EdgeInsets.all(GcSpacing.x1),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(GcRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthenticationModeTab(
              label: 'Войти',
              selected: !registerSelected,
              onPressed: () => onSelected(false),
            ),
          ),
          const SizedBox(width: GcSpacing.x1),
          Expanded(
            child: _AuthenticationModeTab(
              label: 'Регистрация',
              selected: registerSelected,
              onPressed: () => onSelected(true),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuthenticationModeTab extends StatelessWidget {
  const _AuthenticationModeTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('auth-mode-tab-$label'),
    button: true,
    selected: selected,
    role: SemanticsRole.tab,
    onTap: onPressed,
    child: SizedBox(
      height: GcLayout.authTabHeight,
      child: Material(
        color: selected ? GcColors.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(GcRadii.sm),
        child: InkWell(
          excludeFromSemantics: true,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(GcRadii.sm),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? GcColors.text : GcColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 20 / 14,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthFieldLabel extends StatelessWidget {
  const _AuthFieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Text(
      label,
      style: const TextStyle(
        color: GcColors.textSecondary,
        fontSize: 13,
        height: 18 / 13,
      ),
    ),
  );
}

InputDecoration _authFieldDecoration() => const InputDecoration(
  isDense: true,
  filled: true,
  fillColor: GcColors.surface,
  constraints: BoxConstraints(minHeight: GcLayout.controlLarge),
  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(GcRadii.md)),
    borderSide: BorderSide(color: GcColors.control),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(GcRadii.md)),
    borderSide: BorderSide(color: GcColors.control),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(GcRadii.md)),
    borderSide: BorderSide(color: GcColors.focus, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(GcRadii.md)),
    borderSide: BorderSide(color: GcColors.danger),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(GcRadii.md)),
    borderSide: BorderSide(color: GcColors.danger, width: 2),
  ),
);

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GcColors.border.withValues(alpha: .32)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
