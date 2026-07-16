import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../application/exercise_catalog.dart';
import '../data/exercise_guide_catalog.dart';
import '../models/exercise_guide_content.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  ExerciseDifficulty? _selectedDifficulty;

  @override
  Widget build(BuildContext context) {
    const catalog = ExerciseCatalog();
    const guideCatalog = ExerciseGuideCatalog();
    final contents = _selectedDifficulty == null
        ? guideCatalog.contents
        : guideCatalog.contents
              .where((content) => content.difficulty == _selectedDifficulty)
              .toList();

    return AppScaffoldShell(
      title: 'Hareket Rehberi',
      currentPage: AppDestination.guide,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          _DifficultyFilter(
            selectedDifficulty: _selectedDifficulty,
            onChanged: (difficulty) {
              setState(() => _selectedDifficulty = difficulty);
            },
          ),
          Expanded(
            child: contents.isEmpty
                ? const _GuideEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: contents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final content = contents[index];
                      final definition = catalog.definitionFor(content.type);

                      return _ExerciseGuideCard(
                        content: content,
                        isAnalysisSupported: definition.isAnalysisSupported,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyFilter extends StatelessWidget {
  const _DifficultyFilter({
    required this.selectedDifficulty,
    required this.onChanged,
  });

  final ExerciseDifficulty? selectedDifficulty;
  final ValueChanged<ExerciseDifficulty?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          _FilterChipButton(
            label: 'Tümü',
            isSelected: selectedDifficulty == null,
            onTap: () => onChanged(null),
          ),
          for (final difficulty in ExerciseDifficulty.values) ...[
            const SizedBox(width: 8),
            _FilterChipButton(
              label: difficulty.label,
              isSelected: selectedDifficulty == difficulty,
              onTap: () => onChanged(difficulty),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: const Color(0xFF151515),
      selectedColor: Colors.greenAccent,
      side: BorderSide(color: isSelected ? Colors.greenAccent : Colors.white12),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _ExerciseGuideCard extends StatelessWidget {
  const _ExerciseGuideCard({
    required this.content,
    required this.isAnalysisSupported,
  });

  final ExerciseGuideContent content;
  final bool isAnalysisSupported;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151515),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.greenAccent,
          collapsedIconColor: Colors.white70,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _GuideBadge(label: content.difficulty.label, isActive: false),
                  if (isAnalysisSupported)
                    const _GuideBadge(label: 'Analiz aktif', isActive: true),
                ],
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              content.subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          children: [
            _GuideTextBlock(title: 'Amaç', text: content.purpose),
            const SizedBox(height: 14),
            _GuideSection(title: 'Kurulum', items: content.setupSteps),
            const SizedBox(height: 14),
            _GuideSection(title: 'Teknik İpuçları', items: content.tips),
            const SizedBox(height: 14),
            _GuideSection(
              title: 'Yaygın Hatalar',
              items: content.commonMistakes,
            ),
            const SizedBox(height: 16),
            _VideoButton(content: content),
          ],
        ),
      ),
    );
  }
}

class _GuideBadge extends StatelessWidget {
  const _GuideBadge({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.greenAccent
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: isActive ? null : Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.black : Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GuideTextBlock extends StatelessWidget {
  const _GuideTextBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, color: Colors.greenAccent, size: 6),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VideoButton extends StatelessWidget {
  const _VideoButton({required this.content});

  final ExerciseGuideContent content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sourceLabel = Text(
            'Kaynak: ${content.youtubeSourceLabel}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );
          final button = TextButton.icon(
            onPressed: () => _openVideo(context, content.youtubeUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('YouTube’da İzle'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.greenAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          );

          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sourceLabel,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: button),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: sourceLabel),
              const SizedBox(width: 10),
              button,
            ],
          );
        },
      ),
    );
  }

  Future<void> _openVideo(BuildContext context, String url) async {
    // Product choice: keep guide videos external until an in-app player is designed.
    final uri = Uri.parse(url);
    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!didLaunch && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video bağlantısı açılamadı.')),
      );
    }
  }
}

class _GuideEmptyState extends StatelessWidget {
  const _GuideEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: const Text(
            'Bu zorlukta rehber içeriği bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
