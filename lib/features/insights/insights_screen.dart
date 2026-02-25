import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/insights_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, kNavBarClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights',
              style: tt.headlineLarge,
            ).animate().fadeIn(duration: 500.ms),
            const SizedBox(height: 4),
            Text(
              'What Emori sees in your story',
              style: tt.bodyMedium,
            ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
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

            const SizedBox(height: 16),

            _InsightCard(
                  icon: Icons.nights_stay_outlined,
                  iconColor: Colors.white,
                  iconBg: AppColors.coral,
                  title: 'Weekly Reflection',
                  subtitle: 'A letter from Emori about your week',
                  buttonLabel: 'Generate Reflection',
                  asyncValue: ref.watch(weeklyReflectionProvider),
                  onTap: () =>
                      ref.read(weeklyReflectionProvider.notifier).generate(),
                )
                .animate()
                .fadeIn(delay: 350.ms, duration: 600.ms)
                .slideY(begin: 0.05, end: 0, delay: 350.ms, duration: 600.ms),
          ],
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
