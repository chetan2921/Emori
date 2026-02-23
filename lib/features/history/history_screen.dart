import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/entry.dart';
import '../../core/providers/entry_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: context.colors.surface,
              onSurface: context.colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(entriesProvider);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: entriesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (allEntries) {
            // Filter by date if selected
            final entries = _selectedDate == null
                ? allEntries
                : allEntries.where((e) {
                    return e.createdAt.year == _selectedDate!.year &&
                        e.createdAt.month == _selectedDate!.month &&
                        e.createdAt.day == _selectedDate!.day;
                  }).toList();

            return _buildList(context, entries, tt, allEntries.isEmpty);
          },
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: Text('🌱', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Your story starts here', style: tt.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Share something with Emori\nand it will appear here.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildList(
    BuildContext context,
    List<Entry> entries,
    TextTheme tt,
    bool isCompletelyEmpty,
  ) {
    if (isCompletelyEmpty) return _buildEmpty(context, tt);

    final groups = _groupByDate(entries);
    final c = context.colors;

    return Column(
      children: [
        // Header with Back Button and Date Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: c.textPrimary),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back to Chat',
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Journey', style: tt.headlineLarge),
                          const SizedBox(height: 4),
                          Text(
                            _selectedDate == null
                                ? '${entries.length} ${entries.length == 1 ? 'memory' : 'memories'} captured'
                                : 'Showing memories for ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            style: tt.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (_selectedDate != null)
                    IconButton(
                      icon: Icon(Icons.clear, color: c.textSecondary),
                      onPressed: () => setState(() => _selectedDate = null),
                      tooltip: 'Clear filter',
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.calendar_month_outlined,
                      color: _selectedDate != null
                          ? AppColors.primary
                          : c.textSecondary,
                    ),
                    onPressed: _pickDate,
                    tooltip: 'Filter by date',
                  ),
                ],
              ),
            ],
          ),
        ),

        // No results state
        if (entries.isEmpty && _selectedDate != null)
          Expanded(
            child: Center(
              child: Text(
                'No memories on this date.',
                style: GoogleFonts.inter(color: c.textSecondary),
              ),
            ),
          )
        // Grouped List State
        else
          Expanded(
            child: Theme(
              // Remove default borders from ExpansionTile
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: kNavBarClearance),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final groupLabel = groups.keys.elementAt(index);
                  final groupEntries = groups[groupLabel]!;
                  final isRecent =
                      groupLabel == 'Today' || groupLabel == 'Yesterday';

                  return ExpansionTile(
                    initiallyExpanded: isRecent,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(
                      groupLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textHint,
                        letterSpacing: 0.5,
                      ),
                    ),
                    children: groupEntries
                        .map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EntryCard(entry: entry),
                          );
                        })
                        .toList()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05, end: 0, duration: 400.ms),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Map<String, List<Entry>> _groupByDate(List<Entry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final map = <String, List<Entry>>{};
    for (final entry in entries) {
      final d = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else if (now.difference(entry.createdAt).inDays < 7) {
        label = 'This Week';
      } else {
        label =
            '${entry.createdAt.day}/${entry.createdAt.month}/${entry.createdAt.year}';
      }
      map.putIfAbsent(label, () => []).add(entry);
    }
    return map;
  }
}

class _EntryCard extends ConsumerWidget {
  final Entry entry;
  const _EntryCard({required this.entry});

  IconData _typeIcon(String type) {
    const icons = {
      'lesson': Icons.lightbulb_outline_rounded,
      'feeling': Icons.favorite_outline_rounded,
      'idea': Icons.wb_incandescent_outlined,
      'goal': Icons.flag_outlined,
      'mistake': Icons.refresh_rounded,
      'gratitude': Icons.volunteer_activism_outlined,
      'observation': Icons.visibility_outlined,
    };
    return icons[type.toLowerCase()] ?? Icons.note_outlined;
  }

  String _personalizeSummary(String summary) {
    String text = summary;
    text = text.replaceAll(
      RegExp(r'\bThe writer\b', caseSensitive: false),
      'You',
    );
    text = text.replaceAll(
      RegExp(r'\bThe author\b', caseSensitive: false),
      'You',
    );
    text = text.replaceAll(RegExp(r'\bTheir\b', caseSensitive: false), 'Your');
    text = text.replaceAll(RegExp(r'\bThey\b', caseSensitive: false), 'You');

    // Quick grammar fixes for common AI phrasing that results from the above replacement
    text = text.replaceAll('You expresses', 'You express');
    text = text.replaceAll('You feels', 'You feel');
    text = text.replaceAll('You is', 'You are');
    text = text.replaceAll('You has', 'You have');
    text = text.replaceAll('You notes', 'You note');
    text = text.replaceAll('You mentions', 'You mention');
    text = text.replaceAll('You highlights', 'You highlight');
    text = text.replaceAll('You reflects', 'You reflect');
    text = text.replaceAll('You shares', 'You share');
    return text;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final displaySummary = _personalizeSummary(entry.summary);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete this memory?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          content: Text(
            'This entry will be permanently removed.',
            style: GoogleFonts.inter(color: c.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: c.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(entriesProvider.notifier).deleteEntry(entry.id),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border(bottom: BorderSide(color: c.border, width: 1.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(entry.type), size: 14, color: AppColors.teal),
                  const SizedBox(width: 5),
                  Text(
                    entry.type.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeOnly(entry.createdAt),
                    style: GoogleFonts.inter(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Images (if any)
              if (entry.imagePaths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.imagePaths.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(File(entry.imagePaths[index])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              Text(
                displaySummary,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: c.textPrimary,
                ),
              ),
              if (entry.emotions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entry.emotions.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.sage,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            e,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeOnly(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final a = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $a';
  }
}
