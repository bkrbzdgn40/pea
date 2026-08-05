import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../application/payments/market_payment_browser.dart';
import '../../application/payments/market_payment_navigation_policy.dart';
import '../../application/payments/market_payment_session.dart';
import '../../application/payments/market_payment_status.dart';
import '../formatters/market_price_formatter.dart';
import '../providers/market_cart_provider.dart';
import '../providers/market_payment_session_provider.dart';

enum _MarketPaytrScreenPhase {
  loading,
  active,
  verifying,
  paid,
  failed,
  unknown,
  webError,
}

class MarketPaytrPaymentScreen extends ConsumerStatefulWidget {
  const MarketPaytrPaymentScreen({super.key, required this.session});

  final MarketPaymentSession session;

  @override
  ConsumerState<MarketPaytrPaymentScreen> createState() =>
      _MarketPaytrPaymentScreenState();
}

class _MarketPaytrPaymentScreenState
    extends ConsumerState<MarketPaytrPaymentScreen> {
  late final MarketPaymentNavigationPolicy _navigationPolicy;
  late final MarketPaymentBrowser _browser;

  _MarketPaytrScreenPhase _phase = _MarketPaytrScreenPhase.loading;
  MarketPaymentStatus? _status;
  String? _message;
  int _pageProgress = 0;
  bool _verificationRunning = false;
  bool _cartCleared = false;

  @override
  void initState() {
    super.initState();
    _navigationPolicy = MarketPaymentNavigationPolicy(widget.session);
    _browser = ref
        .read(marketPaymentBrowserFactoryProvider)
        .create(
          initialUri: widget.session.iframeUri,
          onNavigation: _handleNavigation,
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onMainFrameError: _handleMainFrameError,
        );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isFinal =
        _phase == _MarketPaytrScreenPhase.paid ||
        _phase == _MarketPaytrScreenPhase.failed;

    return PopScope(
      canPop: isFinal,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_confirmExit());
        }
      },
      child: AppScaffoldShell(
        title: localizations.marketPaytrScreenTitle,
        showDrawer: false,
        maxContentWidth: 900,
        padding: const EdgeInsets.all(AppSpacing.sm),
        actions: <Widget>[
          if (!isFinal)
            IconButton(
              key: const Key('market-paytr-check-status-action'),
              tooltip: localizations.marketPaytrCheckStatus,
              onPressed: _verificationRunning
                  ? null
                  : () => unawaited(_verifyPayment()),
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PaymentHeader(
              session: widget.session,
              phase: _phase,
              pageProgress: _pageProgress,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_phase) {
      _MarketPaytrScreenPhase.paid => _PaymentResultCard(
        key: const Key('market-paytr-payment-paid'),
        icon: Icons.check_circle_outline_rounded,
        title: AppLocalizations.of(context).marketPaytrPaidTitle,
        message: AppLocalizations.of(context).marketPaytrPaidMessage,
        status: _status,
        primaryLabel: AppLocalizations.of(context).marketPaytrReturnToMarket,
        onPrimary: () => Navigator.of(context).pop(true),
      ),
      _MarketPaytrScreenPhase.failed => _PaymentResultCard(
        key: const Key('market-paytr-payment-failed'),
        icon: Icons.error_outline_rounded,
        title: AppLocalizations.of(context).marketPaytrFailedTitle,
        message: AppLocalizations.of(context).marketPaytrFailedMessage,
        status: _status,
        primaryLabel: AppLocalizations.of(context).marketReturnToCart,
        onPrimary: () => Navigator.of(context).pop(false),
      ),
      _MarketPaytrScreenPhase.unknown => _PaymentProblemCard(
        key: const Key('market-paytr-payment-unknown'),
        title: AppLocalizations.of(context).marketPaytrUnknownTitle,
        message:
            _message ?? AppLocalizations.of(context).marketPaytrUnknownMessage,
        onRetryStatus: _verificationRunning
            ? null
            : () => unawaited(_verifyPayment()),
        onReload: () => unawaited(_reloadBrowser()),
      ),
      _MarketPaytrScreenPhase.webError => _PaymentProblemCard(
        key: const Key('market-paytr-web-error'),
        title: AppLocalizations.of(context).marketPaytrWebErrorTitle,
        message:
            _message ?? AppLocalizations.of(context).marketPaytrWebErrorMessage,
        onRetryStatus: _verificationRunning
            ? null
            : () => unawaited(_verifyPayment()),
        onReload: () => unawaited(_reloadBrowser()),
      ),
      _ => Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.surface),
            child: _browser.build(key: const Key('market-paytr-webview')),
          ),
          if (_phase == _MarketPaytrScreenPhase.loading)
            const ColoredBox(
              color: Colors.white,
              child: Center(
                child: CircularProgressIndicator(
                  key: Key('market-paytr-page-loading'),
                ),
              ),
            ),
          if (_phase == _MarketPaytrScreenPhase.verifying)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: AppSurfaceCard(
                  key: const Key('market-paytr-verifying'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).marketPaytrVerifyingMessage,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    };
  }

  MarketPaymentNavigationDecision _handleNavigation(Uri uri) {
    final decision = _navigationPolicy.decide(uri);
    if (decision == MarketPaymentNavigationDecision.successReturn ||
        decision == MarketPaymentNavigationDecision.failureReturn) {
      unawaited(_verifyPayment());
    } else if (decision == MarketPaymentNavigationDecision.block && mounted) {
      setState(() {
        _message = AppLocalizations.of(context).marketPaytrBlockedNavigation;
      });
    }
    return decision;
  }

  void _handlePageStarted(Uri uri) {
    if (!mounted || _verificationRunning) {
      return;
    }
    setState(() {
      _phase = _MarketPaytrScreenPhase.loading;
      _pageProgress = 20;
      _message = null;
    });
  }

  void _handlePageFinished(Uri uri) {
    if (!mounted || _verificationRunning) {
      return;
    }
    setState(() {
      _phase = _MarketPaytrScreenPhase.active;
      _pageProgress = 100;
    });
  }

  void _handleMainFrameError(String message) {
    if (!mounted || _verificationRunning) {
      return;
    }
    setState(() {
      _phase = _MarketPaytrScreenPhase.webError;
      _message = AppLocalizations.of(context).marketPaytrWebErrorMessage;
    });
  }

  Future<void> _verifyPayment() async {
    if (_verificationRunning || !mounted) {
      return;
    }
    _verificationRunning = true;
    setState(() {
      _phase = _MarketPaytrScreenPhase.verifying;
      _message = null;
    });

    final repository = ref.read(marketPaymentStatusRepositoryProvider);
    final delay = ref.read(marketPaymentVerificationDelayProvider);
    final attempts = ref.read(marketPaymentVerificationAttemptsProvider);
    final interval = ref.read(marketPaymentVerificationIntervalProvider);

    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        final status = await repository.getStatus(
          orderId: widget.session.orderId,
        );
        if (!mounted) {
          return;
        }
        if (status.merchantOid != widget.session.merchantOid ||
            status.total != widget.session.total) {
          throw const FormatException('Payment status does not match session.');
        }

        if (status.value == MarketPaymentStatusValue.paid) {
          if (!_cartCleared) {
            ref.read(marketCartProvider.notifier).clear();
            _cartCleared = true;
          }
          setState(() {
            _status = status;
            _phase = _MarketPaytrScreenPhase.paid;
          });
          return;
        }
        if (status.value == MarketPaymentStatusValue.failed) {
          setState(() {
            _status = status;
            _phase = _MarketPaytrScreenPhase.failed;
          });
          return;
        }
        if (attempt < attempts - 1) {
          await delay(interval);
        }
      }

      if (mounted) {
        setState(() {
          _phase = _MarketPaytrScreenPhase.unknown;
          _message = AppLocalizations.of(context).marketPaytrUnknownMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _MarketPaytrScreenPhase.unknown;
          _message = AppLocalizations.of(context).marketPaytrStatusError;
        });
      }
    } finally {
      _verificationRunning = false;
    }
  }

  Future<void> _reloadBrowser() async {
    setState(() {
      _phase = _MarketPaytrScreenPhase.loading;
      _pageProgress = 0;
      _message = null;
    });
    await _browser.reload();
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).marketPaytrExitTitle),
        content: Text(AppLocalizations.of(context).marketPaytrExitMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            key: const Key('market-paytr-confirm-exit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(context).marketPaytrExitAction),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader({
    required this.session,
    required this.phase,
    required this.pageProgress,
  });

  final MarketPaymentSession session;
  final _MarketPaytrScreenPhase phase;
  final int pageProgress;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final localizations = AppLocalizations.of(context);
    final formatter = MarketPriceFormatter(localizations.locale);

    return AppSurfaceCard(
      key: const Key('market-paytr-payment-header'),
      variant: AppSurfaceVariant.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: colors.analysisAccent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  localizations.marketPaytrSecureHeader,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                formatter.format(session.total),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.marketPaymentOrderReference(session.orderId),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.foregroundMuted),
          ),
          if (phase == _MarketPaytrScreenPhase.loading) ...[
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(value: pageProgress / 100),
          ],
        ],
      ),
    );
  }
}

class _PaymentResultCard extends StatelessWidget {
  const _PaymentResultCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.status,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String message;
  final MarketPaymentStatus? status;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final formatter = MarketPriceFormatter(AppLocalizations.of(context).locale);

    return Center(
      child: AppSurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.analysisAccent),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            if (status != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppLocalizations.of(
                  context,
                ).marketPaymentOrderReference(status!.orderId),
              ),
              Text(
                AppLocalizations.of(
                  context,
                ).marketPaymentVerifiedTotal(formatter.format(status!.total)),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
          ],
        ),
      ),
    );
  }
}

class _PaymentProblemCard extends StatelessWidget {
  const _PaymentProblemCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetryStatus,
    required this.onReload,
  });

  final String title;
  final String message;
  final VoidCallback? onRetryStatus;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: const Key('market-paytr-reload-page'),
                  onPressed: onReload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppLocalizations.of(context).marketPaytrReload),
                ),
                FilledButton.icon(
                  key: const Key('market-paytr-retry-status'),
                  onPressed: onRetryStatus,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(
                    AppLocalizations.of(context).marketPaytrCheckStatus,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
