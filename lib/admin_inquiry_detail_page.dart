import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'inquiry_service.dart';
import 'user_provider.dart';

class AdminInquiryDetailPage extends StatefulWidget {
  final int inquiryId;
  const AdminInquiryDetailPage({Key? key, required this.inquiryId}) : super(key: key);

  @override
  State<AdminInquiryDetailPage> createState() => _AdminInquiryDetailPageState();
}

class _AdminInquiryDetailPageState extends State<AdminInquiryDetailPage> {
  late Future<Inquiry> _future;
  final _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = InquiryService.fetchInquiry(widget.inquiryId);
  }

  Future<void> _submit() async {
    final adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;
    await InquiryService.answerInquiry(widget.inquiryId, adminId, _answerController.text);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세')),
      body: FutureBuilder<Inquiry>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('조회 실패'));
          }
          final inquiry = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inquiry.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(inquiry.content),
                const Divider(),
                if (inquiry.answer != null)
                  Text('답변: ${inquiry.answer}')
                else ...[
                  TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(labelText: '답변 입력'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _submit, child: const Text('답변하기')),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}
