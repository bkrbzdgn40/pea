import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import 'market_product_visual.dart';

class MarketProductGallery extends StatefulWidget {
  const MarketProductGallery({
    super.key,
    required this.productId,
    required this.productName,
    required this.imageAssetPaths,
    this.iconSize = 92,
  });

  final String productId;
  final String productName;
  final List<String> imageAssetPaths;
  final double iconSize;

  @override
  State<MarketProductGallery> createState() => _MarketProductGalleryState();
}

class _MarketProductGalleryState extends State<MarketProductGallery> {
  late final PageController _pageController;
  int _currentPage = 0;

  int get _pageCount =>
      widget.imageAssetPaths.isEmpty ? 1 : widget.imageAssetPaths.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant MarketProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        !listEquals(oldWidget.imageAssetPaths, widget.imageAssetPaths)) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final hasMultipleImages = _pageCount > 1;

    return Stack(
      key: ValueKey('market-product-gallery-${widget.productId}'),
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: ValueKey('market-product-gallery-pages-${widget.productId}'),
          controller: _pageController,
          itemCount: _pageCount,
          physics: hasMultipleImages
              ? const PageScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          onPageChanged: (page) {
            if (_currentPage == page) {
              return;
            }
            setState(() {
              _currentPage = page;
            });
          },
          itemBuilder: (context, index) {
            final imageAssetPath = widget.imageAssetPaths.isEmpty
                ? null
                : widget.imageAssetPaths[index];

            return KeyedSubtree(
              key: ValueKey(
                'market-product-gallery-image-${widget.productId}-$index',
              ),
              child: MarketProductVisual(
                productId: widget.productId,
                imageAssetPath: imageAssetPath,
                iconSize: widget.iconSize,
                semanticLabel: localizations.marketProductGalleryImageLabel(
                  widget.productName,
                  index + 1,
                  _pageCount,
                ),
              ),
            );
          },
        ),
        if (hasMultipleImages) ...[
          PositionedDirectional(
            start: AppSpacing.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _GalleryNavigationButton(
                key: const Key('market-product-gallery-previous'),
                icon: Icons.chevron_left_rounded,
                semanticLabel: localizations.marketPreviousProductImage,
                enabled: _currentPage > 0,
                onPressed: () => _animateToPage(_currentPage - 1),
              ),
            ),
          ),
          PositionedDirectional(
            end: AppSpacing.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _GalleryNavigationButton(
                key: const Key('market-product-gallery-next'),
                icon: Icons.chevron_right_rounded,
                semanticLabel: localizations.marketNextProductImage,
                enabled: _currentPage < _pageCount - 1,
                onPressed: () => _animateToPage(_currentPage + 1),
              ),
            ),
          ),
          PositionedDirectional(
            start: AppSpacing.sm,
            end: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _GalleryIndicator(
              currentPage: _currentPage,
              pageCount: _pageCount,
              semanticLabel: localizations.marketProductGalleryPosition(
                _currentPage + 1,
                _pageCount,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _animateToPage(int page) {
    if (page < 0 || page >= _pageCount || !_pageController.hasClients) {
      return;
    }

    if (AppMotion.prefersReducedMotion(context)) {
      _pageController.jumpToPage(page);
      return;
    }

    _pageController.animateToPage(
      page,
      duration: AppMotionDurations.standard,
      curve: AppMotionCurves.standard,
    );
  }
}

class _GalleryNavigationButton extends StatelessWidget {
  const _GalleryNavigationButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surfaceStrong.withValues(alpha: enabled ? 0.9 : 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox.square(
              dimension: AppTouchTargets.minimum,
              child: Icon(
                icon,
                color: enabled
                    ? colors.foreground
                    : colors.foregroundMuted.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryIndicator extends StatelessWidget {
  const _GalleryIndicator({
    required this.currentPage,
    required this.pageCount,
    required this.semanticLabel,
  });

  final int currentPage;
  final int pageCount;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final motionDuration = AppMotion.resolveDuration(
      context,
      AppMotionDurations.fast,
    );

    return Semantics(
      liveRegion: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceStrong.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: colors.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < pageCount; index++) ...[
                      AnimatedContainer(
                        key: ValueKey('market-product-gallery-dot-$index'),
                        duration: motionDuration,
                        width: index == currentPage ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index == currentPage
                              ? colors.analysisAccent
                              : colors.foregroundMuted.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                      if (index != pageCount - 1)
                        const SizedBox(width: AppSpacing.xxs),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${currentPage + 1} / $pageCount',
                      key: const Key('market-product-gallery-position'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
