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
  final TextEditingController _policyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    (widget.firestore ?? FirebaseFirestore.instance)
        .collection('settings')
        .doc('config')
        .get()
        .then((doc) {
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('scrapingPolicy')) {
        _policyController.text = doc.data()!['scrapingPolicy'] ?? '';
      }
    });
  }

  @override
  void dispose() {
    _policyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _addUrl(List<dynamic> currentUrls) {
    final newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty) {
      bool alreadyExists = currentUrls.any((e) {
        if (e is Map) return e['url'] == newUrl;
        return e.toString() == newUrl;
      });
      if (!alreadyExists) {
        final updatedUrls = List<dynamic>.from(currentUrls)..add({
          "url": newUrl,
          "affiliatePlatform": null,
          "affiliateId": null,
        });
        (widget.firestore ?? FirebaseFirestore.instance)
            .collection('settings')
            .doc('config')
            .set({'targetUrls': updatedUrls}, SetOptions(merge: true));
        _urlController.clear();
      }
    }
  }

  void _removeUrl(List<dynamic> currentUrls, dynamic itemToRemove) {
    final updatedUrls = List<dynamic>.from(currentUrls)..remove(itemToRemove);
    (widget.firestore ?? FirebaseFirestore.instance)
        .collection('settings')
        .doc('config')
        .set({'targetUrls': updatedUrls}, SetOptions(merge: true));
  }

  void _updateAffiliate(List<dynamic> currentUrls, dynamic oldItem, Map<String, dynamic> newItem) {
    final updatedUrls = List<dynamic>.from(currentUrls);
    final index = updatedUrls.indexOf(oldItem);
    if (index != -1) {
      updatedUrls[index] = newItem;
      (widget.firestore ?? FirebaseFirestore.instance)
          .collection('settings')
          .doc('config')
          .set({'targetUrls': updatedUrls}, SetOptions(merge: true));
    }
  }

  void _showAffiliateDialog(BuildContext context, List<dynamic> currentUrls, dynamic oldItem, String urlString) {
    bool isAmazon = false;
    String initialId = '';

    if (oldItem is Map) {
      isAmazon = oldItem['affiliatePlatform'] == 'amazon';
      initialId = oldItem['affiliateId']?.toString() ?? '';
    }

    final TextEditingController idController = TextEditingController(text: initialId);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('アフィリエイトID設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Amazon'),
                    value: isAmazon,
                    onChanged: (bool? value) {
                      setState(() {
                        isAmazon = value ?? false;
                      });
                    },
                  ),
                  if (isAmazon)
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: '紹介ID (tag)',
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    final newItem = {
                      "url": urlString,
                      "affiliatePlatform": isAmazon ? 'amazon' : null,
                      "affiliateId": isAmazon ? idController.text.trim() : null,
                    };
                    _updateAffiliate(currentUrls, oldItem, newItem);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _savePolicy() {
    (widget.firestore ?? FirebaseFirestore.instance)
        .collection('settings')
        .doc('config')
        .set({'scrapingPolicy': _policyController.text}, SetOptions(merge: true));
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
                      final item = targetUrls[index];
                      String urlString = '';
                      if (item is Map) {
                        urlString = item['url']?.toString() ?? '';
                      } else {
                        urlString = item.toString();
                      }

                      return ListTile(
                        title: Text(urlString, style: const TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.monetization_on, color: Colors.amber),
                              onPressed: () => _showAffiliateDialog(context, targetUrls, item, urlString),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeUrl(targetUrls, item),
                            ),
                          ],
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
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _policyController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: '調査方針',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.green, size: 36),
                  onPressed: _savePolicy,
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
