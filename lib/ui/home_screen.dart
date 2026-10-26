import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/attendance_store.dart';
import 'attendance_design.dart';
import 'attend/attend_screen.dart';
import 'navigation_shell.dart';

/// Standalone Screen for backward compatibility
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationShell(initialIndex: 0);
  }
}

/// Rich HomeScreen Content with Multi-Card Carousel, Real-time Clock & Live Geofence
class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _loadError;
  List<AttendanceRecord> _records = const [];
  UserProfile? _profile;
  final PageController _carouselController = PageController(viewportFraction: 0.92);
  int _carouselIndex = 0;

  late final AnimationController _cardAnimController;
  late final Animation<double> _cardPulseAnim;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _cardPulseAnim = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeInOutSine),
    );

    _loadData();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final records = await AttendanceStore.load();
      final profile = await AttendanceStore.loadProfile();
      if (!mounted) return;
      setState(() {
        _records = records;
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load records: $e';
        _loading = false;
      });
    }
  }

  void _openAttendance(AttendanceAction action) {
    Navigator.push(
      context,
      SmoothPageRoute(page: AttendScreen(action: action)),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayRecords = _records.where((r) =>
        r.createdAt.year == now.year &&
        r.createdAt.month == now.month &&
        r.createdAt.day == now.day).toList();

    final checkIns = todayRecords.where((r) => r.type == 'check_in').toList();
    final checkOuts = todayRecords.where((r) => r.type == 'check_out').toList();

    final checkInTime = checkIns.isEmpty ? '—' : DateFormat('HH:mm').format(checkIns.first.createdAt);
    final checkOutTime = checkOuts.isEmpty ? '—' : DateFormat('HH:mm').format(checkOuts.first.createdAt);

    final userName = _profile?.name ?? 'Prinz Tsabio';
    final userRole = _profile?.role ?? 'Senior Mobile Engineer';
    final userBadge = _profile?.employeeId ?? '8152';

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 380,
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
              // Header Row: Search Pill & User Chip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AttendanceRadius.pill),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded, size: 17, color: Colors.white70),
                            SizedBox(width: 8),
                            Text(
                              'Search activity & logs...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AttendanceRadius.pill),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.white24,
                            child: _profile != null && _profile!.photoBase64.isNotEmpty
                                ? ClipOval(
                                    child: Image.memory(
                                      base64Decode(_profile!.photoBase64),
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.person_rounded, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            userName.split(' ').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Shift and Geofence Tags
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Row(
                  children: [
                    _buildTopStatusBadge('SHIFT', '09:00 - 18:00', Colors.cyanAccent),
                    const SizedBox(width: 8),
                    _buildTopStatusBadge('GEOFENCE', 'Cyber 2 Tower (In-Zone)', const Color(0xFF34D399)),
                  ],
                ),
              ),

              // Hero Clock & Live Virtual Badge
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, d MMM yyyy').format(now).toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, snapshot) {
                            return Text(
                              DateFormat('HH:mm').format(DateTime.now()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                                height: 1.05,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ConceptzillaAsterisk(size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID #$userBadge',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                userRole,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Tiles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.login_rounded,
                        label: 'CHECK IN',
                        accent: const Color(0xFF2563EB),
                        onTap: () => _openAttendance(AttendanceAction.checkIn),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.logout_rounded,
                        label: 'CHECK OUT',
                        accent: const Color(0xFF0F172A),
                        onTap: () => _openAttendance(AttendanceAction.checkOut),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.free_breakfast_rounded,
                        label: 'BREAK',
                        accent: const Color(0xFFF59E0B),
                        onTap: () => _openAttendance(AttendanceAction.breakAction),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.more_horiz_rounded,
                        label: 'OVERTIME',
                        accent: const Color(0xFF8B5CF6),
                        onTap: () => _openAttendance(AttendanceAction.overtime),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Bottom White Sheet
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AttendanceColors.card,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Carousel Showcase
                        ScaleTransition(
                          scale: _cardPulseAnim,
                          child: SizedBox(
                            height: 204,
                            child: PageView(
                              controller: _carouselController,
                              onPageChanged: (i) => setState(() => _carouselIndex = i),
                              children: [
                                _buildVirtualBadgeCard(userBadge, checkInTime, checkOutTime),
                                _buildOfficePerformanceCard(todayRecords.length),
                                _buildBiometricSecurityCard(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Dots
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              final active = index == _carouselIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: active ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active ? AttendanceColors.text : AttendanceColors.divider,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 22),

                        AttendanceSectionHeading(
                          title: 'Activity Stream',
                          trailing: 'Live feed',
                          onTrailing: _loadData,
                        ),

                        const SizedBox(height: 14),

                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_loadError != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AttendanceColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(_loadError!, style: const TextStyle(color: AttendanceColors.error)),
                          )
                        else if (_records.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  Icon(Icons.history_rounded, size: 40, color: AttendanceColors.textMuted.withValues(alpha: 0.5)),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No attendance records yet',
                                    style: TextStyle(
                                      color: AttendanceColors.secondaryText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _records.take(6).length,
                            separatorBuilder: (context, index) => const Divider(
                              color: AttendanceColors.divider,
                              height: 18,
                            ),
                            itemBuilder: (context, index) {
                              final item = _records[index];
                              return _buildActivityRow(item);
                            },
                          ),
                      ],
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

  Widget _buildTopStatusBadge(String prefix, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AttendanceRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$prefix • $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AttendanceColors.surfaceBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AttendanceColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualBadgeCard(String badgeId, String inTime, String outTime) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AttendanceColors.cardAuroraGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '•••• $badgeId',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ATTENDANCE PASS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Center(
            child: ConceptzillaAsterisk(size: 48, color: Colors.white),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IN TIME', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9.5, fontWeight: FontWeight.w700)),
                  Text(inTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OUT TIME', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9.5, fontWeight: FontWeight.w700)),
                  Text(outTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contactless_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficePerformanceCard(int activitiesCount) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AttendanceColors.darkSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('WORK PRODUCTIVITY', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AttendanceColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('100% ON TARGET', style: TextStyle(color: AttendanceColors.success, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('8h 30m', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const Text('Effective Shift Time Today', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 6),
              Text('$activitiesCount attendance checkpoints verified', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricSecurityCard() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BIOMETRIC SECURITY', style: TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Icon(Icons.shield_rounded, color: Colors.cyanAccent, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          const Text('99.4% Match', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const Text('Neural Anti-Spoofing Active', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const Spacer(),
          const Text('Face verification registered & bound to device', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActivityRow(AttendanceRecord item) {
    final isCheckIn = item.type == 'check_in';
    final isLeave = item.type == 'leave';

    final Color badgeBg = isCheckIn
        ? const Color(0xFFE8F5E9)
        : (isLeave ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD));
    final Color badgeText = isCheckIn
        ? AttendanceColors.success
        : (isLeave ? AttendanceColors.warning : AttendanceColors.accent);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AttendanceColors.softSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isCheckIn
                ? Icons.login_rounded
                : (isLeave ? Icons.description_rounded : Icons.logout_rounded),
            color: AttendanceColors.text,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AttendanceColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('HH:mm').format(item.createdAt)} • ${item.location}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AttendanceColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(AttendanceRadius.pill),
          ),
          child: Text(
            item.status.toUpperCase(),
            style: TextStyle(
              color: badgeText,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
