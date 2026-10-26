import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/attendance_store.dart';
import '../attendance_design.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  String _photoBase64 = '';
  bool _isLoading = true;
  bool _isSaving = false;

  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _avatarScale;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _headerFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    _avatarScale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutBack),
    ));

    _formFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    ));

    _loadProfile();
    _entryController.forward();
  }

  Future<void> _loadProfile() async {
    final profile = await AttendanceStore.loadProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile.name;
      _idController.text = profile.employeeId;
      _roleController.text = profile.role;
      _deptController.text = profile.department;
      _photoBase64 = profile.photoBase64;
      _isLoading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _photoBase64 = base64Encode(bytes);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Profile photo captured successfully!'),
              ],
            ),
            backgroundColor: AttendanceColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final profile = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? 'Prinz Tsabio'
          : _nameController.text.trim(),
      employeeId: _idController.text.trim().isEmpty
          ? '8152'
          : _idController.text.trim(),
      role: _roleController.text.trim().isEmpty
          ? 'Mobile Architect'
          : _roleController.text.trim(),
      department: _deptController.text.trim().isEmpty
          ? 'Engineering'
          : _deptController.text.trim(),
      photoBase64: _photoBase64,
    );

    await AttendanceStore.saveProfile(profile);

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Profile saved & synced!'),
          ],
        ),
        backgroundColor: AttendanceColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _roleController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AttendanceColors.page,
      body: Stack(
        children: [
          // Aurora gradient header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340,
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
                // Animated Top App Bar
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
                                  'BIOMETRIC PROFILE',
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
                          // Save button with animated feedback
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Hero Photo Avatar with pulsing ring
                ScaleTransition(
                  scale: _avatarScale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated pulsing ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale =
                                1.0 + (_pulseController.value * 0.06);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.15 + _pulseController.value * 0.1),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Main avatar
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AttendanceColors.darkSurfaceElevated,
                            border:
                                Border.all(color: Colors.white, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: AttendanceColors.accent
                                    .withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _photoBase64.isNotEmpty
                                ? Image.memory(
                                    base64Decode(_photoBase64),
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    size: 54,
                                    color: Colors.white70,
                                  ),
                          ),
                        ),
                        // Camera capture button
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AttendanceColors.accent,
                                    AttendanceColors.accentCyan,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AttendanceColors.accent
                                        .withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Name display under avatar
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Column(
                      children: [
                        Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : 'Your Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _roleController.text.isNotEmpty
                              ? _roleController.text
                              : 'Set your role',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // White Form Sheet
                Expanded(
                  child: SlideTransition(
                    position: _formSlide,
                    child: FadeTransition(
                      opacity: _formFade,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AttendanceColors.card,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(36)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AttendanceColors.accent,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 28, 24, 110),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Section header
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: AttendanceColors.accent,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'EMPLOYEE DETAILS',
                                          style: TextStyle(
                                            color: AttendanceColors
                                                .secondaryText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    _ProfileInputField(
                                      label: 'Full Name',
                                      controller: _nameController,
                                      icon: Icons.person_outline_rounded,
                                      accentColor: const Color(0xFF6366F1),
                                    ),
                                    const SizedBox(height: 16),

                                    _ProfileInputField(
                                      label: 'Employee / Badge ID',
                                      controller: _idController,
                                      icon: Icons.badge_outlined,
                                      accentColor: const Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(height: 16),

                                    _ProfileInputField(
                                      label: 'Job Title / Role',
                                      controller: _roleController,
                                      icon: Icons.work_outline_rounded,
                                      accentColor: const Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(height: 16),

                                    // Department
                                    _ProfileInputField(
                                      label: 'Department',
                                      controller: _deptController,
                                      icon: Icons.business_outlined,
                                      accentColor: const Color(0xFF10B981),
                                    ),
                                    const SizedBox(height: 24),

                                    // Save Button
                                    AttendancePrimaryButton(
                                      label: _isSaving
                                          ? 'Saving Profile...'
                                          : 'Save Profile',
                                      loading: _isSaving,
                                      backgroundColor: AttendanceColors.text,
                                      foregroundColor: Colors.white,
                                      onPressed: _saveProfile,
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
      ),
    );
  }

  Widget _buildSaveButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AttendanceRadius.pill),
      child: InkWell(
        onTap: _saveProfile,
        borderRadius: BorderRadius.circular(AttendanceRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSaving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A refined input field with animated focus state & colored icon accent
class _ProfileInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final Color accentColor;

  const _ProfileInputField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<_ProfileInputField> createState() => _ProfileInputFieldState();
}

class _ProfileInputFieldState extends State<_ProfileInputField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: _isFocused
                ? widget.accentColor
                : AttendanceColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _isFocused
                ? widget.accentColor.withValues(alpha: 0.04)
                : AttendanceColors.softSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isFocused
                  ? widget.accentColor.withValues(alpha: 0.4)
                  : AttendanceColors.surfaceBorder,
              width: _isFocused ? 1.5 : 1.0,
            ),
          ),
          child: Focus(
            onFocusChange: (focused) =>
                setState(() => _isFocused = focused),
            child: TextField(
              controller: widget.controller,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AttendanceColors.text,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                prefixIcon: Container(
                  margin: const EdgeInsets.only(left: 12, right: 4),
                  child: Icon(
                    widget.icon,
                    color: _isFocused
                        ? widget.accentColor
                        : AttendanceColors.secondaryText,
                    size: 20,
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 42),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
