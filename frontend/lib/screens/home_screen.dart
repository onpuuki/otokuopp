import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/screens/webview_screen.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:http/http.dart' as http;

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

    try {
      final response = await http.post(
        Uri.parse(scraperUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'urls': []}), // Default empty array to trigger fallback URLs
      );

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
    } catch (e) {
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
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'デバッグ: スクレイピング実行',
            onPressed: _triggerScraping,
          ),
          const SizedBox(width: 16),
        ],
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
