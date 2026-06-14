import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/debug_log_manager.dart';

class DebugLogScreen extends StatelessWidget {
  const DebugLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('デバッグログ'),
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
      body: ValueListenableBuilder<List<String>>(
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
      ),
    );
  }
}
