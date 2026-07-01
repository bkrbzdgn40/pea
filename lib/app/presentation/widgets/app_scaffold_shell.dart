import 'package:flutter/material.dart';

import 'app_drawer.dart';

export 'app_drawer.dart' show AppDrawerPage;

class AppScaffoldShell extends StatelessWidget {
  const AppScaffoldShell({
    super.key,
    required this.title,
    required this.body,
    this.currentPage,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.showDrawer = true,
  });

  final String title;
  final Widget body;
  final AppDrawerPage? currentPage;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final bool showDrawer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: showDrawer ? AppDrawer(currentPage: currentPage) : null,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: actions,
      ),
      body: SafeArea(
        child: Padding(padding: padding, child: body),
      ),
    );
  }
}
