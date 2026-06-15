import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScrapingStatusScreen extends StatelessWidget {
  final FirebaseFirestore? firestore;
  const ScrapingStatusScreen({Key? key, this.firestore}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('スクレイピング状況'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: (firestore ?? FirebaseFirestore.instance)
            .collection('scraping_jobs')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;

          if (data.size == 0) {
            return const Center(child: Text('実行中のジョブはありません。'));
          }

          final document = data.docs.first;
          final job = document.data()! as Map<String, dynamic>;

          final int totalUrls = job['totalUrls'] as int? ?? 0;
          final int completedUrls = job['completedUrls'] as int? ?? 0;
          final String status = job['status'] as String? ?? '不明';

          double progress = 0.0;
          if (totalUrls > 0) {
            progress = completedUrls / totalUrls;
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '最新のスクレイピング状況',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(
                  '進捗: $completedUrls / $totalUrls 件',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 20,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ステータス: $status',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
