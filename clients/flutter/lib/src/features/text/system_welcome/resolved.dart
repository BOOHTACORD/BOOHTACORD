import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../core/session/scope.dart';
import '../../../models.dart';
import 'row.dart';
import 'lookup.dart';

class ResolvedSystemWelcome extends StatefulWidget {
  const ResolvedSystemWelcome({
    super.key,
    required this.state,
    required this.message,
    this.onDelete,
  });
  final AppState state;
  final ChatMessage message;
  final VoidCallback? onDelete;
  @override
  State<ResolvedSystemWelcome> createState() => _ResolvedSystemWelcomeState();
}

class _ResolvedSystemWelcomeState extends State<ResolvedSystemWelcome> {
  String? _name, _requestedFor;
  SessionTicket? _ticket;
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_changed);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ResolvedSystemWelcome old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_changed);
      widget.state.addListener(_changed);
    }
    if (old.state != widget.state ||
        old.message.authorId != widget.message.authorId) {
      _name = null;
      _requestedFor = null;
      _ticket = null;
      _resolve();
    }
  }

  void _changed() {
    if (!mounted) return;
    _resolve();
    setState(() {});
  }

  void _resolve() {
    final state = widget.state;
    final user = state.user?.accountId;
    final author = widget.message.authorId;
    final key = '$user:$author';
    if (_ticket != null && !_ticket!.isCurrent) {
      _requestedFor = null;
      _name = null;
      _ticket = null;
    }
    if (_requestedFor != key) _name = null;
    if (user == null ||
        author.isEmpty ||
        widget.message.deleted ||
        state.members.any((member) => member.id == author) ||
        _requestedFor == key) {
      return;
    }
    _requestedFor = key;
    final ticket = state.session.scope.capture();
    _ticket = ticket;
    if (!ticket.isActive) {
      _requestedFor = null;
      _ticket = null;
      return;
    }
    () async {
      try {
        final member = await loadWelcomeAuthor(
          state.session.scope,
          state.api,
          author,
        );
        if (!mounted ||
            !ticket.isActive ||
            widget.state != state ||
            widget.state.user?.accountId != user ||
            widget.message.authorId != author ||
            member.id != author) {
          return;
        }
        setState(() => _name = member.displayName);
      } catch (_) {
        /* An unavailable profile keeps the fallback. */
      }
    }();
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.state.members
        .where((m) => m.id == widget.message.authorId)
        .firstOrNull;
    return SystemWelcomeMessage(
      message: widget.message,
      displayName: member?.displayName ?? _name ?? 'Участник',
      onDelete: widget.onDelete,
    );
  }
}
