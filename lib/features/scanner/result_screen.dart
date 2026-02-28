import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:plant_detection/core/services/wikipedia_service.dart';
import 'package:plant_detection/core/services/database_helper.dart';
import 'package:plant_detection/core/services/pdf_service.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final Map<String, dynamic> inferenceResult;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.inferenceResult,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  Map<String, dynamic>? _wikiInfo;
  bool _isLoadingWiki = true;
  bool _isSaving = false;

  bool get _isPlantMode => widget.inferenceResult['mode'] == 'plant';

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    final label = widget.inferenceResult['plant'] as String? ?? 'Unknown';
    final mode = _isPlantMode ? InfoFetchMode.plant : InfoFetchMode.disease;
    final wikiService = ref.read(wikipediaServiceProvider);
    final info = await wikiService.fetchInfo(label, mode);

    if (mounted) {
      setState(() {
        _wikiInfo = info;
        _isLoadingWiki = false;
      });
      _saveScanToHistory();
    }
  }

  Future<void> _saveScanToHistory() async {
    setState(() {
      _isSaving = true;
    });
    final scan = {
      'imagePath': widget.imagePath,
      'plantDetected': widget.inferenceResult['plant'],
      'diseaseDetected': widget.inferenceResult['disease'],
      'diseaseConfidence': widget.inferenceResult['confidence']
          ?.toStringAsFixed(2),
      'isHealthy': (widget.inferenceResult['isHealthy'] ?? true) ? 1 : 0,
      'scanDate': DateTime.now().toIso8601String(),
    };
    await DatabaseHelper.instance.insertScan(scan);
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _getRiskStatus() {
    if (_isPlantMode) return 'N/A';
    final conf = widget.inferenceResult['confidence'] as double? ?? 0.0;
    if (conf > 0.8) return 'High Risk';
    if (conf > 0.5) return 'Moderate Risk';
    return 'Low Risk';
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.inferenceResult['plant'] as String? ?? 'Unknown';
    final confidence = widget.inferenceResult['confidence'] as double? ?? 0.0;
    final confPercent = (confidence * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: Text('analysis_result'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(widget.imagePath),
                height: 250,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),

            // Detection Summary Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Mode indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isPlantMode
                            ? Colors.green.withOpacity(0.15)
                            : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isPlantMode
                            ? '🌿 ${('detected_plant').tr()}'
                            : '🔬 ${('disease_detected').tr()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isPlantMode ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main result
                    Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isPlantMode
                                ? Colors.green
                                : Colors.deepOrange,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Confidence: $confPercent%',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    if (!_isPlantMode) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'status'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _getRiskStatus(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: confidence > 0.8 ? Colors.red : Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Wikipedia Info
            Text(
              'details'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _isLoadingWiki
                ? const Center(child: CircularProgressIndicator())
                : _wikiInfo != null
                ? Text(
                    _wikiInfo!['extract'] ??
                        'No detailed description available.',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  )
                : const Text(
                    'Could not fetch information from Wikipedia.',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),

            const SizedBox(height: 30),

            // PDF button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _isSaving = true;
                      });
                      try {
                        final pdfService = ref.read(pdfServiceProvider);
                        final riskStatus = _getRiskStatus();
                        final extract = _wikiInfo?['extract'] as String? ?? '';
                        await pdfService.generateAndPrintReport(
                          imagePath: widget.imagePath,
                          result: widget.inferenceResult,
                          riskStatus: riskStatus,
                          wikiExtract: extract,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Report saved! View it in the Reports section.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to generate PDF: $e'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSaving = false;
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text('download_pdf'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isSaving)
              const Text(
                'Saving to history...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
