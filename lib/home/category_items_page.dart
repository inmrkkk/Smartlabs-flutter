import 'package:flutter/material.dart';
import 'package:app/home/models/equipment_models.dart';
import 'package:app/home/service/equipment_service.dart';
import 'package:app/home/service/cart_service.dart';
import 'package:app/home/form_page.dart';
import 'package:app/services/restriction_service.dart';

class CategoryItemsPage extends StatefulWidget {
  final EquipmentCategory category;

  const CategoryItemsPage({super.key, required this.category});

  @override
  State<CategoryItemsPage> createState() => _CategoryItemsPageState();
}

class _CategoryItemsPageState extends State<CategoryItemsPage> {
  final CartService _cartService = CartService();
  bool _isLoading = true;
  List<EquipmentItem> _items = [];
  List<EquipmentItem> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();
  
  // Restriction related state
  bool _isRestricted = false;
  Map<String, dynamic>? _restrictionData;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearchFilter);
    _loadItems();
    _checkUserRestriction();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearchFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _filterItemsFromSource(_items, query);
    });
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await EquipmentService.getCategoryItems(widget.category.id);
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final query = _searchController.text.trim().toLowerCase();
      final filteredItems = _filterItemsFromSource(items, query);
      setState(() {
        _items = items;
        _filteredItems = filteredItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading items: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.category.title),
        backgroundColor: widget.category.color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text('No items in this category'),
                  ],
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search equipment...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        _filteredItems.isEmpty
                            ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text('No items match your search'),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with title and eye icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (item.model != null && item.model!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.model!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showDescriptionDialog(item),
                                icon: const Icon(Icons.visibility),
                                color: const Color(0xFF2AA39F),
                                tooltip: 'View Notes',
                              ),
                            ],
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const SizedBox.shrink(),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: item.statusColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.status,
                                  style: TextStyle(
                                    color: item.statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total: ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.quantityBorrowed != null &&
                                      item.quantityBorrowed! > 0)
                                    Text(
                                      'Available: ${item.availableQuantity}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: item.availableQuantity > 0
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    )
                                  else
                                    Text(
                                      'Available: ${item.quantity}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Action buttons with restriction protection
                          Column(
                            children: [
                              if (_isRestricted) ...[
                                // Restricted user message
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, 
                                           color: Colors.red.shade600, size: 20),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Restricted Account – Borrowing Disabled',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isRestricted ? null : () => _showQuantityDialog(item),
                                      icon: const Icon(Icons.add_shopping_cart),
                                      label: const Text('Add to Request'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _isRestricted 
                                            ? Colors.grey 
                                            : const Color(0xFF2AA39F),
                                        side: BorderSide(
                                          color: _isRestricted 
                                              ? Colors.grey 
                                              : const Color(0xFF2AA39F),
                                          width: 2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isRestricted 
                                          ? () => _showRestrictionModal()
                                          : () async {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) => BorrowFormPage(
                                                        itemName: item.name,
                                                        categoryName:
                                                            widget.category.title,
                                                        itemId: item.id,
                                                        categoryId: item.categoryId,
                                                        initialLabId: widget.category.labId,
                                                        initialLabRecordId: widget.category.labRecordId,
                                                        lockLaboratory: true,
                                                        maxQuantity: item.availableQuantity,
                                                      ),
                                                ),
                                              );

                                              if (result == true) {
                                                _loadItems(); // Refresh list
                                              }
                                            },
                                      icon: const Icon(Icons.shopping_bag),
                                      label: const Text('Borrow Now'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isRestricted 
                                            ? Colors.grey 
                                            : const Color(0xFF52B788),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
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

  List<EquipmentItem> _filterItemsFromSource(
    List<EquipmentItem> source,
    String query,
  ) {
    if (query.isEmpty) return source;
    
    return source.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.model?.toLowerCase().contains(query) == true;
    }).toList();
  }

  /// Check user restriction status
  Future<void> _checkUserRestriction() async {
    try {
      final result = await RestrictionService().checkUserRestriction();
      if (mounted) {
        setState(() {
          _isRestricted = result['isRestricted'] as bool;
          _restrictionData = result['restrictionData'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      debugPrint('Error checking user restriction: $e');
    }
  }

  /// Show restriction modal when user tries to borrow
  void _showRestrictionModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              const Text('Account Restricted'),
            ],
          ),
          content: const Text(
            'Your account is currently restricted due to unresolved damaged or lost equipment. Please settle your pending records to restore borrowing access.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('I Understand'),
            ),
          ],
        );
      },
    );
  }

  void _showQuantityDialog(EquipmentItem item) {
    if (_isRestricted) {
      _showRestrictionModal();
      return;
    }
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add ${item.name} to Cart'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How many would you like to borrow?',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final quantity = int.tryParse(quantityController.text) ?? 1;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid quantity'),
                      ),
                    );
                    return;
                  }

                  if (quantity > item.availableQuantity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Only ${item.availableQuantity} available for ${item.name}',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _cartService.addItem(
                    CartItem(
                      itemId: item.id,
                      categoryId: item.categoryId,
                      itemName: item.name,
                      categoryName: widget.category.title,
                      quantity: quantity,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2AA39F),
                ),
                child: const Text('Add to Request'),
              ),
            ],
          ),
    );
  }

  void _showDescriptionDialog(EquipmentItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.model != null && item.model!.isNotEmpty)
                          Text(
                            'Model: ${item.model}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Description content
              if (item.description != null && item.description!.isNotEmpty) ...[
                Text(
                  'Notes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Description available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
