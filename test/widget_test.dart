import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/attendance_store.dart';
import 'package:attendance_app/ui/attendance_history/attendance_history_screen.dart';
import 'package:attendance_app/ui/absent/absent_screen.dart';
import 'package:attendance_app/ui/home_screen.dart';

Future<void> pumpFrame(WidgetTester tester) async {
  // The screens use endless animations (pulse rings, live clocks), so
  // pumpAndSettle never resolves — pump a few frames instead.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app opens directly to the home workspace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AttendanceApp());
    await pumpFrame(tester);

    expect(find.text('Activity Stream'), findsOneWidget);
  });

  testWidgets('home screen renders key sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await pumpFrame(tester);

    expect(find.text('Activity Stream'), findsOneWidget);
    expect(find.text('CHECK IN'), findsOneWidget);
    expect(find.text('CHECK OUT'), findsOneWidget);
  });

  testWidgets('history screen renders records', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AttendanceHistoryScreen()),
    );
    await pumpFrame(tester);

    expect(find.byType(AttendanceHistoryScreen), findsOneWidget);
  });

  testWidgets('leave screen renders request form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AbsentScreen()));
    await pumpFrame(tester);

    expect(find.text('Request Absence'), findsOneWidget);
  });

  test(
    'attendance store blocks duplicate check-ins for the same day',
    () async {
      // Use a future day so demo seed records (today / past days) never interfere
      final day = DateTime.now().add(const Duration(days: 100));
      final record = AttendanceRecord(
        id: 'first-checkin',
        title: 'Check in',
        status: 'On time',
        type: 'check_in',
        createdAt: day,
        location: 'Main Office - Entrance Gate',
        note: 'Recorded for validation',
      );

      expect(
        await AttendanceStore.addWithResult(record),
        AttendanceAddResult.saved,
      );
      expect(
        await AttendanceStore.addWithResult(record),
        AttendanceAddResult.duplicate,
      );
    },
  );

  test('attendance store enforces check-in before checkout', () async {
    final day = DateTime.now().add(const Duration(days: 101));
    final checkOut = AttendanceRecord(
      id: 'check-out-before-check-in',
      title: 'Check out',
      status: 'Completed',
      type: 'check_out',
      createdAt: day,
      location: 'Current Location',
      note: '',
    );

    expect(
      await AttendanceStore.addWithResult(checkOut),
      AttendanceAddResult.requiresCheckIn,
    );

    final checkIn = AttendanceRecord(
      id: 'check-in',
      title: 'Check in',
      status: 'On time',
      type: 'check_in',
      createdAt: day,
      location: 'Current Location',
      note: '',
    );
    expect(
      await AttendanceStore.addWithResult(checkIn),
      AttendanceAddResult.saved,
    );
    expect(
      await AttendanceStore.addWithResult(checkOut),
      AttendanceAddResult.saved,
    );
    expect(
      await AttendanceStore.addWithResult(
        AttendanceRecord(
          id: 'second-check-out',
          title: 'Check out',
          status: 'Completed',
          type: 'check_out',
          createdAt: day.add(const Duration(minutes: 1)),
          location: 'Current Location',
          note: '',
        ),
      ),
      AttendanceAddResult.duplicate,
    );
  });

  test('attendance store skips corrupted records', () async {
    SharedPreferences.setMockInitialValues({
      'attendance_records_v1': ['not-json'],
    });

    // Corrupted entries are ignored and the demo-safe dataset kicks in
    final records = await AttendanceStore.load();
    expect(records, isNotEmpty);
  });

  test('user profile round-trips through persistence', () async {
    const profile = UserProfile(
      name: 'Prinz Tsabio',
      employeeId: '8152',
      role: 'Lead Mobile Architect',
      department: 'Engineering',
      photoBase64: '',
    );

    await AttendanceStore.saveProfile(profile);
    final loaded = await AttendanceStore.loadProfile();

    expect(loaded.name, 'Prinz Tsabio');
    expect(loaded.employeeId, '8152');
  });
}
