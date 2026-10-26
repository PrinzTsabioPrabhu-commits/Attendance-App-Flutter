import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_store.dart';
import '../attendance_design.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AttendanceColors.page,
      body: AttendanceHistoryContent(),
    );
  }
}

class AttendanceHistoryContent extends StatefulWidget {
  const AttendanceHistoryContent({super.key});

  @override
  State<AttendanceHistoryContent> createState() =>
      _AttendanceHistoryContentState();
}

class _AttendanceHistoryContentState extends State<AttendanceHistoryContent>
    with TickerProviderStateMixin {
  bool _loading = true;
  final bool _newestFirst = true;
  String? _loadError;
  DateTime _selectedDate = DateTime.now();
  List<AttendanceRecord> _records = const [];
  String _activeFilter = 'All';

  late final AnimationController _entryController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _kpiFade;
  late final Animation<double> _sheetFade;
  late final Animation<Offset> _sheetSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    ));

    _kpiFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );

    _sheetFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));

    _entryController.forward();
    _loadRecords();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final records = await AttendanceStore.load();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load records: $error';
        _loading = false;
      });
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    var list = _records.where((record) {
      final matchesDate = record.createdAt.year == _selectedDate.year &&
          record.createdAt.month == _selectedDate.month &&
          record.createdAt.day == _selectedDate.day;
      if (!matchesDate) return false;
      if (_activeFilter == 'Check In') return record.type == 'check_in';
      if (_activeFilter == 'Check Out') return record.type == 'check_out';
      if (_activeFilter == 'Leave') return record.type == 'leave';
      return true;
    }).toList();

    list.sort(
      (a, b) => _newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return list;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AttendanceColors.accent,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AttendanceColors.text,
          ),
        ),
        child: child!,
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayRecords = _filteredRecords;
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    // Monthly Analytics
    final currentMonthRecords = _records
        .where((r) =>
            r.createdAt.month == _selectedDate.month &&
            r.createdAt.year == _selectedDate.year)
        .toList();
    final totalOntime = currentMonthRecords
        .where((r) => r.status.toLowerCase().contains('time'))
        .length;
    final totalLeaves =
        currentMonthRecords.where((r) => r.type == 'leave').length;

    return Stack(
      children: [
        // Background gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 360,
          child: Container(
            decoration: const BoxDecoration(
              gradient: AttendanceColors.neoAuroraGradient,
            ),
          ),
        ),

        SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Animated Header
              SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius:
                                BorderRadius.circular(AttendanceRadius.pill),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Row(
                            children: [
                              ConceptzillaAsterisk(
                                  size: 14, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'AUDIT LOGS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            // Date display chip
                            GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                      AttendanceRadius.pill),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      isToday
                                          ? 'Today'
                                          : DateFormat('d MMM')
                                              .format(_selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // KPI Monthly Summary
              FadeTransition(
                opacity: _kpiFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        _buildKpiTile(
                          icon: Icons.receipt_long_rounded,
                          value: '${currentMonthRecords.length}',
                          label: 'Total',
                          color: Colors.white,
                        ),
                        _buildKpiDivider(),
                        _buildKpiTile(
                          icon: Icons.check_circle_outline_rounded,
                          value: '$totalOntime',
                          label: 'On Time',
                          color: Colors.greenAccent,
                        ),
                        _buildKpiDivider(),
                        _buildKpiTile(
                          icon: Icons.event_busy_rounded,
                          value: '$totalLeaves',
                          label: 'Permits',
                          color: Colors.orangeAccent,
                        ),
                        _buildKpiDivider(),
                        _buildKpiTile(
                          icon: Icons.today_rounded,
                          value: '${dayRecords.length}',
                          label: 'Today',
                          color: AttendanceColors.accentCyan,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Filter Chips with animated selection
              FadeTransition(
                opacity: _kpiFade,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: ['All', 'Check In', 'Check Out', 'Leave']
                        .map((tab) {
                      final isSel = tab == _activeFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _activeFilter = tab),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                  AttendanceRadius.pill),
                              border: Border.all(
                                color: isSel
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: isSel
                                    ? AttendanceColors.text
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Content Sheet
              Expanded(
                child: SlideTransition(
                  position: _sheetSlide,
                  child: FadeTransition(
                    opacity: _sheetFade,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AttendanceColors.card,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(36)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AttendanceColors.accent,
                                strokeWidth: 2.5,
                              ),
                            )
                          : _loadError != null
                              ? _buildErrorState()
                              : dayRecords.isEmpty
                                  ? _buildEmptyState()
                                  : _buildRecordsList(dayRecords),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AttendanceColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 40, color: AttendanceColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AttendanceColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadRecords,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AttendanceColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AttendanceColors.softSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AttendanceColors.surfaceBorder,
                ),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 44,
                color: AttendanceColors.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Records Found',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AttendanceColors.text,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No attendance logs for ${DateFormat('d MMMM yyyy').format(_selectedDate)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AttendanceColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AttendanceColors.accent.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AttendanceRadius.pill),
                  border: Border.all(
                    color: AttendanceColors.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        size: 16, color: AttendanceColors.accent),
                    SizedBox(width: 8),
                    Text(
                      'Pick another date',
                      style: TextStyle(
                        color: AttendanceColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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

  Widget _buildRecordsList(List<AttendanceRecord> dayRecords) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      itemCount: dayRecords.length,
      itemBuilder: (context, index) {
        final item = dayRecords[index];
        return _HistoryRecordCard(
          record: item,
          index: index,
        );
      },
    );
  }
}

/// Individual record card with type-based theming
class _HistoryRecordCard extends StatelessWidget {
  final AttendanceRecord record;
  final int index;

  const _HistoryRecordCard({
    required this.record,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isCheckIn = record.type == 'check_in';
    final isLeave = record.type == 'leave';

    // Type-based colors
    final Color iconBg;
    final Color iconColor;
    final Color statusBg;
    final Color statusColor;
    final IconData typeIcon;

    if (isCheckIn) {
      iconBg = const Color(0xFFE8F5E9);
      iconColor = AttendanceColors.success;
      statusBg = const Color(0xFFE8F5E9);
      statusColor = AttendanceColors.success;
      typeIcon = Icons.login_rounded;
    } else if (isLeave) {
      iconBg = const Color(0xFFFFF3E0);
      iconColor = AttendanceColors.warning;
      statusBg = const Color(0xFFFFF3E0);
      statusColor = AttendanceColors.warning;
      typeIcon = Icons.description_rounded;
    } else {
      iconBg = const Color(0xFFE3F2FD);
      iconColor = AttendanceColors.accent;
      statusBg = const Color(0xFFE3F2FD);
      statusColor = AttendanceColors.accent;
      typeIcon = Icons.logout_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AttendanceColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(typeIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Title & time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AttendanceColors.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('HH:mm:ss • EEEE, d MMM')
                            .format(record.createdAt),
                        style: const TextStyle(
                          color: AttendanceColors.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius:
                        BorderRadius.circular(AttendanceRadius.pill),
                  ),
                  child: Text(
                    record.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            // Location row
            if (record.location.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AttendanceColors.softSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14,
                        color: AttendanceColors.accentCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.location,
                        style: const TextStyle(
                          color: AttendanceColors.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Note row
            if (record.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 14,
                    color: AttendanceColors.secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.note,
                      style: const TextStyle(
                        color: AttendanceColors.textMuted,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
