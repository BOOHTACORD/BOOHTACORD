import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.state});
  final AppState state;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _resultFocus = FocusNode();
  String? _validationError;
  bool _showPasswords = false;

  @override
  void initState() {
    super.initState();
    if (widget.state.resetUnusable) _focusResult();
  }

  void _focusResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resultFocus.requestFocus();
    });
  }

  Future<void> _submit() async {
    setState(() => _validationError = null);
    final password = _password.text;
    if (password.runes.length < 12 || password.runes.length > 128) {
      setState(
        () =>
            _validationError = 'Пароль должен содержать от 12 до 128 символов.',
      );
      return;
    }
    if (password != _confirmation.text) {
      setState(() => _validationError = 'Пароли не совпадают.');
      return;
    }
    final completed = await widget.state.completePasswordReset(password);
    if (!mounted) return;
    if (completed || widget.state.resetUnusable) {
      _password.clear();
      _confirmation.clear();
      _focusResult();
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final terminal = state.resetCompleted || state.resetUnusable;
    final message = state.resetCompleted
        ? 'Пароль изменён. Войдите в аккаунт с новым паролем.'
        : state.resetError ??
              'Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: GcColors.sidebar,
                border: Border.all(color: GcColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Безопасность аккаунта',
                    style: TextStyle(
                      color: GcColors.accentText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Новый пароль',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  if (terminal)
                    Focus(
                      focusNode: _resultFocus,
                      child: Semantics(
                        liveRegion: true,
                        label: message,
                        child: Text(
                          message,
                          style: TextStyle(
                            color: state.resetCompleted
                                ? GcColors.textSecondary
                                : GcColors.danger,
                            height: 1.45,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _password,
                      enabled: !state.resetPending,
                      obscureText: !_showPasswords,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Новый пароль',
                        suffixIcon: IconButton(
                          tooltip: _showPasswords
                              ? 'Скрыть пароли'
                              : 'Показать пароли',
                          onPressed: state.resetPending
                              ? null
                              : () => setState(
                                  () => _showPasswords = !_showPasswords,
                                ),
                          icon: Icon(
                            _showPasswords
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmation,
                      enabled: !state.resetPending,
                      obscureText: !_showPasswords,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Повторите пароль',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'От 12 до 128 символов.',
                      style: TextStyle(color: GcColors.textSecondary),
                    ),
                    if (_validationError != null ||
                        state.resetError != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _validationError ?? state.resetError!,
                          style: const TextStyle(color: GcColors.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: state.resetPending ? null : _submit,
                      child: Text(
                        state.resetPending
                            ? 'Меняем пароль…'
                            : 'Изменить пароль',
                      ),
                    ),
                  ],
                  if (terminal) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: state.returnToLogin,
                      child: const Text('Перейти ко входу'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
