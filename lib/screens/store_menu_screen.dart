import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/food_item.dart';
import '../services/menu_service.dart';
import 'food_editor_screen.dart';

class StoreMenuScreen extends StatefulWidget {
  const StoreMenuScreen({super.key});

  @override
  State<StoreMenuScreen> createState() => _StoreMenuScreenState();
}

class _StoreMenuScreenState extends State<StoreMenuScreen> {
  MenuService get _menuService => context.read<MenuService>();

  Future<void> _createFood() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FoodEditorScreen()));
  }

  Future<void> _editFood(FoodItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FoodEditorScreen(initial: item)),
    );
  }

  Future<void> _toggleAvailability(FoodItem item, bool value) async {
    final error = await _menuService.toggleAvailability(item, value);
    if (!mounted || error == null) {
      return;
    }
    _showError(error);
  }

  Future<void> _deleteFood(FoodItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoa mon an'),
          content: Text('Ban chac chan muon xoa ${item.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xoa'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    final error = await _menuService.deleteFood(item);
    if (!mounted || error == null) {
      return;
    }
    _showError(error);
  }

  String _prettyOptions(Map<String, dynamic> options) {
    if (options.isEmpty) {
      return '{}';
    }

    final size = options['size']?.toString() ?? '-';
    return '{size: $size}';
  }

  String _resolveCategoryName(
    String categoryId,
    Map<String, String> categoryNames,
  ) {
    final trimmed = categoryId.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    return categoryNames[trimmed] ?? trimmed;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quan ly menu cua hang')),
      body: StreamBuilder<List<MenuCategory>>(
        stream: _menuService.watchCategories(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.hasError) {
            return Center(
              child: Text('Loi tai danh muc: ${categorySnapshot.error}'),
            );
          }

          final categoryNames = <String, String>{};
          final categories = categorySnapshot.data ?? const <MenuCategory>[];
          for (final category in categories) {
            categoryNames[category.id] = category.name;
          }

          return StreamBuilder<List<FoodItem>>(
            stream: _menuService.watchCurrentStoreFoods(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Loi tai menu: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final foods = snapshot.data!;
              if (foods.isEmpty) {
                return const Center(
                  child: Text('Chua co mon an. Bam + de tao mon dau tien.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: foods.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = foods[index];
                  final categoryName = _resolveCategoryName(
                    item.categoryId,
                    categoryNames,
                  );

                  return Card(
                    child: ListTile(
                      title: Text(
                        item.name.isEmpty ? '(Khong ten)' : item.name,
                      ),
                      subtitle: Text(
                        'Gia: ${item.price} | Danh muc: $categoryName\n'
                        'Danh gia: ${item.avgRating} (${item.totalRatings})\n'
                        'Tuy chon: ${_prettyOptions(item.options)}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          Switch(
                            value: item.isAvailable,
                            onChanged: (value) {
                              _toggleAvailability(item, value);
                            },
                          ),
                          IconButton(
                            tooltip: 'Sua',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              _editFood(item);
                            },
                          ),
                          IconButton(
                            tooltip: 'Xoa',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              _deleteFood(item);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createFood,
        child: const Icon(Icons.add),
      ),
    );
  }
}
