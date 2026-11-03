import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../card_inline_state.dart';
import 'board_column_header.dart';
import 'card_composer.dart';

class AddCardSlot extends ConsumerWidget {
  const AddCardSlot({
    super.key,
    required this.columnId,
    required this.dense,
    this.prominent = false,
  });

  final String columnId;
  final bool dense;
  final bool prominent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(
      cardInlineProvider.select((state) => state.composerColumnId == columnId),
    );
    if (open) {
      return SizedBox(
        width: double.infinity,
        child: CardComposer(columnId: columnId, dense: dense),
      );
    }
    return AddCardButton(
      columnId: columnId,
      dense: dense,
      prominent: prominent,
      onPressed: () =>
          ref.read(cardInlineProvider.notifier).openComposer(columnId),
    );
  }
}
