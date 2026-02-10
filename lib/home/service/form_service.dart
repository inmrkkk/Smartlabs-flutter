import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../form_page.dart';
import 'notification_service.dart';
import 'laboratory_service.dart';
import 'borrow_history_service.dart';

class FormService {
  Future<DateTime?> selectDate(
    BuildContext context,
    bool isStartDate,
    DateTime? currentStartDate,
    DateTime? currentEndDate,
  ) async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> submitBorrowRequest({
    required BorrowFormPage widget,
    required String itemNo,
    required Laboratory laboratory,
    required int quantity,
    required DateTime dateToBeUsed,
    required DateTime dateToReturn,
    required String adviserName,
    String? signature,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Check if user is a teacher/instructor
    final userRole = await _getUserRole(user.uid);
    final isTeacher = userRole == 'teacher';

    String? adviserId;
    String? adviserNameFinal;

    if (isTeacher) {
      // For teachers, use their own ID as adviser and auto-approve
      adviserId = user.uid;
      adviserNameFinal =
          await _getUserName(user.uid) ?? user.email ?? 'Instructor';
    } else {
      // For students, find the selected adviser
      adviserId = await _findAdviserIdByName(adviserName);
      if (adviserId == null) {
        throw Exception('Instructor not found');
      }
      adviserNameFinal = adviserName;
    }

    // Set status: 'approved' for teachers, 'pending' for students
    final status = isTeacher ? 'approved' : 'pending';

    final borrowRequestData = <String, dynamic>{
      'userId': user.uid,
      'userEmail': user.email,
      'itemId': widget.itemId,
      'categoryId': widget.categoryId,
      'itemName': widget.itemName,
      'categoryName': widget.categoryName,
      'itemNo': itemNo,
      'laboratory':
          laboratory.labName, // Display name for backward compatibility
      'labId': laboratory.labId, // Lab code (e.g., "LAB001")
      'labRecordId': laboratory.id, // Firebase record ID
      'quantity': quantity,
      'dateToBeUsed': dateToBeUsed.toIso8601String(),
      'dateToReturn': dateToReturn.toIso8601String(),
      'adviserName': adviserNameFinal,
      'adviserId': adviserId,
      'status': status,
      'requestedAt': DateTime.now().toIso8601String(),
      if (signature != null) 'signature': signature,
      if (isTeacher) 'processedAt': DateTime.now().toIso8601String(),
      if (isTeacher) 'processedBy': user.uid,
    };

    final borrowRef =
        FirebaseDatabase.instance.ref().child('borrow_requests').push();
    final requestId = borrowRef.key!;

    borrowRequestData['requestId'] = requestId;

    final List<Future> tasks = [
      // Store request under /borrow_requests
      borrowRef.set(borrowRequestData),
    ];

    if (isTeacher) {
      // Archive to history storage for association rule mining
      // Note: Only batch requests (with batchId) are archived
      // Single requests from form_service don't have batchId, so they won't be archived
      tasks.add(
        BorrowHistoryService.archiveApprovedRequest(
          requestId,
          borrowRequestData,
        ),
      );

      // Send confirmation notification to instructor
      tasks.add(
        NotificationService.sendNotificationToUser(
          userId: user.uid,
          title: 'Request Approved',
          message:
              'Your request for ${widget.itemName} has been automatically approved.',
          type: 'success',
          additionalData: {
            'requestId': requestId,
            'itemName': widget.itemName,
            'status': 'approved',
          },
        ),
      );
    } else {
      // For students: Send notification to instructor
      final studentName = await _getUserName(user.uid) ?? user.email;
      tasks.add(
        NotificationService.sendNotificationToUser(
          userId: adviserId,
          title: 'New Borrow Request',
          message: '$studentName has requested to borrow ${widget.itemName}',
          type: 'info',
          additionalData: {
            'requestId': requestId,
            'itemName': widget.itemName,
            'studentEmail': user.email,
            'requestedAt': borrowRequestData['requestedAt'],
          },
        ),
      );

      // Send confirmation notification to student
      tasks.add(
        NotificationService.sendNotificationToUser(
          userId: user.uid,
          title: 'Request Submitted',
          message:
              'Your request for ${widget.itemName} has been submitted and is pending approval.',
          type: 'success',
          additionalData: {
            'requestId': requestId,
            'itemName': widget.itemName,
            'adviserName': adviserNameFinal,
          },
        ),
      );
    }

    await Future.wait(tasks);
  }

  /// Get user role from database
  Future<String?> _getUserRole(String userId) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(userId)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return data['role'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  /// Get user name from database
  Future<String?> _getUserName(String userId) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(userId)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return data['name'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user name: $e');
      return null;
    }
  }

  Future<String?> _findAdviserIdByName(String adviserName) async {
    try {
      final DatabaseReference usersRef = FirebaseDatabase.instance.ref().child(
        'users',
      );
      final DatabaseEvent event = await usersRef.once();

      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> usersData =
            event.snapshot.value as Map<dynamic, dynamic>;

        for (final entry in usersData.entries) {
          final userData = entry.value;
          if (userData is Map &&
              userData['role'] == 'teacher' &&
              userData['name'] == adviserName) {
            return entry.key;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error finding adviser: $e');
      return null;
    }
  }
}
