import 'package:flutter/material.dart';

/// Conceptzilla Neo-Fintech & Modern iOS 2025 Theme System
/// Crisp, sharp, pixel-perfect contrast without blurry fog
abstract final class AttendanceColors {
  // Midnight Deep Dark Space (Solid & Crisp Minimalist)
  static const page = Color(0xFF090D14);
  static const darkSurface = Color(0xFF111722);
  static const darkSurfaceElevated = Color(0xFF18202F);
  static const darkBorder = Color(0x1FFFFFFF);

  // Soft/White Bottom Canvas
  static const card = Colors.white;
  static const softSurface = Color(0xFFF8FAFC);
  static const surfaceBorder = Color(0xFFE2E8F0);

  // Vibrant Neo Accents (Clean Apple/Conceptzilla Blue)
  static const accent = Color(0xFF2563EB);
  static const accentCyan = Color(0xFF38BDF8);
  static const accentPurple = Color(0xFF6366F1);
  static const softAccent = Color(0xFFEFF6FF);

  // Crisp High-Contrast Typography Hierarchy
  static const text = Color(0xFF0F172A);
  static const secondaryText = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // Status Colors
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const divider = Color(0xFFF1F5F9);

  // Ultra-Clean Minimalist Header Gradient (Smooth, crisp, no blur)
  static const LinearGradient neoAuroraGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF3B82F6),
      Color(0xFF1D4ED8),
      Color(0xFF0F172A),
      Color(0xFF090D14),
    ],
    stops: [0.0, 0.35, 0.75, 1.0],
  );

  static const LinearGradient cardAuroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3B82F6),
      Color(0xFF1D4ED8),
      Color(0xFF0F172A),
    ],
  );
}

abstract final class AttendanceSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AttendanceRadius {
  static const card = 28.0;
  static const compact = 18.0;
  static const pill = 100.0;
}

abstract final class AttendanceTypography {
  static const pageTitle = TextStyle(
    fontSize: 32,
    height: 1.12,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );
  static const sectionTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  static const buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const navigationLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

/// Smooth iOS-like slide & fade page route transition
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0.0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

abstract final class AttendanceTheme {
  static ThemeData get light {
    final textTheme = ThemeData.light().textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: AttendanceColors.text,
      displayColor: AttendanceColors.text,
    );
    final attendanceTextTheme = textTheme.copyWith(
      headlineLarge: AttendanceTypography.pageTitle,
      titleLarge: AttendanceTypography.sectionTitle,
      titleMedium: AttendanceTypography.cardTitle,
      bodyMedium: AttendanceTypography.body,
      bodySmall: AttendanceTypography.caption,
      labelLarge: AttendanceTypography.buttonLabel,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AttendanceColors.page,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AttendanceColors.accent,
        onPrimary: Colors.white,
        secondary: AttendanceColors.success,
        onSecondary: Colors.white,
        error: AttendanceColors.error,
        onError: Colors.white,
        surface: AttendanceColors.darkSurface,
        onSurface: Colors.white,
      ),
      textTheme: attendanceTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AttendanceColors.text,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AttendanceColors.darkSurfaceElevated,
        contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: StadiumBorder(),
      ),
    );
  }
}

/// Signature 8-point Conceptzilla Asterisk Logo / Symbol
class ConceptzillaAsterisk extends StatelessWidget {
  final double size;
  final Color color;

  const ConceptzillaAsterisk({
    super.key,
    this.size = 56,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AsteriskPainter(color: color),
    );
  }
}

class _AsteriskPainter extends CustomPainter {
  final Color color;
  _AsteriskPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.135
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.88;

    const angles = [0.0, 0.785398, 1.5708, 2.35619];
    for (final angle in angles) {
      final dx = radius * _cos(angle);
      final dy = radius * _sin(angle);
      canvas.drawLine(
        Offset(center.dx - dx, center.dy - dy),
        Offset(center.dx + dx, center.dy + dy),
        paint,
      );
    }
  }

  double _cos(double radians) => radians == 0.0
      ? 1.0
      : (radians == 1.5708 ? 0.0 : 0.707106);
  double _sin(double radians) => radians == 0.0
      ? 0.0
      : (radians == 1.5708 ? 1.0 : 0.707106);

  @override
  bool shouldRepaint(covariant _AsteriskPainter oldDelegate) =>
      oldDelegate.color != color;
}

class AttendanceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final Color? borderColor;
  final BoxBorder? customBorder;
  final List<BoxShadow>? shadows;

  const AttendanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AttendanceSpacing.md),
    this.color = AttendanceColors.card,
    this.radius = AttendanceRadius.card,
    this.borderColor,
    this.customBorder,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: customBorder ??
            (borderColor == null ? null : Border.all(color: borderColor!)),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

class AttendancePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AttendancePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.padding = const EdgeInsets.symmetric(vertical: 18),
    this.textStyle = AttendanceTypography.buttonLabel,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white;
    final fg = foregroundColor ?? AttendanceColors.text;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: padding,
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AttendanceRadius.pill),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              ),
              const SizedBox(width: AttendanceSpacing.xs),
            ],
            Text(label, style: textStyle.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

class AttendanceIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool dark;

  const AttendanceIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : AttendanceColors.text;
    final background = dark
        ? Colors.white.withValues(alpha: 0.12)
        : AttendanceColors.softSurface;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AttendanceRadius.pill),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AttendanceRadius.pill),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: foreground, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Floating Pill Navigation Bar mimicking the Conceptzilla iOS 2025 Bottom Bar
class AttendanceBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AttendanceBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (label: 'Home', icon: Icons.home_filled),
    (label: 'Scan', icon: Icons.filter_center_focus_rounded),
    (label: 'History', icon: Icons.receipt_long_rounded),
    (label: 'Leave', icon: Icons.description_outlined),
    (label: 'Profile', icon: Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AttendanceRadius.pill),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = index == currentIndex;

          return InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(AttendanceRadius.pill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 16 : 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: selected ? AttendanceColors.text : Colors.transparent,
                borderRadius: BorderRadius.circular(AttendanceRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.label == 'Scan')
                    ConceptzillaAsterisk(
                      size: 15,
                      color: selected ? Colors.white : AttendanceColors.secondaryText,
                    )
                  else
                    Icon(
                      item.icon,
                      size: 18,
                      color: selected ? Colors.white : AttendanceColors.secondaryText,
                    ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AttendanceSectionHeading extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  final bool onDark;

  const AttendanceSectionHeading({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailing,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AttendanceColors.text;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AttendanceTypography.sectionTitle.copyWith(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          InkWell(
            onTap: onTrailing,
            borderRadius: BorderRadius.circular(AttendanceRadius.compact),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AttendanceSpacing.xs,
                horizontal: AttendanceSpacing.xs,
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  color: AttendanceColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
