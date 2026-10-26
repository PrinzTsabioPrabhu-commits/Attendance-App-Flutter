import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum AttendanceAddResult {
  saved,
  duplicate,
  requiresCheckIn,
  alreadyCheckedOut,
  checkOutRequired,
}

/// User profile model supporting international enterprise standard
class UserProfile {
  final String name;
  final String employeeId;
  final String role;
  final String department;
  final String photoBase64; // Optional profile photo base64

  const UserProfile({
    required this.name,
    required this.employeeId,
    required this.role,
    required this.department,
    required this.photoBase64,
  });

  UserProfile copyWith({
    String? name,
    String? employeeId,
    String? role,
    String? department,
    String? photoBase64,
  }) {
    return UserProfile(
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      department: department ?? this.department,
      photoBase64: photoBase64 ?? this.photoBase64,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'employeeId': employeeId,
    'role': role,
    'department': department,
    'photoBase64': photoBase64,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name']?.toString() ?? 'Prinz Tsabio',
      employeeId: json['employeeId']?.toString() ?? '8152',
      role: json['role']?.toString() ?? 'Lead Mobile Architect',
      department: json['department']?.toString() ?? 'Engineering',
      photoBase64: json['photoBase64']?.toString() ?? '',
    );
  }
}

/// Attendance record model with biometric match confidence and audit trail
class AttendanceRecord {
  final String id;
  final String title;
  final String status;
  final String type;
  final DateTime createdAt;
  final String location;
  final String note;
  final double biometricConfidence;
  final String? verificationBadge;

  const AttendanceRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.location,
    required this.note,
    this.biometricConfidence = 0.984,
    this.verificationBadge = 'Biometric Verified',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
    'location': location,
    'note': note,
    'biometricConfidence': biometricConfidence,
    'verificationBadge': verificationBadge,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    if (createdAtRaw is! String) {
      throw const FormatException('Record is missing its timestamp.');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('Record timestamp is invalid.');
    }
    return AttendanceRecord(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Attendance',
      status: json['status']?.toString() ?? 'On time',
      type: json['type']?.toString() ?? 'check_in',
      createdAt: createdAt,
      location: json['location']?.toString() ?? 'Location unavailable',
      note: json['note']?.toString() ?? '',
      biometricConfidence: (json['biometricConfidence'] as num?)?.toDouble() ?? 0.98,
      verificationBadge: json['verificationBadge']?.toString() ?? 'Biometric Verified',
    );
  }
}

/// Robust Enterprise Attendance & Profile Store with SharedPreferences persistence,
/// atomic reads, fallback data safety, and validation guards.
class AttendanceStore {
  static const _key = 'attendance_records_v1';
  static const _profileKey = 'user_profile_v1';

  /// Load user profile with safe defaults and robust exception handling
  static Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) {
      return const UserProfile(
        name: 'Prinz Tsabio',
        employeeId: '8152',
        role: 'Senior Mobile Engineer',
        department: 'Product & Tech',
        photoBase64: '',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UserProfile.fromJson(decoded);
      }
      return const UserProfile(
        name: 'Prinz Tsabio',
        employeeId: '8152',
        role: 'Senior Mobile Engineer',
        department: 'Product & Tech',
        photoBase64: '',
      );
    } catch (_) {
      return const UserProfile(
        name: 'Prinz Tsabio',
        employeeId: '8152',
        role: 'Senior Mobile Engineer',
        department: 'Product & Tech',
        photoBase64: '',
      );
    }
  }

  /// Save or update profile
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Load attendance records
  static Future<List<AttendanceRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];

    final records = <AttendanceRecord>[];
    for (var index = 0; index < raw.length; index++) {
      try {
        final decoded = jsonDecode(raw[index]);
        if (decoded is! Map<String, dynamic>) continue;
        records.add(AttendanceRecord.fromJson(decoded));
      } catch (_) {}
    }

    // Populate with demo records on fresh install if empty
    if (records.isEmpty) {
      final now = DateTime.now();
      records.addAll([
        AttendanceRecord(
          id: '1',
          title: 'Check In',
          status: 'On Time',
          type: 'check_in',
          createdAt: DateTime(now.year, now.month, now.day - 3, 8, 45),
          location: 'Cyber 2 Tower, Kuningan, Jakarta Selatan',
          note: 'Biometric Face Match: 98.4%',
          biometricConfidence: 0.984,
          verificationBadge: 'Verified L1',
        ),
        AttendanceRecord(
          id: '2',
          title: 'Break',
          status: 'Completed',
          type: 'break',
          createdAt: DateTime(now.year, now.month, now.day - 3, 12, 10),
          location: 'Cyber 2 Tower, Kuningan, Jakarta Selatan',
          note: 'Lunch break verified',
          biometricConfidence: 0.975,
          verificationBadge: 'Verified',
        ),
        AttendanceRecord(
          id: '3',
          title: 'Check In',
          status: 'On Time',
          type: 'check_in',
          createdAt: DateTime(now.year, now.month, now.day - 1, 8, 52),
          location: 'Cyber 2 Tower, Kuningan, Jakarta Selatan',
          note: 'Biometric Face Match: 99.1%',
          biometricConfidence: 0.991,
          verificationBadge: 'Verified L1',
        ),
        AttendanceRecord(
          id: '4',
          title: 'Check Out',
          status: 'Completed',
          type: 'check_out',
          createdAt: DateTime(now.year, now.month, now.day - 1, 18, 05),
          location: 'Cyber 2 Tower, Kuningan, Jakarta Selatan',
          note: 'Daily checkout confirmed',
          biometricConfidence: 0.988,
          verificationBadge: 'Verified L1',
        ),
        AttendanceRecord(
          id: '5',
          title: 'Work From Home',
          status: 'Approved',
          type: 'leave',
          createdAt: DateTime(now.year, now.month, now.day - 2, 9, 00),
          location: 'Remote Work • Verified IP',
          note: 'Sprint Planning & Architecture Review',
          biometricConfidence: 1.0,
          verificationBadge: 'Authorized',
        ),
      ]);
      await save(records);
    }

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// Save attendance records with atomic write
  static Future<void> save(List<AttendanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = records.map((entry) => jsonEncode(entry.toJson())).toList(growable: false);
    await prefs.setStringList(_key, payload);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Append new attendance record
  static Future<void> add(AttendanceRecord record) async {
    final records = await load();
    records.insert(0, record);
    await save(records);
  }

  /// Enterprise guard logic to enforce daily attendance integrity.
  ///
  /// Status hari ini diperiksa kronologis per SESI:
  ///   sesi baru dibuka oleh Check In dan ditutup oleh Check Out.
  ///  - Check In  : hanya boleh jika TIDAK ada sesi terbuka (harus Check Out
  ///                dulu sebelum Check In lagi).
  ///  - Check Out : hanya boleh jika ada sesi terbuka (sudah Check In).
  ///  - Break / Overtime : maksimal 1x per sesi terbuka.
  static Future<AttendanceAddResult> addWithResult(AttendanceRecord record) async {
    final records = await load();
    final todayRecords =
        records.where((existing) => _isSameDay(existing.createdAt, record.createdAt)).toList();

    // Rekonstruksi keadaan sesi secara kronologis
    final events = todayRecords.map((r) {
      return MapEntry(r.createdAt.millisecondsSinceEpoch, r.type);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    bool sessionOpen = false;
    bool breakUsed = false;
    bool overtimeUsed = false;

    for (final event in events) {
      switch (event.value) {
        case 'check_in':
          sessionOpen = true;
          breakUsed = false;
          overtimeUsed = false;
        case 'check_out':
          sessionOpen = false;
          breakUsed = false;
          overtimeUsed = false;
        case 'break':
          if (sessionOpen) breakUsed = true;
        case 'overtime':
          if (sessionOpen) overtimeUsed = true;
      }
    }

    switch (record.type) {
      case 'check_in':
        if (sessionOpen) return AttendanceAddResult.checkOutRequired;
      case 'check_out':
        if (!sessionOpen) {
          return AttendanceAddResult.requiresCheckIn;
        }
      case 'break':
        if (!sessionOpen) return AttendanceAddResult.requiresCheckIn;
        if (breakUsed) return AttendanceAddResult.duplicate;
      case 'overtime':
        if (!sessionOpen) return AttendanceAddResult.requiresCheckIn;
        if (overtimeUsed) return AttendanceAddResult.duplicate;
    }

    records.insert(0, record);
    await save(records);
    return AttendanceAddResult.saved;
  }

  /// Delete a record by ID
  static Future<void> delete(String id) async {
    final records = await load();
    records.removeWhere((record) => record.id != id);
    await save(records);
  }

  /// Reset all stored data (Development & Admin testing)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_profileKey);
  }
}
