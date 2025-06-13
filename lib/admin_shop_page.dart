import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shop_service.dart';
import 'user_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'shop_constants.dart';

class AdminShopPage extends StatefulWidget {
  const AdminShopPage({Key? key}) : super(key: key);

  @override
  State<AdminShopPage> createState() => _AdminShopPageState();
}

class _AdminShopPageState extends State<AdminShopPage> {
  late Future<List<ShopItem>> _future;
  int? _adminId;
  String? _selectedCategory;
  File? _pickedImage;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _adminId = context.read<UserProvider>().userId;
    _future = _loadItems();
  }

  Future<List<ShopItem>> _loadItems() {
    return ShopService.fetchAdminItems(_adminId ?? 0);
  }

  Future<void> _delete(int id) async {
    await ShopService.deleteItem(_adminId ?? 0, id);
    setState(() {
      _future = _loadItems();
    });
  }

  Future<void> _uploadItemImage(File image) async {
    try {
      final url = await ShopService.uploadItemImage(image);
      setState(() {
        _uploadedImageUrl = url;
        _pickedImage = image;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이미지 업로드 실패')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await _uploadItemImage(File(pickedFile.path));
    }
  }

  Future<void> _showItemDialog({ShopItem? item}) async {
    _selectedCategory = item?.category ?? shopCategories.first;
    _uploadedImageUrl = item?.imageUrl;
    _pickedImage = null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final priceCtrl =
        TextEditingController(text: item != null ? '${item.pricePoints}' : '');
    final isNew = item == null;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isNew ? '상품 추가' : '상품 수정'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: shopCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  decoration: const InputDecoration(labelText: '카테고리'),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
                const SizedBox(height: 8),
                if (_pickedImage != null)
                  Image.file(_pickedImage!, height: 80)
                else if (_uploadedImageUrl != null &&
                    _uploadedImageUrl!.isNotEmpty)
                  Image.network(_uploadedImageUrl!, height: 80),
                TextButton(
                  onPressed: _pickImage,
                  child: const Text('이미지 선택'),
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: '가격(포인트)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final category = _selectedCategory ?? shopCategories.first;
                final name = nameCtrl.text;
                final image = _uploadedImageUrl ?? '';
                final price = int.tryParse(priceCtrl.text) ?? 0;
                if (isNew) {
                  await ShopService.createItem(
                      _adminId ?? 0, category, name, image, price);
                } else {
                  await ShopService.updateItem(
                      _adminId ?? 0, item!.id, category, name, image, price);
                }
                if (!mounted) return;
                Navigator.pop(ctx);
                setState(() {
                  _future = _loadItems();
                });
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('포인트 상점 관리')),
      body: FutureBuilder<List<ShopItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('상품이 없습니다.'));
          }
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: item.imageUrl.isNotEmpty
                    ? Image.network(item.imageUrl, width: 40, height: 40)
                    : null,
                title: Text(item.name),
                subtitle: Text('${item.pricePoints}P - ${item.category}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showItemDialog(item: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _delete(item.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
