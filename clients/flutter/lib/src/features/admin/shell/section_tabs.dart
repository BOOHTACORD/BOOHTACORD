import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'tab_control/control.dart';
import 'types.dart';
export 'types.dart';

/// The admin tab strip owns tab semantics and responsive spacing while the
/// screen retains selection/loading state. This prevents feature panels from
/// having to know anything about the surrounding workspace chrome.
class AdminSectionTabs extends StatelessWidget {
  const AdminSectionTabs({
    super.key,
    required this.selectedSection,
    required this.onSelected,
    required this.compactLabel,
    required this.wideSpacing,
    required this.channelsSelected,
    required this.onRefreshChannels,
    required this.refreshDisabled,
  });

  final AdminSection selectedSection;
  final ValueChanged<AdminSection> onSelected;
  final bool compactLabel;
  final bool wideSpacing;
  final bool channelsSelected;
  final VoidCallback? onRefreshChannels;
  final bool refreshDisabled;

  Widget _tab(String label, AdminSection section) => AdminTabControl(
    label: label,
    section: section.name,
    selected: selectedSection == section,
    onSelected: () => onSelected(section),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('admin-section-tabs-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: Semantics(
                    key: const ValueKey('admin-section-tabs-semantics'),
                    container: true,
                    explicitChildNodes: true,
                    role: SemanticsRole.tabBar,
                    label: 'Разделы администрирования',
                    hint: compactLabel
                        ? 'Прокрутите список разделов по горизонтали.'
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tab('Гильдия', AdminSection.guild),
                        _tab('Участники', AdminSection.members),
                        if (wideSpacing) const SizedBox(width: 8),
                        _tab('Роли', AdminSection.roles),
                        if (wideSpacing) const SizedBox(width: 8),
                        _tab('Каналы', AdminSection.channels),
                        if (wideSpacing) const SizedBox(width: 8),
                        _tab('Аудит', AdminSection.audit),
                        if (wideSpacing) const SizedBox(width: 8),
                        _tab('Медиа', AdminSection.media),
                        if (wideSpacing) const SizedBox(width: 8),
                        _tab(
                          compactLabel ? 'Статус' : 'Готовность',
                          AdminSection.readiness,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (channelsSelected)
                IconButton(
                  tooltip: 'Обновить список каналов',
                  onPressed: refreshDisabled ? null : onRefreshChannels,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        ),
      ),
      if (compactLabel)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ExcludeSemantics(
            child: Text(
              'Прокрутите список разделов по горизонтали',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: GcColors.muted),
            ),
          ),
        ),
    ],
  );
}
