import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../board_notifier.dart';
import '../board_providers.dart';

class CardTitleEditor extends ConsumerStatefulWidget {
  const CardTitleEditor({
    super.key,
    required this.cardId,
    required this.title,
    required this.editable,
    required this.style,
  });

  final String cardId;
  final String title;
  final bool editable;
  final TextStyle style;

  @override
  ConsumerState<CardTitleEditor> createState() => _CardTitleEditorState();
}

class _CardTitleEditorState extends ConsumerState<CardTitleEditor> {
  final FocusNode _focus = FocusNode();
  TextEditingController? _controller;
  late final BoardNotifier _board;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _board = ref.read(boardNotifierProvider.notifier);
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(CardTitleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editing && !widget.editable) {
      _editing = false;
      _commit(_controller?.text ?? widget.title, deferred: true);
    }
  }

  @override
  void dispose() {
    final pending = _editing ? (_controller?.text ?? widget.title) : null;
    _editing = false;
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller?.dispose();
    if (pending != null) {
      _commit(pending, deferred: true);
    }
    super.dispose();
  }

  void _commit(String text, {bool deferred = false}) {
    final board = _board;
    final cardId = widget.cardId;
    if (!deferred) {
      board.editCardTitle(cardId: cardId, title: text);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      board.editCardTitle(cardId: cardId, title: text);
    });
  }

  void _start() {
    final controller = TextEditingController(text: widget.title);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    setState(() {
      _controller?.dispose();
      _controller = controller;
      _editing = true;
    });
    _focus.requestFocus();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && _editing) {
      _finish(commit: true);
    }
  }

  void _finish({required bool commit}) {
    if (!_editing) {
      return;
    }
    final text = _controller?.text ?? widget.title;
    setState(() => _editing = false);
    if (commit) {
      _commit(text);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _finish(commit: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _finish(commit: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final l10n = AppLocalizations.of(context);
    final style = widget.style.copyWith(color: colors.textPrimary);
    if (!widget.editable) {
      return Semantics(header: true, child: Text(widget.title, style: style));
    }
    if (!_editing) {
      return _TitleButton(title: widget.title, style: style, onTap: _start);
    }
    final underline = UnderlineInputBorder(
      borderSide: BorderSide(
        color: colors.emphasis,
        width: sizes.emphasisBorder,
      ),
    );
    return Focus(
      onKeyEvent: _onKey,
      child: Semantics(
        header: true,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          maxLines: null,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(CardLimits.titleMaxLength),
          ],
          onSubmitted: (_) => _finish(commit: true),
          style: style,
          decoration: InputDecoration(
            labelText: l10n.cardTitleField,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            filled: false,
            isCollapsed: true,
            contentPadding: EdgeInsetsDirectional.symmetric(
              vertical: CardoSpacing.of(context).sm,
            ),
            border: underline,
            enabledBorder: underline,
            focusedBorder: underline,
          ),
        ),
      ),
    );
  }
}

class _TitleButton extends StatelessWidget {
  const _TitleButton({
    required this.title,
    required this.style,
    required this.onTap,
  });

  final String title;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      button: true,
      hint: AppLocalizations.of(context).cardTitleEditHint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: CardoSizes.of(context).tapTarget,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(title, style: style),
            ),
          ),
        ),
      ),
    );
  }
}
