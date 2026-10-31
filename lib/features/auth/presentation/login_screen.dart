import 'package:flutter/material.dart';

import '../../../shared/widgets/scrollable_fill.dart';
import '../../../theme/cardo_theme.dart';
import 'widgets/brand_panels.dart';
import 'widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final wide =
        layout.windowClassFor(MediaQuery.sizeOf(context).width) ==
        CardoWindowClass.expanded;
    return Scaffold(
      body: wide
          ? SafeArea(
              child: Padding(
                padding: EdgeInsetsDirectional.all(spacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.lg,
                  children: <Widget>[
                    const Expanded(child: BrandPanel()),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: metrics.formMaxWidth,
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsetsDirectional.symmetric(
                              vertical: spacing.section,
                            ),
                            child: const LoginForm(wide: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
                child: const ScrollableFill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      BrandHero(),
                      Expanded(child: LoginForm(wide: false)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
