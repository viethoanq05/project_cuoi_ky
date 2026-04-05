import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/food_item.dart';
import '../services/menu_service.dart';

class FoodEditorScreen extends StatefulWidget {
  const FoodEditorScreen({super.key, this.initial});
  final FoodItem? initial;

  @override
  State<FoodEditorScreen> createState() => _FoodEditorScreenState();
}

class _FoodEditorScreenState extends State<FoodEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  bool _isAvailable = true;
  String _size = 'M';
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String _imageUrl = '';
  bool _uploadingImage = false;
  bool _saving = false;

  MenuService get _menuService => context.read<MenuService>();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _priceController = TextEditingController(
      text: (initial?.price ?? 0).toString(),
    );

    _isAvailable = initial?.isAvailable ?? true;
    _selectedCategoryId = initial?.categoryId;
    _imageUrl = initial?.image ?? '';

    final initialSize = (initial?.options['size']?.toString() ?? 'M')
        .toUpperCase();
    _size = ['S', 'M', 'L'].contains(initialSize) ? initialSize : 'M';
  }

  bool get _isDrinkCategory {
    return _looksLikeDrink(_selectedCategoryName) ||
        _looksLikeDrink(_selectedCategoryId);
  }

  bool _looksLikeDrink(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      return false;
    }

    // Best-effort matching for common “drink” labels.
    final normalized = raw
        .replaceAll('đ', 'd')
        .replaceAll('ồ', 'o')
        .replaceAll('ố', 'o')
        .replaceAll('ộ', 'o')
        .replaceAll('ơ', 'o')
        .replaceAll('ớ', 'o')
        .replaceAll('ở', 'o')
        .replaceAll('ợ', 'o')
        .replaceAll('ọ', 'o')
        .replaceAll('û', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('ứ', 'u')
        .replaceAll('ừ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('ủ', 'u')
        .replaceAll('ụ', 'u')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e')
        .replaceAll('ẹ', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i')
        .replaceAll('ị', 'i');

    return normalized.contains('do uong') ||
        normalized.contains('douong') ||
        normalized.contains('do_uong') ||
        normalized.contains('drink') ||
        normalized.contains('beverage') ||
        normalized.contains('nuoc');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadingImage) {
      return;
    }

    XFile? picked;
    try {
      final picker = ImagePicker();
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } on MissingPluginException {
      if (mounted) {
        _showMessage(
          'Image picker chua duoc khoi tao. Hay tat app va chay lai (khong dung hot reload).',
        );
      }
      return;
    }

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _uploadingImage = true;
    });

    try {
      final bytes = await picked.readAsBytes();
      final url = await _menuService.uploadFoodImage(
        bytes: bytes,
        fileName: picked.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _imageUrl = url;
      });
      _showMessage('Upload anh thanh cong.');
    } catch (e) {
      if (mounted) {
        _showMessage('Upload anh that bai: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.trim().isEmpty) {
      _showMessage('Vui long chon danh muc.');
      return;
    }

    if (_imageUrl.trim().isEmpty) {
      _showMessage('Vui long upload anh mon an.');
      return;
    }

    setState(() {
      _saving = true;
    });

    String? error;
    try {
      final options = <String, dynamic>{...?widget.initial?.options};
      if (_isDrinkCategory) {
        options['size'] = _size;
      } else {
        options.remove('size');
      }

      final payload = _EditorPayload(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId!.trim(),
        image: _imageUrl.trim(),
        price: num.tryParse(_priceController.text.trim()) ?? 0,
        options: options,
        isAvailable: _isAvailable,
      );

      if (widget.initial == null) {
        error = await _menuService.createFood(
          name: payload.name,
          description: payload.description,
          categoryId: payload.categoryId,
          image: payload.image,
          price: payload.price,
          options: payload.options,
          isAvailable: payload.isAvailable,
        );
      } else {
        final item = widget.initial!.copyWith(
          name: payload.name,
          description: payload.description,
          categoryId: payload.categoryId,
          image: payload.image,
          price: payload.price,
          options: payload.options,
          isAvailable: payload.isAvailable,
        );
        error = await _menuService.updateFood(item);
      }
    } catch (e) {
      error = 'Luu mon an that bai: $e';
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    if (error != null) {
      _showMessage(error);
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final showSize = _isDrinkCategory;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Chinh sua mon an' : 'Them mon an')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Ten mon an'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nhap ten mon an';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Mo ta'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<MenuCategory>>(
                    stream: _menuService.watchCategories(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <MenuCategory>[];
                      if (snapshot.hasError) {
                        return Text(
                          'Khong tai duoc danh muc: ${snapshot.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }

                      final selected =
                          items.any((c) => c.id == _selectedCategoryId)
                          ? _selectedCategoryId
                          : null;

                      MenuCategory? selectedCategory;
                      if (selected != null) {
                        for (final c in items) {
                          if (c.id == selected) {
                            selectedCategory = c;
                            break;
                          }
                        }
                      }

                      if (_selectedCategoryName == null &&
                          selectedCategory != null) {
                        final selectedName = selectedCategory.name;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _selectedCategoryName = selectedName;
                          });
                        });
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: 'Danh muc',
                        ),
                        items: items
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          MenuCategory? picked;
                          for (final c in items) {
                            if (c.id == value) {
                              picked = c;
                              break;
                            }
                          }
                          setState(() {
                            _selectedCategoryId = value;
                            _selectedCategoryName = picked?.name;
                          });
                        },
                        validator: (_) {
                          if (_selectedCategoryId == null ||
                              _selectedCategoryId!.trim().isEmpty) {
                            return 'Chon danh muc';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Gia'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = num.tryParse((value ?? '').trim());
                      if (parsed == null || parsed < 0) {
                        return 'Gia khong hop le';
                      }
                      return null;
                    },
                  ),
                  if (showSize) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Kich thuoc (size)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    RadioGroup<String>(
                      groupValue: _size,
                      onChanged: (value) {
                        setState(() {
                          _size = value!;
                        });
                      },
                      child: const Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'S',
                              title: Text('S'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'M',
                              title: Text('M'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'L',
                              title: Text('L'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SwitchListTile(
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dang ban'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _uploadingImage ? null : _pickAndUploadImage,
                    icon: _uploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(
                      _imageUrl.isEmpty
                          ? 'Upload anh mon an'
                          : 'Upload lai anh',
                    ),
                  ),
                  if (_imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImagePreview(_imageUrl),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Dang luu...' : 'Luu mon an'),
                  ),
                ],
              ),
            ),
          ),
          if (_saving)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black12,
                child: SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String image) {
    return Image.network(
      image,
      height: 180,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 100,
        alignment: Alignment.center,
        color: Colors.black12,
        child: const Text('Khong hien thi duoc anh'),
      ),
    );
  }
}

class _EditorPayload {
  const _EditorPayload({
    required this.name,
    required this.description,
    required this.categoryId,
    required this.image,
    required this.price,
    required this.options,
    required this.isAvailable,
  });

  final String name;
  final String description;
  final String categoryId;
  final String image;
  final num price;
  final Map<String, dynamic> options;
  final bool isAvailable;
}
