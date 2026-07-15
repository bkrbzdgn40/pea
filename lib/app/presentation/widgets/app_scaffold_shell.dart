import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import 'app_drawer.dart';

export 'app_drawer.dart' show AppDestination;

class AppScaffoldShell extends StatelessWidget {
  const AppScaffoldShell({
    super.key,
    required this.title,
    required this.body,
    this.currentPage,
    this.actions,
    this.padding = AppSpacing.pagePadding,
    this.showDrawer = true,
  });

  final String title;
  final Widget body;
  final AppDestination? currentPage;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final bool showDrawer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: showDrawer ? AppDrawer(currentPage: currentPage) : null,
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Padding(padding: padding, child: body),
      ),
    );
  }
}
