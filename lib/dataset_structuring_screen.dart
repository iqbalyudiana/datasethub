import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'services/structuring_service.dart';

class DatasetStructuringScreen extends StatefulWidget {
  final String datasetType;

  const DatasetStructuringScreen({
    super.key,
    this.datasetType = 'Classification',
  });

  @override
  State<DatasetStructuringScreen> createState() =>
      _DatasetStructuringScreenState();
}

class _DatasetStructuringScreenState extends State<DatasetStructuringScreen> {
  final StructuringService _structuringService = StructuringService();

  List<FileSystemEntity> _datasets = [];
  String? _selectedDatasetPath;

  bool _enableMetadata = true;
  bool _enableExport = false;

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDatasets();
  }

  Future<void> _loadDatasets() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      }
      directory ??= await getApplicationDocumentsDirectory();

      final classificationDir = Directory(
        '${directory.path}/${widget.datasetType}',
      );
      if (await classificationDir.exists()) {
        setState(() {
          _datasets = classificationDir
              .listSync()
              .whereType<Directory>()
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading datasets: $e');
    }
  }

  Future<void> _startStructuring() async {
    if (_selectedDatasetPath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a dataset')));
      return;
    }

    if (!_enableMetadata && !_enableExport) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one action')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Starting...';
    });

    try {
      final sourceDir = Directory(_selectedDatasetPath!);

      if (_enableMetadata) {
        setState(() => _statusMessage = 'Generating metadata...');
        final classes = await _structuringService.generateMetadata(sourceDir);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated metadata for ${classes.length} classes'),
            ),
          );
        }
      }

      if (_enableExport) {
        setState(() => _statusMessage = 'Compressing dataset...');
        Directory? documentsDir;
        if (Platform.isAndroid) {
          documentsDir =
              await getExternalStorageDirectory(); // Or external public?
          // Use external storage public folder if possible, but scoped storage might block.
          // Let's use app docs for now, user can find it.
          // Or better: /Classification/Exports to keep it inside app scope but visible?
        }
        documentsDir ??= await getApplicationDocumentsDirectory();
        final exportDir = Directory('${documentsDir.path}/Exports');

        final zipFile = await _structuringService.exportDataset(
          sourceDir,
          exportDir,
          (prog) {
            setState(() {
              _progress = prog;
              _statusMessage = 'Zipping: ${(prog * 100).toInt()}%';
            });
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported to ${zipFile.path}'),
              action: SnackBarAction(
                label: 'SHARE',
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(zipFile.path)],
                      text: 'Dataset Export',
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Completed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dataset Structuring')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedDatasetPath ?? 'dataset_dropdown'),
              decoration: const InputDecoration(
                labelText: 'Select Dataset',
                border: OutlineInputBorder(),
              ),
              items: _datasets.map((entity) {
                final name = entity.path.split('/').last;
                return DropdownMenuItem(value: entity.path, child: Text(name));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDatasetPath = value;
                });
              },
            ),
            const SizedBox(height: 24),

            CheckboxListTile(
              title: const Text('Generate Metadata (classes.txt)'),
              subtitle: const Text(
                'Creates a list of class names in the dataset root',
              ),
              value: _enableMetadata,
              onChanged: (val) => setState(() => _enableMetadata = val!),
            ),
            CheckboxListTile(
              title: const Text('Export to Zip'),
              subtitle: const Text('Compresses the dataset into a .zip file'),
              value: _enableExport,
              onChanged: (val) => setState(() => _enableExport = val!),
            ),
            const SizedBox(height: 32),

            if (_isProcessing) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(_statusMessage, textAlign: TextAlign.center),
            ] else
              ElevatedButton(
                onPressed: _startStructuring,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                ),
                child: const Text('Run Stucturing'),
              ),
          ],
        ),
      ),
    );
  }
}
