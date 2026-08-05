import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../application/payments/market_checkout_customer.dart';
import '../../application/payments/market_payment_session.dart';
import '../../application/payments/market_payment_session_failure.dart';
import '../../domain/models/market_cart.dart';
import '../../domain/models/market_cart_line.dart';
import '../formatters/market_price_formatter.dart';
import '../providers/market_cart_provider.dart';
import '../providers/market_payment_session_provider.dart';
import 'market_paytr_payment_screen.dart';
import '../widgets/market_empty_state.dart';

class MarketCheckoutScreen extends ConsumerWidget {
  const MarketCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final isEmpty = ref.watch(
      marketCartProvider.select((cart) => cart.isEmpty),
    );

    return AppScaffoldShell(
      title: localizations.marketCheckoutTitle,
      showDrawer: false,
      maxContentWidth: 760,
      body: isEmpty
          ? MarketEmptyState(
              key: const Key('market-checkout-empty-state'),
              icon: Icons.receipt_long_outlined,
              title: localizations.marketCheckoutEmptyTitle,
              message: localizations.marketCheckoutEmptyMessage,
              actionLabel: localizations.marketReturnToCart,
              actionKey: const Key('market-checkout-return-to-cart'),
              onAction: () => Navigator.of(context).maybePop(),
            )
          : const _MarketCheckoutContent(),
    );
  }
}

class _MarketCheckoutContent extends ConsumerStatefulWidget {
  const _MarketCheckoutContent();

  @override
  ConsumerState<_MarketCheckoutContent> createState() =>
      _MarketCheckoutContentState();
}

class _MarketCheckoutContentState
    extends ConsumerState<_MarketCheckoutContent> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _fullNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  bool _paymentStateResetScheduled = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _fullNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(marketCartProvider);
    final isSubmitting = ref.watch(
      marketPaymentSessionControllerProvider.select(
        (state) => state.isSubmitting,
      ),
    );
    final layout = AppLayout.of(context);

    return CustomScrollView(
      key: const Key('market-checkout-scroll-view'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CheckoutSecurityNotice(),
              SizedBox(height: layout.panelGap),
              AutofillGroup(
                child: _DeliveryFormCard(
                  formKey: _formKey,
                  fullNameController: _fullNameController,
                  emailController: _emailController,
                  phoneController: _phoneController,
                  addressController: _addressController,
                  fullNameFocusNode: _fullNameFocusNode,
                  emailFocusNode: _emailFocusNode,
                  phoneFocusNode: _phoneFocusNode,
                  addressFocusNode: _addressFocusNode,
                  enabled: !isSubmitting,
                  onChanged: _markInputChanged,
                ),
              ),
              SizedBox(height: layout.panelGap),
              const _PaymentMethodCard(),
              SizedBox(height: layout.panelGap),
              _OrderItemsCard(lines: cart.lines),
              SizedBox(height: layout.panelGap),
              _OrderTotalCard(cart: cart),
              Consumer(
                builder: (context, ref, child) {
                  final paymentState = ref.watch(
                    marketPaymentSessionControllerProvider,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (paymentState.phase ==
                              MarketPaymentSessionPhase.failed ||
                          paymentState.phase ==
                              MarketPaymentSessionPhase.ready) ...[
                        SizedBox(height: layout.panelGap),
                        _PaymentSessionStatusCard(state: paymentState),
                      ],
                      SizedBox(height: layout.panelGap),
                      FilledButton.icon(
                        key: const Key(
                          'market-checkout-create-payment-session',
                        ),
                        onPressed:
                            paymentState.phase ==
                                    MarketPaymentSessionPhase.ready &&
                                paymentState.session != null
                            ? () => _openPayment(paymentState.session!)
                            : paymentState.canSubmit
                            ? () => _submit(cart)
                            : null,
                        icon: paymentState.isSubmitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  key: Key('market-checkout-payment-progress'),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_outline_rounded),
                        label: Text(
                          _paymentButtonLabel(
                            AppLocalizations.of(context),
                            paymentState.phase,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxs),
            ],
          ),
        ),
      ],
    );
  }

  void _markInputChanged(String _) {
    final paymentState = ref.read(marketPaymentSessionControllerProvider);
    final shouldResetPaymentState =
        paymentState.phase == MarketPaymentSessionPhase.ready ||
        paymentState.phase == MarketPaymentSessionPhase.failed;
    if (!shouldResetPaymentState || _paymentStateResetScheduled) {
      return;
    }

    _paymentStateResetScheduled = true;
    // Do not mutate payment UI state inside the platform text-input update.
    // Deferring one frame keeps the active IME connection and focus intact.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paymentStateResetScheduled = false;
      if (!mounted) {
        return;
      }
      ref
          .read(marketPaymentSessionControllerProvider.notifier)
          .markInputChanged();
    });
  }

  Future<void> _openPayment(MarketPaymentSession session) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MarketPaytrPaymentScreen(session: session),
      ),
    );
  }

  Future<void> _submit(MarketCart cart) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(marketPaymentSessionControllerProvider.notifier)
        .createSession(
          cart: cart,
          customer: MarketCheckoutCustomer(
            email: _emailController.text,
            fullName: _fullNameController.text,
            phone: _phoneController.text,
            address: _addressController.text,
          ),
        );
  }

  String _paymentButtonLabel(
    AppLocalizations localizations,
    MarketPaymentSessionPhase phase,
  ) {
    return switch (phase) {
      MarketPaymentSessionPhase.submitting =>
        localizations.marketPaymentSessionCreating,
      MarketPaymentSessionPhase.ready =>
        localizations.marketPaymentSessionReadyButton,
      MarketPaymentSessionPhase.idle || MarketPaymentSessionPhase.failed =>
        localizations.marketCreatePaymentSession,
    };
  }
}

class _CheckoutSecurityNotice extends StatelessWidget {
  const _CheckoutSecurityNotice();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const Key('market-checkout-security-notice'),
      variant: AppSurfaceVariant.accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: colors.analysisAccent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.marketSecureCheckoutTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.marketSecureCheckoutDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryFormCard extends StatelessWidget {
  const _DeliveryFormCard({
    required this.formKey,
    required this.fullNameController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.fullNameFocusNode,
    required this.emailFocusNode,
    required this.phoneFocusNode,
    required this.addressFocusNode,
    required this.enabled,
    required this.onChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final FocusNode fullNameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode addressFocusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const Key('market-checkout-delivery-card'),
      variant: AppSurfaceVariant.standard,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: colors.foregroundMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    localizations.marketDeliveryInformation,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: AppFontWeights.heavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('market-checkout-full-name'),
              controller: fullNameController,
              focusNode: fullNameFocusNode,
              enabled: enabled,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: 60,
              decoration: InputDecoration(
                labelText: localizations.marketCheckoutFullName,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              onChanged: onChanged,
              validator: (value) => _requiredLengthValidator(
                value,
                localizations,
                minimum: 2,
                maximum: 60,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('market-checkout-email'),
              controller: emailController,
              focusNode: emailFocusNode,
              enabled: enabled,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              maxLength: 100,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: localizations.marketCheckoutEmail,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              onChanged: onChanged,
              validator: (value) {
                final normalized = value?.trim() ?? '';
                if (normalized.isEmpty) {
                  return localizations.marketCheckoutRequiredField;
                }
                final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                final isAscii = normalized.codeUnits.every(
                  (unit) => unit < 128,
                );
                if (normalized.length > 100 ||
                    !emailPattern.hasMatch(normalized) ||
                    !isAscii) {
                  return localizations.marketCheckoutInvalidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('market-checkout-phone'),
              controller: phoneController,
              focusNode: phoneFocusNode,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              maxLength: 20,
              decoration: InputDecoration(
                labelText: localizations.marketCheckoutPhone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              onChanged: onChanged,
              validator: (value) {
                final normalized = value?.trim() ?? '';
                if (normalized.isEmpty) {
                  return localizations.marketCheckoutRequiredField;
                }
                final digitCount = RegExp(r'\d').allMatches(normalized).length;
                if (normalized.length > 20 || digitCount < 7) {
                  return localizations.marketCheckoutInvalidPhone;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('market-checkout-address'),
              controller: addressController,
              focusNode: addressFocusNode,
              enabled: enabled,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              autofillHints: const [AutofillHints.fullStreetAddress],
              minLines: 3,
              maxLines: 5,
              maxLength: 400,
              decoration: InputDecoration(
                labelText: localizations.marketCheckoutAddress,
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              onChanged: onChanged,
              validator: (value) => _requiredLengthValidator(
                value,
                localizations,
                minimum: 10,
                maximum: 400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredLengthValidator(
    String? value,
    AppLocalizations localizations, {
    required int minimum,
    required int maximum,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return localizations.marketCheckoutRequiredField;
    }
    if (normalized.length < minimum || normalized.length > maximum) {
      return localizations.marketCheckoutInvalidLength(minimum, maximum);
    }
    return null;
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const Key('market-checkout-payment-card'),
      variant: AppSurfaceVariant.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.payment_outlined, color: colors.foregroundMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.marketPaymentMethod,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.marketPaytrPaymentMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSessionStatusCard extends StatelessWidget {
  const _PaymentSessionStatusCard({required this.state});

  final MarketPaymentSessionState state;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final session = state.session;
    final failure = state.failure;
    final isReady = session != null;

    return AppSurfaceCard(
      key: Key(
        isReady
            ? 'market-checkout-payment-session-ready'
            : 'market-checkout-payment-session-error',
      ),
      variant: isReady ? AppSurfaceVariant.accent : AppSurfaceVariant.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.check_circle_outline : Icons.error_outline,
            color: isReady ? colors.analysisAccent : colors.foregroundMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady
                      ? localizations.marketPaymentSessionReadyTitle
                      : localizations.marketPaymentSessionErrorTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isReady
                      ? localizations.marketPaymentSessionReadyDescription
                      : _localizedFailure(localizations, failure),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
                  ),
                ),
                if (session != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    localizations.marketPaymentOrderReference(session.orderId),
                    key: const Key('market-checkout-payment-order-id'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    localizations.marketPaymentVerifiedTotal(
                      MarketPriceFormatter(
                        localizations.locale,
                      ).format(session.total),
                    ),
                    key: const Key('market-checkout-payment-server-total'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _localizedFailure(
    AppLocalizations localizations,
    MarketPaymentSessionFailure? failure,
  ) {
    return switch (failure?.code) {
      'payment_not_configured' =>
        localizations.marketPaymentConfigurationMissing,
      'unauthenticated' => localizations.marketPaymentAuthenticationRequired,
      'product_unavailable' ||
      'mixed_currency' ||
      'invalid_quantity' ||
      'invalid_items' ||
      'too_many_items' => localizations.marketPaymentCartChanged,
      'payment_already_finalized' =>
        localizations.marketPaymentAlreadyFinalized,
      'payment_session_timeout' || 'payment_session_network_error' =>
        localizations.marketPaymentNetworkFailure,
      _ => localizations.marketPaymentSessionGenericFailure,
    };
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.lines});

  final List<MarketCartLine> lines;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const Key('market-checkout-order-items'),
      variant: AppSurfaceVariant.strong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.marketOrderItems,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < lines.length; index++) ...[
            _OrderLineSummary(line: lines[index]),
            if (index != lines.length - 1)
              Divider(height: AppSpacing.xl, color: colors.outlineSubtle),
          ],
        ],
      ),
    );
  }
}

class _OrderLineSummary extends StatelessWidget {
  const _OrderLineSummary({required this.line});

  final MarketCartLine line;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final formatter = MarketPriceFormatter(localizations.locale);

    return Column(
      key: ValueKey('market-checkout-line-${line.product.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.marketProductName(line.product.id),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colors.foreground,
            fontWeight: AppFontWeights.semibold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              '${line.quantity} × ${formatter.format(line.product.price)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.foregroundMuted),
            ),
            Text(
              formatter.format(line.lineTotal),
              key: ValueKey('market-checkout-line-total-${line.product.id}'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderTotalCard extends StatelessWidget {
  const _OrderTotalCard({required this.cart});

  final MarketCart cart;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final total = MarketPriceFormatter(
      localizations.locale,
    ).format(cart.subtotal);

    return AppSurfaceCard(
      key: const Key('market-checkout-total-card'),
      variant: AppSurfaceVariant.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResponsiveAmountRow(
            label: localizations.marketSubtotal,
            value: total,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizations.marketCheckoutTotalNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.4,
            ),
          ),
          Divider(height: AppSpacing.xl, color: colors.outlineSubtle),
          _ResponsiveAmountRow(
            label: localizations.marketCheckoutTotal,
            value: total,
            valueKey: const Key('market-checkout-total-value'),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _ResponsiveAmountRow extends StatelessWidget {
  const _ResponsiveAmountRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = textScale >= 1.5 || constraints.maxWidth < 260;
        final textTheme = Theme.of(context).textTheme;
        final colors = context.semanticColors;

        final labelWidget = Text(
          label,
          style: (emphasize ? textTheme.titleMedium : textTheme.bodyLarge)
              ?.copyWith(
                color: colors.foreground,
                fontWeight: emphasize
                    ? AppFontWeights.heavy
                    : AppFontWeights.semibold,
              ),
        );
        final valueWidget = Text(
          value,
          key: valueKey,
          textAlign: TextAlign.end,
          style: (emphasize ? textTheme.titleLarge : textTheme.bodyLarge)
              ?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.heavy,
              ),
        );

        if (useStackedLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelWidget,
              const SizedBox(height: AppSpacing.xs),
              Align(alignment: Alignment.centerRight, child: valueWidget),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: AppSpacing.sm),
            valueWidget,
          ],
        );
      },
    );
  }
}
