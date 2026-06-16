import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
            .limit(30)
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
            return const Center(child: Text('実行されたジョブはありません。'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: data.docs.length,
            itemBuilder: (context, index) {
              final document = data.docs[index];
              final job = document.data()! as Map<String, dynamic>;

              final int totalUrls = job['totalUrls'] as int? ?? 0;
              final int completedUrls = job['completedUrls'] as int? ?? 0;
              final String status = job['status'] as String? ?? '不明';
              final int extractedCount = job['totalExtractedCampaigns'] as int? ?? 0;
              final int tokensUsed = job['totalTokensUsed'] as int? ?? 0;
              final double estimatedCost = (job['totalEstimatedCostYen'] as num?)?.toDouble() ?? 0.0;

              String createdAtStr = '不明';
              if (job['createdAt'] is Timestamp) {
                createdAtStr = DateFormat('yyyy/MM/dd HH:mm:ss').format((job['createdAt'] as Timestamp).toDate());
              }

              String completedAtStr = '処理中...';
              if (job['completedAt'] is Timestamp) {
                completedAtStr = DateFormat('yyyy/MM/dd HH:mm:ss').format((job['completedAt'] as Timestamp).toDate());
              } else if (status == 'completed') {
                completedAtStr = '記録なし';
              }

              double progress = 0.0;
              if (totalUrls > 0) {
                progress = completedUrls / totalUrls;
              }

              return Card(
                elevation: 4.0,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ステータス: $status',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '$completedUrls / $totalUrls 件',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.green : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('開始: $createdAtStr'),
                      Text('完了: $completedAtStr'),
                      const SizedBox(height: 8),
                      Text('収集件数: $extractedCount 件'),
                      Text('消費トークン: $tokensUsed'),
                      Text('消費クレジット(概算): 約 ${estimatedCost.toStringAsFixed(3)} 円'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
