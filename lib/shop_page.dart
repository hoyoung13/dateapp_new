import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'shop_service.dart';
import 'user_provider.dart';
import 'shop_item_detail_page.dart';
import 'shop_constants.dart';
import 'image_utils.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({Key? key}) : super(key: key);

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = shopCategories;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('포인트 상점'),
          bottom: TabBar(
            controller: _tabController,
            tabs: _categories.map((e) => Tab(text: e)).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((c) => _buildTab(c)).toList(),
        ),
      ),
    );
  }

  Widget _buildTab(String category) {
    return FutureBuilder<List<ShopItem>>(
      future: ShopService.fetchItems(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('상품이 없습니다.'));
        }
        final items = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopItemDetailPage(item: item),
                  ),
                );
                // update user points after purchase
                final uid = context.read<UserProvider>().userId;
                if (uid != null) {
                  await context.read<UserProvider>().fetchUserProfile(uid);
                }
              },
              child: Card(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.imageUrl.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: Image.network(
                          resolveImageUrl(item.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(item.name),
                    Text('${item.pricePoints}P',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
