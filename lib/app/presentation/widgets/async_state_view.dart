import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';
import 'app_state_views.dart';

typedef AsyncDataBuilder<T> = Widget Function(BuildContext context, T data);
typedef AsyncErrorBuilder =
    Widget Function(BuildContext context, Object error, StackTrace stackTrace);

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final AsyncValue<T> value;
  final AsyncDataBuilder<T> dataBuilder;
  final WidgetBuilder? loadingBuilder;
  final AsyncErrorBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loadingBuilder?.call(context) ?? const AppLoadingView(),
      error: (error, stackTrace) =>
          errorBuilder?.call(context, error, stackTrace) ??
          AppErrorView(message: AppLocalizations.of(context).dataLoadFailed),
      data: (data) => dataBuilder(context, data),
    );
  }
}
