import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plant_detection/core/services/database_helper.dart';
import 'package:plant_detection/features/scanner/result_screen.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Map<String, dynamic>> _scans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final scans = await DatabaseHelper.instance.getAllScans();
    setState(() {
      _scans = scans;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scans.isEmpty
          ? const Center(child: Text('No scan history found.'))
          : ListView.builder(
              itemCount: _scans.length,
              itemBuilder: (context, index) {
                final scan = _scans[index];
                final isHealthy = scan['isHealthy'] == 1;
                final date = DateTime.tryParse(scan['scanDate'] ?? '');
                final dateStr = date != null
                    ? DateFormat.yMMMd().format(date)
                    : 'Unknown Date';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          scan['imagePath'] != null &&
                              File(scan['imagePath']).existsSync()
                          ? Image.file(
                              File(scan['imagePath']),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.image_not_supported, size: 50),
                    ),
                    title: Text(
                      scan['plantDetected'] ?? 'Unknown Plant',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHealthy
                              ? 'Healthy 🌱'
                              : 'Disease: ${scan['diseaseDetected']?.replaceAll('_', ' ')}',
                          style: TextStyle(
                            color: isHealthy ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(dateStr, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(
                            imagePath: scan['imagePath'],
                            inferenceResult: {
                              'plant': scan['plantDetected'],
                              'disease': scan['diseaseDetected'],
                              'confidence': double.tryParse(
                                scan['diseaseConfidence'] ?? '0.0',
                              ),
                              'isHealthy': isHealthy,
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
