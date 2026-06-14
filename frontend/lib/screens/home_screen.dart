import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/webview_screen.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'url_manager_dialog.dart';
import 'debug_log_screen.dart';
import '../utils/debug_log_manager.dart';

class HomeScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const HomeScreen({super.key, this.firestore});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLocationFilterEnabled = false;
  final GeoHasher _geoHasher = GeoHasher();

  static const String scraperUrl = 'https://asia-northeast1-otokuapp.cloudfunctions.net/scrapeCampaign';

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
      ).timeout(const Duration(seconds: 45));

      DebugLogManager.addLog('Response received: Status Code: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['count'] ?? 0;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scraping completed! Found $count campaigns.')),
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

  // Test coordinates from requirements: latitude 35.6247, longitude 139.4244
  // Note that GeoHasher.encode parameters are (longitude, latitude)
  Stream<QuerySnapshot> _getCampaignsStream() {
    var collection = (widget.firestore ?? FirebaseFirestore.instance).collection('campaigns');

    if (_isLocationFilterEnabled) {
      // Encode coordinates with a precision of 5 (adjust length as needed)
      String prefix = _geoHasher.encode(139.4244, 35.6247, precision: 5);
      return collection
          .where('geohash', isGreaterThanOrEqualTo: prefix)
          .where('geohash', isLessThan: prefix + '\uf8ff')
          .snapshots();
    }

    return collection.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Row(
            children: [
              const Text('現在地周辺のみ表示'),
              Switch(
                value: _isLocationFilterEnabled,
                onChanged: (value) {
                  setState(() {
                    _isLocationFilterEnabled = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(width: 16),
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

          if (data.size == 0) {
            return const Center(child: Text('No campaigns found.'));
          }

          return ListView.builder(
            itemCount: data.size,
            itemBuilder: (context, index) {
              final document = data.docs[index];
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
