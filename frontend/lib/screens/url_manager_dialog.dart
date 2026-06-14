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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _addUrl(List<dynamic> currentUrls) {
    final newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty && !currentUrls.contains(newUrl)) {
      final updatedUrls = List<String>.from(currentUrls.map((e) => e.toString()))..add(newUrl);
      (widget.firestore ?? FirebaseFirestore.instance)
          .collection('settings')
          .doc('config')
          .set({'targetUrls': updatedUrls}, SetOptions(merge: true));
      _urlController.clear();
    }
  }

  void _removeUrl(List<dynamic> currentUrls, String urlToRemove) {
    final updatedUrls = List<String>.from(currentUrls.map((e) => e.toString()))..remove(urlToRemove);
    (widget.firestore ?? FirebaseFirestore.instance)
        .collection('settings')
        .doc('config')
        .set({'targetUrls': updatedUrls}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('情報取得先URL'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: StreamBuilder<DocumentSnapshot>(
                stream: (widget.firestore ?? FirebaseFirestore.instance)
                    .collection('settings')
                    .doc('config')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<dynamic> targetUrls = [];
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null && data.containsKey('targetUrls')) {
                      targetUrls = data['targetUrls'] as List<dynamic>;
                    }
                  }

                  if (targetUrls.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('URLが登録されていません。'),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: targetUrls.length,
                    itemBuilder: (context, index) {
                      final url = targetUrls[index].toString();
                      return ListTile(
                        title: Text(url, style: const TextStyle(fontSize: 14)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeUrl(targetUrls, url),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: '新規URL追加',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<DocumentSnapshot>(
                  stream: (widget.firestore ?? FirebaseFirestore.instance)
                      .collection('settings')
                      .doc('config')
                      .snapshots(),
                  builder: (context, snapshot) {
                    List<dynamic> targetUrls = [];
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data.containsKey('targetUrls')) {
                        targetUrls = data['targetUrls'] as List<dynamic>;
                      }
                    }
                    return IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue, size: 36),
                      onPressed: () => _addUrl(targetUrls),
                    );
                  },
                ),
              ],
            ),
          ],
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
