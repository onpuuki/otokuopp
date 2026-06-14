import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UrlManagerDialog extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const UrlManagerDialog({super.key, this.firestore});

  @override
  State<UrlManagerDialog> createState() => _UrlManagerDialogState();
}

class _UrlManagerDialogState extends State<UrlManagerDialog> {
  final TextEditingController _urlController = TextEditingController();

  FirebaseFirestore get _firestore => widget.firestore ?? FirebaseFirestore.instance;
  DocumentReference get _configDoc => _firestore.collection('settings').doc('config');

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  Future<void> _initializeDefaults() async {
    final docSnapshot = await _configDoc.get();
    if (!docSnapshot.exists) {
      await _configDoc.set({
        'targetUrls': [
          'https://www.family.co.jp/campaign.html',
          'https://www.dennys.jp/campaign/'
        ]
      }, SetOptions(merge: true));
    } else {
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('targetUrls')) {
        await _configDoc.set({
          'targetUrls': [
            'https://www.family.co.jp/campaign.html',
            'https://www.dennys.jp/campaign/'
          ]
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> _addUrl() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      await _configDoc.set({
        'targetUrls': FieldValue.arrayUnion([url])
      }, SetOptions(merge: true));
      _urlController.clear();
    }
  }

  Future<void> _removeUrl(String url) async {
    await _configDoc.set({
      'targetUrls': FieldValue.arrayRemove([url])
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('情報取得先URLの管理', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: '新しいURLを入力',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addUrl,
                  child: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _configDoc.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('エラー: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text('データがありません'));
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  final List<dynamic> urls = data?['targetUrls'] ?? [];

                  if (urls.isEmpty) {
                    return const Center(child: Text('URLが登録されていません'));
                  }

                  return ListView.builder(
                    itemCount: urls.length,
                    itemBuilder: (context, index) {
                      final url = urls[index] as String;
                      return ListTile(
                        title: Text(url, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeUrl(url),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
