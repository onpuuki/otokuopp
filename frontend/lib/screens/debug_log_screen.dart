import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_log_manager.dart';

class DebugLogScreen extends StatelessWidget {
  final FirebaseFirestore? firestore;

  const DebugLogScreen({super.key, this.firestore});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('デバッグログ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'アプリ側ログ'),
              Tab(text: 'バックエンド側ログ'),
            ],
          ),
          actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'ログをコピー',
            onPressed: () async {
              final logs = DebugLogManager.logsNotifier.value.join('\n');
              await Clipboard.setData(ClipboardData(text: logs));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ログをクリップボードにコピーしました')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'ログをクリア',
            onPressed: () {
              DebugLogManager.clearLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ログをクリアしました')),
              );
            },
          ),
        ],
      ),
        body: TabBarView(
          children: [
            _buildLocalLogsTab(),
            _buildBackendLogsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalLogsTab() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: DebugLogManager.logsNotifier,
      builder: (context, logs, child) {
        if (logs.isEmpty) {
          return const Center(child: Text('ログはありません'));
        }
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                logs[index],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBackendLogsTab() {
    final db = firestore ?? FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
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
    );
  }
}
