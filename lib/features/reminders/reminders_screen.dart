import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database.dart';
import '../../core/models/reminder.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final reminders = await AppDatabase.instance.getAllReminders();
    reminders.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    if (mounted) {
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleComplete(Reminder reminder) async {
    if (reminder.isCompleted) return;
    await AppDatabase.instance.markReminderCompleted(reminder.id);
    await _loadReminders();
  }

  Future<void> _deleteReminder(String id) async {
    await AppDatabase.instance.deleteReminder(id);
    await _loadReminders();
  }

  Map<String, List<Reminder>> _groupReminders(List<Reminder> reminders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final map = <String, List<Reminder>>{};

    for (final r in reminders) {
      final dueDay = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      String label;
      if (r.isCompleted) {
        label = 'Completed';
      } else if (dueDay.isBefore(today)) {
        label = 'Overdue';
      } else if (dueDay == today) {
        label = 'Today';
      } else if (dueDay == tomorrow) {
        label = 'Tomorrow';
      } else if (dueDay.difference(today).inDays <= 7) {
        label = 'This Week';
      } else {
        label = 'Later';
      }
      map.putIfAbsent(label, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tt = Theme.of(context).textTheme;
    final activeCount = _reminders.where((r) => !r.isCompleted).length;

    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _reminders.isEmpty
            ? _buildEmpty(c, tt)
            : _buildList(c, tt, activeCount),
      ),
    );
  }

  Widget _buildEmpty(EmoriColors c, TextTheme tt) {
    return Column(
      children: [
        _buildHeader(c, tt, 0),
        Expanded(
          child: Center(
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
                    child: Text('🔔', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('No reminders yet', style: tt.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Mention any date or deadline in chat\nand I\'ll remember it for you.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms),
        ),
      ],
    );
  }

  Widget _buildHeader(EmoriColors c, TextTheme tt, int activeCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back to Chat',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminders', style: tt.headlineLarge),
                const SizedBox(height: 4),
                Text(
                  '$activeCount ${activeCount == 1 ? 'reminder' : 'reminders'} active',
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(EmoriColors c, TextTheme tt, int activeCount) {
    final groups = _groupReminders(_reminders);

    // Order sections
    const sectionOrder = [
      'Overdue',
      'Today',
      'Tomorrow',
      'This Week',
      'Later',
      'Completed',
    ];
    final orderedKeys = sectionOrder
        .where((k) => groups.containsKey(k))
        .toList();

    return Column(
      children: [
        _buildHeader(c, tt, activeCount),

        Expanded(
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: orderedKeys.length,
              itemBuilder: (context, index) {
                final label = orderedKeys[index];
                final items = groups[label]!;
                final isRecent =
                    label == 'Today' ||
                    label == 'Tomorrow' ||
                    label == 'Overdue';

                return ExpansionTile(
                  initiallyExpanded: isRecent || label == 'This Week',
                  tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: label == 'Overdue'
                              ? AppColors.coral
                              : c.textHint,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (label == 'Overdue'
                                      ? AppColors.coral
                                      : AppColors.primary)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items.length}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: label == 'Overdue'
                                ? AppColors.coral
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: items
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReminderCard(
                            reminder: r,
                            onDelete: () => _deleteReminder(r.id),
                            onComplete: () => _toggleComplete(r),
                          ),
                        ),
                      )
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
}

// ─── Reminder Card (matches _EntryCard style) ──────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onDelete;
  final VoidCallback onComplete;

  const _ReminderCard({
    required this.reminder,
    required this.onDelete,
    required this.onComplete,
  });

  String _relativeDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = due.difference(today).inDays;

    if (diff < 0) return '${-diff}d overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff <= 7) return 'In $diff days';
    return DateFormat('MMM d').format(dueDate);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCompleted = reminder.isCompleted;
    final isOverdue = !isCompleted && reminder.dueDate.isBefore(DateTime.now());

    return Dismissible(
      key: Key(reminder.id),
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
            'Delete this reminder?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          content: Text(
            'This reminder will be permanently removed.',
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
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: isCompleted ? null : onComplete,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border(
              bottom: BorderSide(
                color: isOverdue
                    ? AppColors.coral.withValues(alpha: 0.4)
                    : c.border,
                width: 1.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: type label + time
                Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle_outline
                          : isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_rounded,
                      size: 14,
                      color: isCompleted
                          ? AppColors.success
                          : isOverdue
                          ? AppColors.coral
                          : AppColors.teal,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isCompleted
                          ? 'COMPLETED'
                          : isOverdue
                          ? 'OVERDUE'
                          : 'REMINDER',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? AppColors.success
                            : isOverdue
                            ? AppColors.coral
                            : AppColors.teal,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _relativeDate(reminder.dueDate),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isOverdue ? AppColors.coral : c.textHint,
                        fontWeight: isOverdue
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Row(
                  children: [
                    if (!isCompleted) ...[
                      GestureDetector(
                        onTap: onComplete,
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isOverdue
                                  ? AppColors.coral
                                  : AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (isCompleted) ...[
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? c.textHint : c.textPrimary,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),

                // Description
                if (reminder.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      reminder.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.6,
                        color: c.textSecondary,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],

                // Date info
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
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
                        DateFormat('EEEE, MMMM d, y').format(reminder.dueDate),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
