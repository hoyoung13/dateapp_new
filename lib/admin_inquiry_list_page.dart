import 'package:flutter/material.dart';
import 'inquiry_service.dart';
import 'admin_inquiry_detail_page.dart';

class AdminInquiryListPage extends StatefulWidget {
  const AdminInquiryListPage({Key? key}) : super(key: key);

  @override
  State<AdminInquiryListPage> createState() => _AdminInquiryListPageState();
}

class _AdminInquiryListPageState extends State<AdminInquiryListPage> {
  late Future<List<Inquiry>> _future;

  @override
  void initState() {
    super.initState();
    _future = InquiryService.fetchInquiries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의 목록')),
      body: FutureBuilder<List<Inquiry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('문의 목록 로딩 오류: ${snapshot.error}');
            return const Center(child: Text('문의 데이터를 불러오는데 실패했습니다.'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('문의가 없습니다.'));
          }
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.createdAt),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminInquiryDetailPage(inquiryId: item.id),
                    ),
                  );
                  setState(() {
                    _future = InquiryService.fetchInquiries();
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}
