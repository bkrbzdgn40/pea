import 'package:flutter/material.dart';

import '../../layout/app_layout.dart';
import '../../theme/app_design_tokens.dart';

class AppHeaderListView<T> extends StatelessWidget {
  const AppHeaderListView({
    super.key,
    required this.header,
    required this.items,
    required this.itemBuilder,
    required this.emptyState,
    this.padding,
    this.separatorHeight = AppSpacing.listGap,
  });

  final Widget header;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget emptyState;
  final EdgeInsetsGeometry? padding;
  final double separatorHeight;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? AppLayout.of(context).pagePadding;

    return ListView.separated(
      padding: resolvedPadding,
      itemCount: items.isEmpty ? 2 : items.length + 1,
      separatorBuilder: (_, _) => SizedBox(height: separatorHeight),
      itemBuilder: (context, index) {
        if (index == 0) {
          return header;
        }
        if (items.isEmpty) {
          return emptyState;
        }
        return itemBuilder(context, items[index - 1]);
      },
    );
  }
}
