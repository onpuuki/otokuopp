import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScrapingLogModal extends StatelessWidget {
  final FirebaseFirestore? firestore;

  const ScrapingLogModal({super.key, this.firestore});

  @override
  Widget build(BuildContext context) {
    final db = firestore ?? FirebaseFirestore.instance;

    return AlertDialog(
      title: const Text('スクレイピングログ'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('debug_logs')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(child: Text('ログがありません。'));
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final title = data['title'] as String? ?? 'EMPTY';
                final message = data['message'] as String? ?? '';
                final createdAt = data['createdAt'] as Timestamp?;

                String timeStr = '取得時間不明';
                if (createdAt != null) {
                  final date = createdAt.toDate();
                  timeStr = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
                }

                return ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(message, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
