import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';
import '../heading/presentation.dart';

extension AdminMembersLayout on AdminMembersPanel {
  List<Widget> get _items => [
    ?resetCard,
    if (!accountsEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                'Показано: $resultsCount из $accountsCount загруженных',
              ),
            ),
            if (filtersActive)
              TextButton(
                onPressed: onResetFilters,
                child: const Text('Сбросить фильтры'),
              ),
          ],
        ),
      ),
    ...conflictCards,
    if (!accountsEmpty && accountCards.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('По текущим фильтрам участников нет.'),
      ),
    ...accountCards,
    if (loading)
      Semantics(
        liveRegion: true,
        label: 'Обновляем список участников…',
        child: Center(child: CircularProgressIndicator()),
      ),
    if (cursor != null)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: loading ? null : onLoadMore,
          child: const Text('Загрузить ещё'),
        ),
      ),
    if (status != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(status!, style: const TextStyle(color: GcColors.success)),
        ),
      ),
    if (error != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(error!, style: const TextStyle(color: GcColors.danger)),
        ),
      ),
  ];

  Widget renderMembers(BuildContext context) {
    final key = PageStorageKey(
      'admin-member-list:$search:$roleFilter:$statusFilter',
    );
    if (MediaQuery.textScalerOf(context).scale(14) > 21 ||
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      return ListView(
        // This scroll view owns the editor as well as the results. Changing
        // its key for each query disposes the focused input and its IME.
        key: const PageStorageKey('admin-member-form'),
        padding: listPadding.copyWith(top: 0),
        children: [
          renderMembersHeading(context),
          filters,
          if (loading && accountsEmpty)
            Semantics(
              liveRegion: true,
              child: Text('Загружаем список участников…'),
            )
          else if (accountsEmpty && error == null)
            const Text('Участников пока нет.')
          else
            ..._items,
        ],
      );
    }
    return Column(
      children: [
        renderMembersHeading(context),
        filters,
        if (loading && accountsEmpty)
          loadingState
        else if (!loading && accountsEmpty && error == null)
          const Expanded(child: Center(child: Text('Участников пока нет.')))
        else
          Expanded(
            child: ListView(key: key, padding: listPadding, children: _items),
          ),
      ],
    );
  }
}
