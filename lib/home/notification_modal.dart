import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'borrowing_history_page.dart';

class NotificationModal extends StatefulWidget {
  final BuildContext parentContext;
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToRequests;

  const NotificationModal({
    super.key,
    required this.parentContext,
    this.onNavigateToHistory,
    this.onNavigateToRequests,
  });

  @override
  State<NotificationModal> createState() => _NotificationModalState();
}

class _NotificationModalState extends State<NotificationModal> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      List<NotificationItem> notifications = [];

      // Load user-specific notifications
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('notifications')
              .child(user.uid)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        debugPrint('Found ${data.length} user notifications for user ${user.uid}');
        data.forEach((key, value) {
          // Skip invalid data that's not a Map
          if (value is Map<dynamic, dynamic>) {
            final notificationData = value;
            notifications.add(NotificationItem.fromMap(key, notificationData));
          } else {
            debugPrint('Skipping invalid notification data: key=$key, value=$value (${value.runtimeType})');
          }
        });
      } else {
        debugPrint('No user notifications found for user ${user.uid}');
      }

      // Add system notifications (announcements, maintenance, etc.)
      await _loadSystemNotifications(notifications);

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint('Total notifications to display: ${notifications.length}');

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSystemNotifications(
    List<NotificationItem> notifications,
  ) async {
    try {
      // Load system-wide notifications
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('system_notifications')
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        debugPrint('Found ${data.length} system notifications');
        data.forEach((key, value) {
          // Skip invalid data that's not a Map
          if (value is Map<dynamic, dynamic>) {
            final notificationData = value;
            notifications.add(NotificationItem.fromMap(key, notificationData));
          } else {
            debugPrint('Skipping invalid system notification data: key=$key, value=$value (${value.runtimeType})');
          }
        });
      } else {
        debugPrint('No system notifications found');
      }

      // Load announcements and convert them to notifications
      await _loadAnnouncementNotifications(notifications);
    } catch (e) {
      debugPrint('Error loading system notifications: $e');
    }
  }

  Future<void> _loadAnnouncementNotifications(
    List<NotificationItem> notifications,
  ) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('announcements')
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        debugPrint('Found ${data.length} announcements to convert to notifications');
        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            final announcementData = value;
            // Convert announcement to notification
            final notification = NotificationItem(
              id: 'announcement_$key',
              title: announcementData['title'] ?? 'New Announcement',
              message: announcementData['content'] ?? '',
              timestamp: announcementData['createdAt'] != null
                  ? DateTime.parse(announcementData['createdAt'])
                  : DateTime.now(),
              type: NotificationType.announcement,
              isRead: false, // Announcements should always appear as unread initially
            );
            notifications.add(notification);
          } else {
            debugPrint('Skipping invalid announcement data: key=$key, value=$value (${value.runtimeType})');
          }
        });
      } else {
        debugPrint('No announcements found');
      }
    } catch (e) {
      debugPrint('Error loading announcement notifications: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index].isRead = true;
      }
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('notifications')
            .child(user.uid)
            .child(notificationId)
            .update({'isRead': true});
      }
    } catch (e) {
      debugPrint('Error updating notification read status: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == notificationId);
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('notifications')
            .child(user.uid)
            .child(notificationId)
            .remove();
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Notifications'),
            content: const Text(
              'Are you sure you want to clear all notifications?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _notifications.clear();
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseDatabase.instance
              .ref()
              .child('notifications')
              .child(user.uid)
              .remove();
        }
      } catch (e) {
        debugPrint('Error clearing notifications: $e');
      }
    }
  }

  void _navigateToAnnouncement(NotificationItem notification) async {
    try {
      // Extract the announcement ID from the notification ID
      final announcementId = notification.id.replaceFirst('announcement_', '');
      
      // Fetch the full announcement data
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('announcements')
          .child(announcementId)
          .get();

      if (snapshot.exists && snapshot.value is Map) {
        final announcementData = snapshot.value as Map<dynamic, dynamic>;
        final announcement = {
          'id': announcementId,
          'title': announcementData['title'] ?? '',
          'content': announcementData['content'] ?? '',
          'author': announcementData['author'] ?? '',
          'category': announcementData['category'] ?? '',
          'createdAt': announcementData['createdAt'] ?? '',
          'updatedAt': announcementData['updatedAt'] ?? '',
        };

        // Show the announcement detail dialog
        _showAnnouncementDetailDialog(announcement);
      } else {
        // Fallback: show a simple dialog with notification content
        _showAnnouncementDetailDialog({
          'id': announcementId,
          'title': notification.title,
          'content': notification.message,
          'author': 'System',
          'category': 'info',
          'createdAt': notification.timestamp.toIso8601String(),
          'updatedAt': notification.timestamp.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error navigating to announcement: $e');
      // Fallback: show a simple dialog with notification content
      _showAnnouncementDetailDialog({
        'id': notification.id,
        'title': notification.title,
        'content': notification.message,
        'author': 'System',
        'category': 'info',
        'createdAt': notification.timestamp.toIso8601String(),
        'updatedAt': notification.timestamp.toIso8601String(),
      });
    }
  }

  void _showAnnouncementDetailDialog(Map<String, dynamic> announcement) {
    showDialog(
      context: widget.parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            announcement['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (announcement['category'].toString().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        announcement['category'] as String,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      announcement['category'] as String,
                      style: TextStyle(
                        color: _getCategoryColor(
                          announcement['category'] as String,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  announcement['content'] as String,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'By ${announcement['author']} • ${_formatTime(announcement['createdAt'] as String)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'important':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'update':
        return Colors.purple;
      default:
        return const Color(0xFF2AA39F); // Default app color
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unreadCount > 0)
                      Text(
                        '$unreadCount unread',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                  ],
                ),
                if (_notifications.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllNotifications,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          // Notifications list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      itemCount: _notifications.length,
                      separatorBuilder:
                          (context, index) =>
                              Divider(height: 1, color: Colors.grey[200]),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return Dismissible(
                          key: Key(notification.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) {
                            _deleteNotification(notification.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Notification deleted'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {},
                                ),
                              ),
                            );
                          },
                          child: InkWell(
                            onTap: () {
                              if (!notification.isRead) {
                                _markAsRead(notification.id);
                              }

                              Navigator.of(context).pop();

                              // Check if this is an announcement notification
                              if (notification.type == NotificationType.announcement) {
                                // Navigate to announcement card/detail
                                _navigateToAnnouncement(notification);
                                return;
                              }

                              // Check if this is a student request notification (single or batch)
                              if (notification.type == NotificationType.info && 
                                  (notification.title.contains('New Borrow Request') || 
                                   notification.title.contains('New Batch Borrow Request'))) {
                                // Navigate to Requests tab
                                final navigateToRequests = widget.onNavigateToRequests;
                                if (navigateToRequests != null) {
                                  navigateToRequests();
                                  return;
                                }
                              }

                              final navigateToHistory =
                                  widget.onNavigateToHistory;
                              if (navigateToHistory != null) {
                                navigateToHistory();
                                return;
                              }

                              Navigator.of(widget.parentContext).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => const BorrowingHistoryPage(),
                                ),
                              );
                            },
                            child: Container(
                              color:
                                  notification.isRead
                                      ? Colors.transparent
                                      : Colors.blue.withValues(alpha: 0.05),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: notification.color.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      notification.icon,
                                      color: notification.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notification.title,
                                                style: TextStyle(
                                                  fontWeight:
                                                      notification.isRead
                                                          ? FontWeight.normal
                                                          : FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatTimestamp(
                                                notification.timestamp,
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notification.message,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Unread indicator
                                  if (!notification.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(
                                        left: 8,
                                        top: 6,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

// Notification model
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.isRead,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.announcement:
        return Icons.campaign_outlined;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.announcement:
        return Colors.blue;
      case NotificationType.info:
        return Colors.grey;
    }
  }

  factory NotificationItem.fromMap(String id, Map<dynamic, dynamic> data) {
    return NotificationItem(
      id: id,
      title: data['title'] ?? 'Notification',
      message: data['message'] ?? '',
      timestamp:
          data['timestamp'] != null
              ? DateTime.parse(data['timestamp'])
              : DateTime.now(),
      type: _parseNotificationType(data['type'] ?? 'info'),
      isRead: data['isRead'] ?? false,
    );
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'success':
        return NotificationType.success;
      case 'error':
        return NotificationType.error;
      case 'warning':
        return NotificationType.warning;
      case 'announcement':
        return NotificationType.announcement;
      case 'info':
        return NotificationType.info;
      default:
        return NotificationType.info;
    }
  }
}

enum NotificationType { success, error, warning, announcement, info }

// Function to show the notification modal
void showNotificationModal(
  BuildContext context, {
  VoidCallback? onNavigateToHistory,
  VoidCallback? onNavigateToRequests,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (sheetContext) => NotificationModal(
          parentContext: context,
          onNavigateToHistory: onNavigateToHistory,
          onNavigateToRequests: onNavigateToRequests,
        ),
  );
}
