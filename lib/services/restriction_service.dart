import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestrictionService {
  static final RestrictionService _instance = RestrictionService._internal();
  factory RestrictionService() => _instance;
  RestrictionService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  static bool _hasShownLoginModal = false;

  /// Check if the current user is restricted
  /// Returns [isRestricted, restrictionData] where restrictionData contains details if restricted
  Future<Map<String, dynamic>> checkUserRestriction() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'isRestricted': false, 'restrictionData': null};
      }

      final snapshot = await _database
          .ref()
          .child('restricted_users')
          .child(user.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final status = data['status']?.toString().toLowerCase();
        
        if (status == 'active') {
          return {
            'isRestricted': true,
            'restrictionData': {
              'status': data['status'],
              'restrictionReason': data['restrictionReason'] ?? 'No reason provided',
              'restrictedAt': data['restrictedAt'] ?? DateTime.now().toIso8601String(),
            }
          };
        }
      }

      return {'isRestricted': false, 'restrictionData': null};
    } catch (e) {
      print('Error checking user restriction: $e');
      return {'isRestricted': false, 'restrictionData': null};
    }
  }

  /// Stream to listen for restriction changes in real-time
  Stream<Map<String, dynamic>> watchRestrictionStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value({'isRestricted': false, 'restrictionData': null});
    }

    return _database
        .ref()
        .child('restricted_users')
        .child(user.uid)
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final status = data['status']?.toString().toLowerCase();
        
        if (status == 'active') {
          return {
            'isRestricted': true,
            'restrictionData': {
              'status': data['status'],
              'restrictionReason': data['restrictionReason'] ?? 'No reason provided',
              'restrictedAt': data['restrictedAt'] ?? DateTime.now().toIso8601String(),
            }
          };
        }
      }

      return {'isRestricted': false, 'restrictionData': null};
    });
  }

  /// Reset login modal flag (call when user logs out)
  static void resetLoginModalFlag() {
    _hasShownLoginModal = false;
  }

  /// Check if login modal has been shown in current session
  static bool get hasShownLoginModal => _hasShownLoginModal;

  /// Mark login modal as shown for current session
  static void markLoginModalShown() {
    _hasShownLoginModal = true;
  }

  /// Security check before allowing borrow request
  /// This should be called right before submitting any borrow request
  Future<bool> canUserBorrow() async {
    final result = await checkUserRestriction();
    return !result['isRestricted'] as bool;
  }

  /// Get formatted restriction date
  static String formatRestrictionDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }
}
