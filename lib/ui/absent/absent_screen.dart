import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_store.dart';
import '../attendance_design.dart';

class AbsentScreen extends StatelessWidget {
  const AbsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF070B12),
      body: AbsentContent(),
    );
  }
}

class AbsentContent extends StatefulWidget {
  const AbsentContent({super.key});

  @override
  State<AbsentContent> createState() => _AbsentContentState();
}

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}

class _AbsentContentState extends State<AbsentContent> with SingleTickerProviderStateMixin {
  final TextEditingController _reasonController = TextEditingController();
  late DateTime _selectedDate;
  String _selectedType = 'Sick Leave';
  bool _isSubmitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<_CategoryData> _categories = [
    _CategoryData(
      title: 'Sick Leave',
      subtitle: 'Medical rest or medical recovery',
      icon: Icons.healing_rounded,
      accent: Color(0xFF38BDF8),
    ),
    _CategoryData(
      title: 'Annual Leave',
      subtitle: 'Personal time off & annual holidays',
      icon: Icons.beach_access_rounded,
      accent: Color(0xFF34D399),
    ),
    _CategoryData(
      title: 'Emergency / Permit',
      subtitle: 'Urgent family or personal affairs',
      icon: Icons.priority_high_rounded,
      accent: Color(0xFFFBBF24),
    ),
    _CategoryData(
      title: 'Work From Home',
      subtitle: 'Remote work assignment approval',
      icon: Icons.home_work_rounded,
      accent: Color(0xFFA78BFA),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Color(0xFF131B2A),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF131B2A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitLeave() async {
    if (_isSubmitting) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showFeedbackDialog(
        isSuccess: false,
        title: 'Reason Required',
        message: 'Please provide a clear justification for your leave request.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final profile = await AttendanceStore.loadProfile();
    final formattedDate = DateFormat('dd MMM yyyy').format(_selectedDate);

    final record = AttendanceRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title: '$_selectedType ($formattedDate)',
      status: 'Submitted',
      type: 'leave',
      createdAt: now,
      location: 'Online â€¢ ${profile.name}',
      note: reason,
    );

    try {
      await AttendanceStore.add(record);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _reasonController.clear();
      });
      _showFeedbackDialog(
        isSuccess: true,
        title: 'Request Submitted',
        message: 'Your leave application has been logged for HR review and processing.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showFeedbackDialog(
        isSuccess: false,
        title: 'Submission Error',
        message: 'Could not record leave request: $e',
      );
    }
  }

  void _showFeedbackDialog({
    required bool isSuccess,
    required String title,
    required String message,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LeaveFeedback',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141B2D),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSuccess ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Understand',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 330,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AttendanceRadius.pill),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConceptzillaAsterisk(size: 13, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'LEAVE & PERMITS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AttendanceRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'HR Portal Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Absence',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submit formal leave or WFH notification for swift HR validation.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AttendanceColors.card,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.category_rounded, size: 16, color: AttendanceColors.secondaryText),
                                SizedBox(width: 6),
                                Text(
                                  'LEAVE CATEGORY',
                                  style: TextStyle(
                                    color: AttendanceColors.secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Column(
                              children: [
                                for (final category in _categories)
                                  Builder(
                                    builder: (context) {
                                      final isSelected = category.title == _selectedType;
                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedType = category.title),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 240),
                                          curve: Curves.easeOutCubic,
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF0F172A) : AttendanceColors.softSurface,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(
                                              color: isSelected ? Colors.transparent : AttendanceColors.surfaceBorder,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: isSelected ? category.accent.withValues(alpha: 0.2) : Colors.white,
                                                  borderRadius: BorderRadius.circular(13),
                                                ),
                                                child: Icon(
                                                  category.icon,
                                                  color: isSelected ? category.accent : AttendanceColors.text,
                                                  size: 21,
                                                ),
                                              ),
                                              const SizedBox(width: 13),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      category.title,
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.white : AttendanceColors.text,
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      category.subtitle,
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.white.withValues(alpha: 0.65) : AttendanceColors.textMuted,
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: isSelected ? Colors.white : Colors.transparent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSelected ? Colors.white : AttendanceColors.surfaceBorder,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: isSelected
                                                    ? const Icon(
                                                        Icons.check_rounded,
                                                        color: Color(0xFF0F172A),
                                                        size: 13,
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            const Row(
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 16, color: AttendanceColors.secondaryText),
                                SizedBox(width: 6),
                                Text(
                                  'EFFECTIVE DATE',
                                  style: TextStyle(
                                    color: AttendanceColors.secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                                decoration: BoxDecoration(
                                  color: AttendanceColors.softSurface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AttendanceColors.surfaceBorder),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AttendanceColors.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.event_available_rounded,
                                        color: AttendanceColors.accent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Selected Date',
                                            style: TextStyle(
                                              color: AttendanceColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formattedDate,
                                            style: const TextStyle(
                                              color: AttendanceColors.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.edit_calendar_rounded,
                                      color: AttendanceColors.secondaryText,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            const Row(
                              children: [
                                Icon(Icons.edit_note_rounded, size: 16, color: AttendanceColors.secondaryText),
                                SizedBox(width: 6),
                                Text(
                                  'REASON & JUSTIFICATION',
                                  style: TextStyle(
                                    color: AttendanceColors.secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Container(
                              decoration: BoxDecoration(
                                color: AttendanceColors.softSurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AttendanceColors.surfaceBorder),
                              ),
                              child: TextField(
                                controller: _reasonController,
                                maxLines: 4,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'Detail your reason, hospital notes, or work delivery plan...',
                                  hintStyle: TextStyle(
                                    color: AttendanceColors.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(18),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            AttendancePrimaryButton(
                              label: _isSubmitting ? 'Submitting Application...' : 'Submit Leave Request',
                              loading: _isSubmitting,
                              backgroundColor: AttendanceColors.text,
                              foregroundColor: Colors.white,
                              onPressed: _submitLeave,
                            ),
                          ],
                        ),
                      ),
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
}
