import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/insights_provider.dart';

class PatternDetectionScreen extends ConsumerWidget {
  const PatternDetectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          'Pattern Detection',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, kNavBarClearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discover Your Patterns',
                style: tt.headlineLarge,
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 16),
              Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.hub_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'What is Pattern Detection?',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Emori analyzes your journal entries over the past 30 days to uncover recurring themes in your thoughts, emotions, and behaviors. By stepping back and looking at the big picture, you might discover things about yourself that you didn't even notice. Finding my patterns gives you the power to break the ones that don't serve you.",
                          style: TextStyle(fontFamily: 'Nunito', 
                            fontSize: 14,
                            color: c.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 500.ms)
                  .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 500.ms),
              const SizedBox(height: 28),

              Text(
                'Recent Emotions',
                style: TextStyle(fontFamily: 'PlusJakartaSans', 
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 16),

              ref
                  .watch(emotionFrequencyProvider)
                  .when(
                    data: (frequencies) {
                      if (frequencies.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.border),
                          ),
                          child: Center(
                            child: Text(
                              "Not enough data to graph your emotions yet. Keep journaling!",
                              style: TextStyle(fontFamily: 'Nunito', color: c.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return _EmotionChart(frequencies: frequencies)
                          .animate()
                          .fadeIn(delay: 150.ms, duration: 600.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            delay: 150.ms,
                            duration: 600.ms,
                            curve: Curves.easeOutBack,
                          );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                  ),

              const SizedBox(height: 28),

              _InsightCard(
                    icon: Icons.hub_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.sage,
                    title: 'Pattern Detection',
                    subtitle: 'Based on your last 30 days',
                    buttonLabel: 'Find My Patterns',
                    asyncValue: ref.watch(patternsProvider),
                    onTap: () => ref.read(patternsProvider.notifier).analyze(),
                  )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms)
                  .slideY(begin: 0.05, end: 0, delay: 200.ms, duration: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final AsyncValue<String?> asyncValue;
  final VoidCallback onTap;

  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.asyncValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontFamily: 'PlusJakartaSans', 
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontFamily: 'Nunito', 
                          fontSize: 12,
                          color: c.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.all(18),
            child: asyncValue.when(
              data: (result) {
                if (result == null) return _buildButton();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result,
                      style: TextStyle(fontFamily: 'Nunito', 
                        fontSize: 13,
                        height: 1.7,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: onTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 15,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Regenerate',
                            style: TextStyle(fontFamily: 'Nunito', 
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => _buildLoading(),
              error: (e, st) => Column(
                children: [
                  Text(
                    'Something went wrong. Try again.',
                    style: TextStyle(fontFamily: 'Nunito', color: AppColors.error),
                  ),
                  const SizedBox(height: 10),
                  _buildButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [AppShadows.colored(AppColors.primary)],
        ),
        child: Center(
          child: Text(
            buttonLabel,
            style: TextStyle(fontFamily: 'PlusJakartaSans', 
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(
          4,
          (i) =>
              Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 12,
                    width: i == 3 ? 160 : double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.sage.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                  .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
                  .shimmer(
                    duration: 1200.ms,
                    color: AppColors.olive.withValues(alpha: 0.15),
                  ),
        ),
        const SizedBox(height: 6),
        Text(
          'Emori is thinking...',
          style: TextStyle(fontFamily: 'Nunito', 
            fontSize: 12,
            color: AppColors.teal,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _EmotionChart extends StatelessWidget {
  final Map<String, int> frequencies;

  const _EmotionChart({required this.frequencies});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Define a palette of colors for the chart
    final List<Color> colors = [
      AppColors.primary,
      AppColors.coral,
      AppColors.teal,
      AppColors.sage,
      AppColors.olive,
    ];

    int total = frequencies.values.fold(0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: frequencies.entries.toList().asMap().entries.map((
                  entry,
                ) {
                  final index = entry.key;
                  final MapEntry<String, int> data = entry.value;
                  final double percentage = (data.value / total) * 100;
                  final isLarge = percentage > 10;

                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: data.value.toDouble(),
                    title: isLarge ? '${percentage.toStringAsFixed(0)}%' : '',
                    radius: 50,
                    titleStyle: TextStyle(fontFamily: 'Nunito', 
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: frequencies.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${data.key} (${data.value})',
                    style: TextStyle(fontFamily: 'Nunito', 
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
} // end of file
