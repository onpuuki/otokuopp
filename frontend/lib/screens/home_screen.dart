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
import 'scraping_log_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

enum SortOption { none, tagAsc, tagDesc, storeAsc, storeDesc }

class FilterCondition {
  String keyword;
  String logicalOperator; // 'AND' or 'OR'

  FilterCondition({this.keyword = '', this.logicalOperator = 'AND'});

  Map<String, dynamic> toJson() => {
        'keyword': keyword,
        'logicalOperator': logicalOperator,
      };

  factory FilterCondition.fromJson(Map<String, dynamic> json) =>
      FilterCondition(
        keyword: json['keyword'] as String? ?? '',
        logicalOperator: json['logicalOperator'] as String? ?? 'AND',
      );
}

class HomeScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const HomeScreen({super.key, this.firestore});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FilterCondition> _filterConditions = [FilterCondition()];
  Set<String> _selectedTypes = {};
  Set<String> _selectedStores = {};
  List<QueryDocumentSnapshot> _currentDocs = [];
  SortOption _currentSort = SortOption.none;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Color? _getCardColor(String tag) {
    if (tag.contains('キャンペーン')) return Colors.orange.shade100;
    if (tag.contains('抽選')) return Colors.blue.shade100;
    if (tag.contains('ポイント')) return Colors.green.shade100;
    return null;
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final conditionsString = prefs.getString('filterConditions');
    final typesString = prefs.getStringList('selectedTypes');
    final storesString = prefs.getStringList('selectedStores');

    setState(() {
      if (conditionsString != null) {
        final List<dynamic> decoded = jsonDecode(conditionsString);
        _filterConditions =
            decoded.map((e) => FilterCondition.fromJson(e)).toList();
        if (_filterConditions.isEmpty) {
          _filterConditions.add(FilterCondition());
        }
      }
      if (typesString != null) {
        _selectedTypes = typesString.toSet();
      }
      if (storesString != null) {
        _selectedStores = storesString.toSet();
      }
    });
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final conditionsString =
        jsonEncode(_filterConditions.map((e) => e.toJson()).toList());
    await prefs.setString('filterConditions', conditionsString);
    await prefs.setStringList('selectedTypes', _selectedTypes.toList());
    await prefs.setStringList('selectedStores', _selectedStores.toList());
  }

  @override
  void dispose() {
    super.dispose();
  }

  static const String scraperUrl =
      'https://asia-northeast1-otokuapp.cloudfunctions.net/startScraping';

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('並び替え'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortOption>(
                title: const Text('お得情報種別(昇順)'),
                value: SortOption.tagAsc,
                groupValue: _currentSort,
                onChanged: (SortOption? value) {
                  if (value != null) {
                    setState(() {
                      _currentSort = value;
                    });
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('お得情報種別(降順)'),
                value: SortOption.tagDesc,
                groupValue: _currentSort,
                onChanged: (SortOption? value) {
                  if (value != null) {
                    setState(() {
                      _currentSort = value;
                    });
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('店舗別(昇順)'),
                value: SortOption.storeAsc,
                groupValue: _currentSort,
                onChanged: (SortOption? value) {
                  if (value != null) {
                    setState(() {
                      _currentSort = value;
                    });
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('店舗別(降順)'),
                value: SortOption.storeDesc,
                groupValue: _currentSort,
                onChanged: (SortOption? value) {
                  if (value != null) {
                    setState(() {
                      _currentSort = value;
                    });
                    Navigator.pop(dialogContext);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _triggerScraping() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('スクレイピングを開始しました（バックグラウンドで処理されます）')),
    );

    DebugLogManager.addLog('Scraping started: sending request to $scraperUrl');

    try {
      // Fire-and-forget: do not wait for the response to prevent timeout/sleep interruptions
      http.post(
        Uri.parse(scraperUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'urls': [],
          'isManual': true,
        }), // Default empty array and manual flag
      ).then((response) {
        DebugLogManager.addLog(
            'Response received: Status Code: ${response.statusCode}, Body: ${response.body}');
      }).catchError((e) {
        DebugLogManager.addLog('Scraping background error: $e');
      });
    } catch (e) {
      DebugLogManager.addLog('Scraping error: $e');
    }
  }

  Future<void> _resetScraping() async {
    const String resetUrl = 'https://asia-northeast1-otokuapp.cloudfunctions.net/resetScraping';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('リセット処理中...')),
    );

    DebugLogManager.addLog('Reset Scraping started: sending request to $resetUrl');

    try {
      final response = await http
          .post(
            Uri.parse(resetUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 120));

      DebugLogManager.addLog(
          'Reset Response received: Status Code: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リセットが完了しました')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('リセット失敗: ${response.statusCode}')),
        );
      }
    } on TimeoutException catch (e) {
      DebugLogManager.addLog('Reset timeout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通信がタイムアウトしました。もう一度お試しください。')),
      );
    } catch (e) {
      DebugLogManager.addLog('Reset error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

  Stream<QuerySnapshot> _getCampaignsStream() {
    return (widget.firestore ?? FirebaseFirestore.instance)
        .collection('campaigns')
        .snapshots();
  }

  void _showStoreSelectionDialog(BuildContext context, Function setModalState) {
    final uniqueStores = _currentDocs
        .map((doc) =>
            (doc.data() as Map<String, dynamic>)['storeName'] as String?)
        .where((name) => name != null && name.trim().isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('店舗を選択'),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: uniqueStores.length,
                    itemBuilder: (context, index) {
                      final storeName = uniqueStores[index];
                      return CheckboxListTile(
                        title: Text(storeName),
                        value: _selectedStores.contains(storeName),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              _selectedStores.add(storeName);
                            } else {
                              _selectedStores.remove(storeName);
                            }
                          });
                          setState(() {});
                          setModalState(() {});
                          _saveFilters();
                        },
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('確定'),
                ),
              ],
            );
          },
        );
      },
    );
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
                        const Text('絞り込み',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filterConditions.length,
                      itemBuilder: (context, index) {
                        final condition = _filterConditions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              if (index > 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 8.0),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: condition.logicalOperator == 'AND'
                                        ? Colors.blue.shade100
                                        : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4.0),
                                    border: Border.all(
                                      color: condition.logicalOperator == 'AND'
                                          ? Colors.blue
                                          : Colors.green,
                                    ),
                                  ),
                                  child: Text(
                                    condition.logicalOperator,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: condition.logicalOperator == 'AND'
                                          ? Colors.blue.shade900
                                          : Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText:
                                        index == 0 ? 'キーワード検索' : '追加キーワード',
                                    border: const OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                      text: condition.keyword)
                                    ..selection = TextSelection.collapsed(
                                        offset: condition.keyword.length),
                                  onChanged: (value) {
                                    condition.keyword = value;
                                    _saveFilters();
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _filterConditions.insert(
                                        index + 1,
                                        FilterCondition(
                                            logicalOperator: 'AND'));
                                  });
                                  _saveFilters();
                                  setModalState(() {});
                                },
                                child: const Text('AND'),
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _filterConditions.insert(index + 1,
                                        FilterCondition(logicalOperator: 'OR'));
                                  });
                                  _saveFilters();
                                  setModalState(() {});
                                },
                                child: const Text('OR'),
                              ),
                              if (index > 0)
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                      _filterConditions.removeAt(index);
                                    });
                                    _saveFilters();
                                    setModalState(() {});
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('情報の種別',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                            _saveFilters();
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showStoreSelectionDialog(context, setModalState),
                      icon: const Icon(Icons.store),
                      label: const Text('店舗を選択'),
                    ),
                    if (_selectedStores.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Wrap(
                          spacing: 8.0,
                          children: _selectedStores.map((store) {
                            return InputChip(
                              label: Text(store),
                              onDeleted: () {
                                setState(() {
                                  _selectedStores.remove(store);
                                });
                                setModalState(() {});
                                _saveFilters();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text('確認'),
                                content: const Text('本当にフィルタ設定をクリアしますか？'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                    },
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(
                                          dialogContext); // Close dialog

                                      setState(() {
                                        _filterConditions = [FilterCondition()];
                                        _selectedTypes.clear();
                                        _selectedStores.clear();
                                      });
                                      setModalState(() {});

                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.remove('filterConditions');
                                      await prefs.remove('selectedTypes');
                                      await prefs.remove('selectedStores');
                                    },
                                    child: const Text('はい'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text('フィルタをクリア'),
                      ),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('絞り込み'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  _showFilterBottomSheet(context);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.sort, size: 18),
                label: const Text('並び替え'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  _showSortDialog(context);
                },
              ),
              const SizedBox(width: 8),
            ],
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
              leading: const Icon(Icons.history),
              title: const Text('スクレイピングログ確認'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => ScrapingLogModal(firestore: widget.firestore),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('スクレイピングリセット'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('確認'),
                      content: const Text('現在のスクレイピング結果をすべて削除します。よろしいですか？'),
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
                            _resetScraping();
                          },
                          child: const Text('OK'),
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
                  MaterialPageRoute(
                      builder: (context) =>
                          ScrapingStatusScreen(firestore: widget.firestore)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('デバッグログ'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DebugLogScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('情報取得先URL'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      UrlManagerDialog(firestore: widget.firestore),
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
                  if (data != null &&
                      data.containsKey('isAutoScrapingEnabled')) {
                    isAutoScrapingEnabled =
                        data['isAutoScrapingEnabled'] as bool;
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
                        .set({'isAutoScrapingEnabled': value},
                            SetOptions(merge: true));
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

          final filteredDocs = _currentDocs.where((doc) {
            final campaign = doc.data()! as Map<String, dynamic>;
            final title = campaign['title'] as String? ?? '';
            final storeName = campaign['storeName'] as String? ?? '';
            final details = campaign['details'] as String? ?? '';

            final combinedText = '$title $storeName $details'.toLowerCase();

            bool currentResult = true;
            bool isFirstValidCondition = true;

            for (int i = 0; i < _filterConditions.length; i++) {
              final condition = _filterConditions[i];
              final kw = condition.keyword.toLowerCase().trim();
              if (kw.isEmpty) continue;

              final contains = combinedText.contains(kw);

              if (isFirstValidCondition) {
                currentResult = contains;
                isFirstValidCondition = false;
              } else {
                if (condition.logicalOperator == 'AND') {
                  currentResult = currentResult && contains;
                } else if (condition.logicalOperator == 'OR') {
                  currentResult = currentResult || contains;
                }
              }
            }

            if (!currentResult && !isFirstValidCondition) {
              return false;
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

            if (_selectedStores.isNotEmpty) {
              if (!_selectedStores.contains(storeName)) {
                return false;
              }
            }

            return true;
          }).toList();

          filteredDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>? ?? {};
            final bData = b.data() as Map<String, dynamic>? ?? {};

            String getSafeString(Map<String, dynamic> data, String key) {
              if (data.containsKey(key) && data[key] != null) {
                return data[key].toString();
              }
              return '';
            }

            switch (_currentSort) {
              case SortOption.tagAsc:
                final aVal = getSafeString(aData, 'mainTag');
                final bVal = getSafeString(bData, 'mainTag');
                return aVal.compareTo(bVal);
              case SortOption.tagDesc:
                final aVal = getSafeString(aData, 'mainTag');
                final bVal = getSafeString(bData, 'mainTag');
                return bVal.compareTo(aVal);
              case SortOption.storeAsc:
                final aVal = getSafeString(aData, 'storeName');
                final bVal = getSafeString(bData, 'storeName');
                return aVal.compareTo(bVal);
              case SortOption.storeDesc:
                final aVal = getSafeString(aData, 'storeName');
                final bVal = getSafeString(bData, 'storeName');
                return bVal.compareTo(aVal);
              case SortOption.none:
                return 0;
            }
          });

          if (filteredDocs.isEmpty) {
            return const Center(child: Text('No campaigns found.'));
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final document = filteredDocs[index];
              final campaign = document.data()! as Map<String, dynamic>;

              final title = campaign['title'] as String? ?? 'No Title';
              final storeName =
                  campaign['storeName'] as String? ?? 'No Store Name';
              final details = campaign['details'] as String? ?? 'No Details';
              final url = campaign['url'] as String? ?? 'https://google.com';
              final isAffiliate = campaign['isAffiliate'] as bool? ?? false;

              final String mainTagStr = (document.data() as Map<String, dynamic>).containsKey('mainTag')
                  ? (document['mainTag'] ?? '').toString()
                  : '';

              String? publishedAtString;
              if ((document.data() as Map<String, dynamic>).containsKey('publishedAt')) {
                final dynamic publishedAtDynamic = document['publishedAt'];
                if (publishedAtDynamic is Timestamp) {
                  final DateTime dateTime = publishedAtDynamic.toDate();
                  publishedAtString = '${DateFormat('yyyy/MM/dd').format(dateTime)}に掲載';
                }
              }

              debugPrint('Card Render: $mainTagStr -> ${_getCardColor(mainTagStr)}');

              return Card(
                surfaceTintColor: Colors.transparent,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () async {
                    if (isAffiliate) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        // fallback to webview if launchUrl fails
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebViewScreen(url: url),
                            ),
                          );
                        }
                      }
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewScreen(url: url),
                        ),
                      );
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: _getCardColor(mainTagStr),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 16, color: Colors.black54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    storeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (publishedAtString != null) ...[
                                  const Spacer(),
                                  Text(
                                    publishedAtString,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const Divider(height: 16, thickness: 1, color: Colors.black12),
                            Text(
                              details,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            if (isAffiliate)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '#PR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
