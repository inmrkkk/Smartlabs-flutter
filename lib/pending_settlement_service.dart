import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class PendingSettlementItem {
  final String recordId;
  final String itemName;
  final String itemStatus; // "Lost" or "Damaged"
  final int qtyToReplace;

  PendingSettlementItem({
    required this.recordId,
    required this.itemName,
    required this.itemStatus,
    required this.qtyToReplace,
  });
}

class PendingSettlementState {
  final bool hasPending;
  final List<PendingSettlementItem> items;

  PendingSettlementState({
    required this.hasPending,
    required this.items,
  });

  int get totalToReplace =>
      items.fold<int>(0, (sum, it) => sum + it.qtyToReplace);
}

class PendingSettlementService {
  static final DatabaseReference _recordsRef =
      FirebaseDatabase.instance.ref('damaged_lost_records');

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Computes how many items must be replaced for this record.
  /// Priority:
  /// - Lost: use missingQuantity if present
  /// - Damaged: use damagedQuantity if present
  /// - Fallback: borrowedQuantity - returnedQuantity (or borrowedQuantity)
  static int _qtyToReplace(Map record) {
    final itemStatus = (record['itemStatus'] ?? '').toString();

    if (itemStatus == 'Lost') {
      final missing = _asInt(record['missingQuantity']);
      if (missing > 0) return missing;
    }

    if (itemStatus == 'Damaged') {
      final damaged = _asInt(record['damagedQuantity']);
      if (damaged > 0) return damaged;
    }

    final borrowed = _asInt(record['borrowedQuantity']);
    final returned = _asInt(record['returnedQuantity']);

    final safeBorrowed = borrowed > 0 ? borrowed : 1;
    final diff = safeBorrowed - (returned >= 0 ? returned : 0);

    if (diff > 0) return diff;
    return safeBorrowed;
  }

  /// Stream this in your Home page to show pending settlement banner/card.
  ///
  /// It reads: /damaged_lost_records
  /// Then filters client-side by:
  /// - borrowerId == FirebaseAuth.currentUser.uid
  /// - status == "Pending"
  static Stream<PendingSettlementState> streamForCurrentBorrower() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Stream.value(PendingSettlementState(hasPending: false, items: []));
    }

    return _recordsRef.onValue.map((event) {
      final data = event.snapshot.value;

      if (data is! Map) {
        return PendingSettlementState(hasPending: false, items: []);
      }

      final items = <PendingSettlementItem>[];

      data.forEach((key, value) {
        if (value is! Map) return;

        final borrowerId = (value['borrowerId'] ?? '').toString();
        final status = (value['status'] ?? '').toString();

        if (borrowerId != uid) return;
        if (status != 'Pending') return;

        final itemName = (value['itemName'] ?? 'Unknown Item').toString();
        final itemStatus = (value['itemStatus'] ?? '').toString();

        items.add(
          PendingSettlementItem(
            recordId: key.toString(),
            itemName: itemName,
            itemStatus: itemStatus,
            qtyToReplace: _qtyToReplace(value),
          ),
        );
      });

      return PendingSettlementState(
        hasPending: items.isNotEmpty,
        items: items,
      );
    });
  }
}

class PendingSettlementCard extends StatelessWidget {
  final VoidCallback? onTap;

  const PendingSettlementCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PendingSettlementState>(
      stream: PendingSettlementService.streamForCurrentBorrower(),
      builder: (context, snapshot) {
        final state = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (state == null || !state.hasPending) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Settlement',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text('Total to replace: ${state.totalToReplace}'),
                  const SizedBox(height: 10),
                  ...state.items.map(
                    (it) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('${it.itemName} (${it.itemStatus})'),
                          ),
                          Text('x${it.qtyToReplace}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
