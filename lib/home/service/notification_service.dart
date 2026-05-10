import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _database = FirebaseDatabase.instance;

  // Send notification to a specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final notificationRef =
          _database.ref().child('notifications').child(userId).push();

      final notificationData = {
        'title': title,
        'message': message,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      await notificationRef.set(notificationData);
    } catch (e) {
      debugPrint('Error sending notification: $e');
      rethrow;
    }
  }

  // Send system-wide notification
  static Future<void> sendSystemNotification({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final notificationRef =
          _database.ref().child('system_notifications').push();

      final notificationData = {
        'title': title,
        'message': message,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      await notificationRef.set(notificationData);
    } catch (e) {
      debugPrint('Error sending system notification: $e');
      rethrow;
    }
  }

  // Send notification when request status changes
  static Future<void> notifyRequestStatusChange({
    required String userId,
    required String requestId,
    required String itemName,
    required String status,
    String? reason,
    String? rejectedByName,
    String? rejectedByRole,
    String? laboratory,
  }) async {
    String title;
    String message;
    String type;

    switch (status) {
      case 'approved':
        title = 'Request Approved';
        message = 'Your request for $itemName has been approved.';
        type = 'success';
        break;
      case 'released':
        title = 'Item Released';
        message =
            'Your request for $itemName has been released and is ready for pickup.';
        type = 'success';
        break;
      case 'rejected':
        title = 'Request Rejected';
        // Build a descriptive message including who rejected the request
        final hasRejectorInfo = rejectedByName != null && rejectedByName.trim().isNotEmpty;
        final hasRoleInfo = rejectedByRole != null && rejectedByRole.trim().isNotEmpty;
        final hasLabInfo = laboratory != null && laboratory.trim().isNotEmpty;

        if (hasRejectorInfo || hasRoleInfo) {
          // Determine display role
          String displayRole;
          if (hasRoleInfo) {
            final roleLower = rejectedByRole.trim().toLowerCase();
            if (roleLower == 'teacher' || roleLower == 'instructor' || roleLower == 'faculty') {
              displayRole = 'Faculty';
            } else if (roleLower == 'admin' || roleLower == 'lab_incharge' || roleLower == 'labincharge') {
              displayRole = 'Laboratory In-Charge';
            } else {
              displayRole = rejectedByRole.trim();
            }
          } else {
            displayRole = 'Faculty';
          }

          final namePart = hasRejectorInfo ? rejectedByName.trim() : displayRole;
          final rolePart = hasRejectorInfo ? ' ($displayRole)' : '';
          final labPart = hasLabInfo ? ' from the ${laboratory.trim()}' : '';

          message =
              'Your request to borrow "$itemName"$labPart was rejected by $namePart$rolePart.${reason != null ? '\n\nReason: $reason' : ''}\n\nClick to view details.';
        } else {
          final labPart = hasLabInfo ? ' from the ${laboratory.trim()}' : '';
          message =
              'Your request for $itemName$labPart was rejected.${reason != null ? ' Reason: $reason' : ''}';
        }
        type = 'error';
        break;
      case 'returned':
        title = 'Item Returned';
        message = 'You have successfully returned $itemName.';
        type = 'success';
        break;
      default:  
        title = 'Request Update';
        message = 'Your request for $itemName has been updated.';
        type = 'info';
    }

    // Set a flag in Firebase to prevent duplicate notifications for this specific status change
    try {
      final flagKey = 'status_${requestId}_$status';
      await _database
          .ref()
          .child('notification_flags')
          .child(userId)
          .child(flagKey)
          .set({
            'notified': true,
            'timestamp': ServerValue.timestamp,
            'sentBy': 'unified_service',
          });
      debugPrint('✅ Set notification flag for $flagKey');
    } catch (e) {
      debugPrint('Error setting notification flag: $e');
    }

    await sendNotificationToUser(
      userId: userId,
      title: title,
      message: message,
      type: type,
      additionalData: {
        'action': 'borrow_request_details',
        'requestId': requestId,
        'status': status,
        'rejectedByName': rejectedByName,
        'rejectedByRole': rejectedByRole,
      },
    );
  }

  // Send reminder notification
  static Future<void> sendReminderNotification({
    required String userId,
    required String itemName,
    required String dueDate,
    required String reminderType,
  }) async {
    String title;
    String message;
    String type;

    switch (reminderType) {
      case 'due_soon':
        title = 'Return Reminder';
        message = 'Please return $itemName by $dueDate.';
        type = 'warning';
        break;
      case 'due_today':
        title = 'Due Today - Return Reminder';
        message = '$itemName is due today ($dueDate). Please return it before 5:00 PM.';
        type = 'warning';
        break;
      case 'overdue':
        title = 'Overdue Item';
        message =
            'You have an overdue item: $itemName. Please return it immediately.';
        type = 'error';
        break;
      case 'maintenance':
        title = 'Maintenance Reminder';
        message = 'Scheduled maintenance for $itemName is due.';
        type = 'info';
        break;
      default:
        title = 'Reminder';
        message = 'Reminder: $itemName - $dueDate';
        type = 'info';
    }

    await sendNotificationToUser(
      userId: userId,
      title: title,
      message: message,
      type: type,
      additionalData: {
        'itemName': itemName,
        'dueDate': dueDate,
        'reminderType': reminderType,
      },
    );
  }

  // Send lab announcement
  static Future<void> sendLabAnnouncement({
    required String title,
    required String message,
    String? priority,
  }) async {
    await sendSystemNotification(
      title: title,
      message: message,
      type: priority == 'high' ? 'announcement' : 'info',
      additionalData: {
        'priority': priority ?? 'normal',
        'announcementType': 'lab_announcement',
      },
    );
  }

  // Send maintenance notification
  static Future<void> sendMaintenanceNotification({
    required String equipmentName,
    required String maintenanceDate,
    required String description,
  }) async {
    await sendSystemNotification(
      title: 'Equipment Maintenance',
      message:
          '$equipmentName will be under maintenance on $maintenanceDate. $description',
      type: 'warning',
      additionalData: {
        'equipmentName': equipmentName,
        'maintenanceDate': maintenanceDate,
        'description': description,
        'announcementType': 'maintenance',
      },
    );
  }

  // Get unread notification count for current user
  static Future<int> getUnreadCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final snapshot =
          await _database
              .ref()
              .child('notifications')
              .child(user.uid)
              .orderByChild('isRead')
              .equalTo(false)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        int unreadCount = 0;
        data.forEach((key, value) {
          // Only count actual notification objects, not boolean values
          if (value is Map<dynamic, dynamic>) {
            final isRead = value['isRead'];
            if (isRead == null || isRead == false) {
              unreadCount++;
            }
          } else {
            debugPrint('Skipping invalid notification in count: key=$key, value=$value (${value.runtimeType})');
          }
        });
        debugPrint('getUnreadCount: Found $unreadCount unread notifications for user ${user.uid}');
        return unreadCount;
      } else {
        debugPrint('getUnreadCount: No unread notifications found for user ${user.uid}');
      }

      return 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark all notifications as read for current user
  static Future<void> markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot =
          await _database.ref().child('notifications').child(user.uid).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final updates = <String, dynamic>{};

        for (var key in data.keys) {
          updates['$key/isRead'] = true;
        }

        await _database
            .ref()
            .child('notifications')
            .child(user.uid)
            .update(updates);
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  // Listen to real-time notifications for current user
  static Stream<Map<String, dynamic>> listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value({});
    }

    return _database.ref().child('notifications').child(user.uid).onValue.map((
      event,
    ) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{};
    });
  }

  // Listen to system notifications
  static Stream<Map<String, dynamic>> listenToSystemNotifications() {
    return _database.ref().child('system_notifications').onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{};
    });
  }
}
