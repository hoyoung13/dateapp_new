import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'shop_service.dart';
import 'user_provider.dart';
import 'image_utils.dart';

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({Key? key}) : super(key: key);

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  late Future<List<Purchase>> _future;

  @override
  void initState() {
    super.initState();
    final userId =
        Provider.of<UserProvider>(context, listen: false).userId ?? 0;
    _future = ShopService.fetchPurchaseHistory(userId);
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy.MM.dd HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('포인트 구매 목록')),
      body: FutureBuilder<List<Purchase>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(child: Text('구매 내역이 없습니다.'));
          }
          final items = snapshot.data!;
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: item.imageUrl.isNotEmpty
                    ? Image.network(resolveImageUrl(item.imageUrl))
                    : null,
                title: Text(item.itemName),
                subtitle: Text(_formatDate(item.purchasedAt)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(item.itemName),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.network(
                            'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${item.barcode}',
                            height: 150,
                          ),
                          const SizedBox(height: 10),
                          const Text('바코드를 제시하세요'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
