import 'package:flutter/material.dart';

import '../../../../theme/cardo_theme.dart';

class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin<KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class BottomFade extends StatelessWidget {
  const BottomFade({super.key});

  @override
  Widget build(BuildContext context) {
    final background = CardoColors.of(context).background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: <Color>[background.withValues(alpha: 0), background],
        ),
      ),
    );
  }
}

class BoundedHeaderLayout extends StatelessWidget {
  const BoundedHeaderLayout({
    super.key,
    required this.header,
    required this.body,
  });

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final fraction = CardoLayout.of(context).headerMaxFraction;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * fraction,
              ),
              child: SingleChildScrollView(child: header),
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
