import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/webview_screen.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'url_manager_dialog.dart';
import 'debug_log_screen.dart';
import '../utils/debug_log_manager.dart';
import 'scraping_status_screen.dart';

class HomeScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const HomeScreen({super.key, this.firestore});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchKeyword = '';
  final Set<String> _selectedTypes = {};
  List<QueryDocumentSnapshot> _currentDocs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  static const String scraperUrl = 'https://asia-northeast1-otokuapp.cloudfunctions.net/startScraping';

  Future<void> _triggerScraping() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scraping started...')),
    );

    DebugLogManager.addLog('Scraping started: sending request to $scraperUrl');

    try {
      final response = await http.post(
        Uri.parse(scraperUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'urls': [],
          'isManual': true,
        }), // Default empty array and manual flag
      ).timeout(const Duration(seconds: 120));

      DebugLogManager.addLog('Response received: Status Code: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('バックグラウンドでスクレイピングを開始しました')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scraping failed: ${response.statusCode}')),
        );
      }
    } on TimeoutException catch (e) {
      DebugLogManager.addLog('Scraping timeout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通信がタイムアウトしました。もう一度お試しください。')),
      );
    } catch (e) {
      DebugLogManager.addLog('Scraping error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Stream<QuerySnapshot> _getCampaignsStream() {
    return (widget.firestore ?? FirebaseFirestore.instance).collection('campaigns').snapshots();
  }


  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('絞り込み', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'キーワード検索',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchKeyword = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('情報の種別', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      children: ['キャンペーン', 'ポイント', '抽選'].map((type) {
                        return FilterChip(
                          label: Text(type),
                          selected: _selectedTypes.contains(type),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTypes.add(type);
                              } else {
                                _selectedTypes.remove(type);
                              }
                            });
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Text(
                'デバッグメニュー',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('手動スクレイピング'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('確認'),
                      content: const Text('本当に実行しますか？'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext); // Cancel
                          },
                          child: const Text('キャンセル'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext); // Close dialog
                            _triggerScraping();
                          },
                          child: const Text('実行'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('スクレイピング状況'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ScrapingStatusScreen(firestore: widget.firestore)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('デバッグログ'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DebugLogScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('情報取得先URL'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => UrlManagerDialog(firestore: widget.firestore),
                );
              },
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: (widget.firestore ?? FirebaseFirestore.instance)
                  .collection('settings')
                  .doc('config')
                  .snapshots(),
              builder: (context, snapshot) {
                bool isAutoScrapingEnabled = true; // default value
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null && data.containsKey('isAutoScrapingEnabled')) {
                    isAutoScrapingEnabled = data['isAutoScrapingEnabled'] as bool;
                  }
                }
                return SwitchListTile(
                  secondary: const Icon(Icons.autorenew),
                  title: const Text('自動スクレイピング'),
                  value: isAutoScrapingEnabled,
                  onChanged: (bool value) {
                    (widget.firestore ?? FirebaseFirestore.instance)
                        .collection('settings')
                        .doc('config')
                        .set({'isAutoScrapingEnabled': value}, SetOptions(merge: true));
                  },
                );
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getCampaignsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;
          _currentDocs = data.docs;

          final keyword = _searchKeyword.toLowerCase().trim();

          List<String> orBlocks = [];
          if (keyword.isNotEmpty) {
            // Replace full-width or with half-width, ignoring case handled by lowercase()
            String normalizedKeyword = keyword.replaceAll(' or ', ' OR ').replaceAll('ｏｒ', ' OR ').replaceAll(' ＯＲ ', ' OR ');

            orBlocks = normalizedKeyword.split(' OR ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            if (orBlocks.isEmpty) {
              orBlocks = [normalizedKeyword];
            }
          }

          final filteredDocs = _currentDocs.where((doc) {
            final campaign = doc.data()! as Map<String, dynamic>;
            final title = campaign['title'] as String? ?? '';
            final storeName = campaign['storeName'] as String? ?? '';
            final details = campaign['details'] as String? ?? '';

            final combinedText = '$title $storeName $details'.toLowerCase();

            if (orBlocks.isNotEmpty) {
              bool matchesOr = false;
              for (String block in orBlocks) {
                // Replace AND with spaces to treat them all as AND delimiters
                String normalizedBlock = block.replaceAll(' and ', ' ').replaceAll('ａｎｄ', ' ').replaceAll('　', ' ');
                List<String> andKeywords = normalizedBlock.split(' ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

                bool matchesAnd = true;
                for (String andKw in andKeywords) {
                  if (!combinedText.contains(andKw)) {
                    matchesAnd = false;
                    break;
                  }
                }

                if (matchesAnd) {
                  matchesOr = true;
                  break;
                }
              }

              if (!matchesOr) {
                return false;
              }
            }

            if (_selectedTypes.isNotEmpty) {
              bool typeMatch = false;
              for (final type in _selectedTypes) {
                if (title.contains(type) || details.contains(type)) {
                  typeMatch = true;
                  break;
                }
              }
              if (!typeMatch) {
                return false;
              }
            }

            return true;
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text('No campaigns found.'));
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final document = filteredDocs[index];
              final campaign = document.data()! as Map<String, dynamic>;

              final title = campaign['title'] as String? ?? 'No Title';
              final storeName = campaign['storeName'] as String? ?? 'No Store Name';
              final details = campaign['details'] as String? ?? 'No Details';
              final url = campaign['url'] as String? ?? 'https://google.com';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebViewScreen(url: url),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          storeName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          details,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
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
