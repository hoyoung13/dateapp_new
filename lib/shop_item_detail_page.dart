import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'shop_service.dart';

class ShopItemDetailPage extends StatefulWidget {
  final ShopItem item;
  const ShopItemDetailPage({Key? key, required this.item}) : super(key: key);

  @override
  State<ShopItemDetailPage> createState() => _ShopItemDetailPageState();
}

class _ShopItemDetailPageState extends State<ShopItemDetailPage> {
  Purchase? _purchase;
  bool _buying = false;

  Future<void> _buy() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    setState(() => _buying = true);
    try {
      final p = await ShopService.purchaseItem(userId, widget.item.id);
      setState(() => _purchase = p);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매 실패')),
      );
    } finally {
      setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.item.imageUrl.isNotEmpty)
              Image.network(widget.item.imageUrl, height: 150),
            const SizedBox(height: 16),
            Text('${widget.item.pricePoints} 포인트',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_purchase == null)
              ElevatedButton(
                onPressed: _buying ? null : _buy,
                child: _buying
                    ? const CircularProgressIndicator()
                    : const Text('구매하기'),
              )
            else ...[
              const Text('구매 완료! 바코드를 제시하세요.'),
              const SizedBox(height: 10),
              Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${_purchase!.barcode}',
                height: 150,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
