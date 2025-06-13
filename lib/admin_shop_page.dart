import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shop_service.dart';
import 'user_provider.dart';

class AdminShopPage extends StatefulWidget {
  const AdminShopPage({Key? key}) : super(key: key);

  @override
  State<AdminShopPage> createState() => _AdminShopPageState();
}

class _AdminShopPageState extends State<AdminShopPage> {
  late Future<List<ShopItem>> _future;
  int? _adminId;

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

  Future<void> _showItemDialog({ShopItem? item}) async {
    final categoryCtrl = TextEditingController(text: item?.category ?? '');
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final imageCtrl = TextEditingController(text: item?.imageUrl ?? '');
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
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: '카테고리'),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(labelText: '이미지 URL'),
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
                final category = categoryCtrl.text;
                final name = nameCtrl.text;
                final image = imageCtrl.text;
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
