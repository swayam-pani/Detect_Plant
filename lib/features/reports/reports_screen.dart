import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:easy_localization/easy_localization.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  List<FileSystemEntity> _pdfFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = dir.listSync();

      final pdfs = files.where((file) {
        return file.path.toLowerCase().endsWith('.pdf');
      }).toList();

      // Sort by newest first
      pdfs.sort((a, b) {
        final statA = a.statSync();
        final statB = b.statSync();
        return statB.modified.compareTo(statA.modified);
      });

      if (mounted) {
        setState(() {
          _pdfFiles = pdfs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePdf(FileSystemEntity file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        _loadPdfs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reports'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfFiles.isEmpty
          ? Center(child: Text('No saved PDF reports found.'))
          : ListView.builder(
              itemCount: _pdfFiles.length,
              itemBuilder: (context, index) {
                final file = _pdfFiles[index];
                final String fileName = file.path
                    .split(Platform.pathSeparator)
                    .last;
                final stat = file.statSync();
                final String fileSize =
                    '${(stat.size / 1024).toStringAsFixed(1)} KB';

                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(fileName),
                  subtitle: Text(
                    '${stat.modified.toString().substring(0, 16)} • $fileSize',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _deletePdf(file),
                  ),
                  onTap: () async {
                    await OpenFile.open(file.path);
                  },
                );
              },
            ),
    );
  }
}
