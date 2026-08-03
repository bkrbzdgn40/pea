import 'package:flutter/material.dart';

import '../../layout/app_layout.dart';
import '../../theme/app_semantic_colors.dart';
import 'app_drawer.dart';

export '../../navigation/app_destination.dart' show AppDestination;

class AppScaffoldShell extends StatelessWidget {
  static const contentPaddingKey = Key('app-scaffold-shell-content-padding');

  const AppScaffoldShell({
    super.key,
    required this.title,
    required this.body,
    this.currentPage,
    this.actions,
    this.padding,
    this.showDrawer = true,
    this.maxContentWidth = 1280,
  }) : assert(maxContentWidth > 0);

  final String title;
  final Widget body;
  final AppDestination? currentPage;
  final List<Widget>? actions;

  /// Overrides the viewport-aware page padding when a screen needs a custom
  /// edge-to-edge composition.
  final EdgeInsetsGeometry? padding;
  final bool showDrawer;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final layout = AppLayout.of(context);
    final resolvedPadding = padding ?? layout.pagePadding;

    return Scaffold(
      backgroundColor: colors.canvas,
      drawer: showDrawer ? AppDrawer(currentPage: currentPage) : null,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      body: ColoredBox(
        color: colors.canvas,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                key: contentPaddingKey,
                padding: resolvedPadding,
                child: SizedBox(width: double.infinity, child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
