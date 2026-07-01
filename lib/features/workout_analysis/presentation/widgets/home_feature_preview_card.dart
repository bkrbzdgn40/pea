import 'package:flutter/material.dart';

class HomeFeaturePreviewCard extends StatelessWidget {
  const HomeFeaturePreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeText,
    this.progress,
    this.trailingText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;
  final double? progress;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress?.clamp(0, 1).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.greenAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            _PreviewBadge(text: badgeText!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.greenAccent,
                ),
              ],
            ),
            if (normalizedProgress != null || trailingText != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trailingText ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (normalizedProgress != null)
                    Text(
                      '%${(normalizedProgress * 100).round()}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              if (normalizedProgress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: normalizedProgress,
                  minHeight: 7,
                  backgroundColor: Colors.white12,
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.greenAccent,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
