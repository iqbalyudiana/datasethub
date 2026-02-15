import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'services/processing_service.dart';

class DatasetProcessingScreen extends StatefulWidget {
  final String datasetType;

  const DatasetProcessingScreen({
    super.key,
    this.datasetType = 'Classification',
  });

  @override
  State<DatasetProcessingScreen> createState() =>
      _DatasetProcessingScreenState();
}

class _DatasetProcessingScreenState extends State<DatasetProcessingScreen> {
  final ProcessingService _processingService = ProcessingService();

  List<FileSystemEntity> _datasets = [];
  String? _selectedDatasetPath;

  // Resize Options
  bool _enableResize = false;
  final TextEditingController _widthController = TextEditingController(
    text: '224',
  );
  final TextEditingController _heightController = TextEditingController(
    text: '224',
  );

  // Split Options
  bool _enableSplit = false;
  RangeValues _splitValues = const RangeValues(
    70,
    90,
  ); // 70% train, 20% valid, 10% test

  // Augmentation Options
  bool _enableAugmentation = false;
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  bool _rotate = false;
  bool _grayscale = false;

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

  Future<void> _startProcessing() async {
    if (_selectedDatasetPath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a dataset')));
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = 'Starting processing...';
    });

    try {
      final sourceDir = Directory(_selectedDatasetPath!);
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      }
      directory ??= await getApplicationDocumentsDirectory();

      final datasetName = sourceDir.path.split('/').last;
      // Save to ${datasetType} folder so it appears in the list
      // Append '_Processed' (or specific suffix based on ops) to avoid name collision
      final outputDir = Directory(
        '${directory.path}/${widget.datasetType}/${datasetName}_Processed',
      );

      await _processingService.processDataset(
        sourceDir: sourceDir,
        outputDir: outputDir,
        resize: _enableResize,
        targetWidth: int.tryParse(_widthController.text) ?? 224,
        targetHeight: int.tryParse(_heightController.text) ?? 224,
        augment: _enableAugmentation,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
        rotate: _rotate,
        grayscale: _grayscale,
        split: _enableSplit,
        trainSplit: _splitValues.start / 100,
        validSplit: (_splitValues.end - _splitValues.start) / 100,
        testSplit: (100 - _splitValues.end) / 100,
        onProgress: (current, total) {
          setState(() {
            _progress = current / total;
            _statusMessage = 'Processing image $current of $total';
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing complete! Saved to ${outputDir.path}'),
          ),
        );
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
      appBar: AppBar(title: const Text('Dataset Processing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dataset Selection
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedDatasetPath ?? 'dataset_dropdown'),
              decoration: const InputDecoration(
                labelText: 'Select Dataset',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedDatasetPath,
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

            // Resize Options
            SwitchListTile(
              title: const Text('Resize Images'),
              value: _enableResize,
              onChanged: (val) => setState(() => _enableResize = val),
            ),
            if (_enableResize)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _widthController,
                      decoration: const InputDecoration(labelText: 'Width'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      decoration: const InputDecoration(labelText: 'Height'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            const Divider(),

            // Split Options
            SwitchListTile(
              title: const Text('Split Dataset'),
              subtitle: const Text('Train / Validation / Test'),
              value: _enableSplit,
              onChanged: (val) => setState(() => _enableSplit = val),
            ),
            if (_enableSplit) ...[
              RangeSlider(
                values: _splitValues,
                min: 0,
                max: 100,
                divisions: 20,
                labels: RangeLabels(
                  '${_splitValues.start.round()}%',
                  '${_splitValues.end.round()}%',
                ),
                onChanged: (values) {
                  setState(() {
                    _splitValues = values;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Train: ${_splitValues.start.round()}%'),
                    Text(
                      'Valid: ${(_splitValues.end - _splitValues.start).round()}%',
                    ),
                    Text('Test: ${(100 - _splitValues.end).round()}%'),
                  ],
                ),
              ),
            ],
            const Divider(),

            // Augmentation Options
            SwitchListTile(
              title: const Text('Data Augmentation'),
              value: _enableAugmentation,
              onChanged: (val) => setState(() => _enableAugmentation = val),
            ),
            if (_enableAugmentation) ...[
              CheckboxListTile(
                title: const Text('Flip Horizontal'),
                value: _flipHorizontal,
                onChanged: (val) => setState(() => _flipHorizontal = val!),
              ),
              CheckboxListTile(
                title: const Text('Flip Vertical'),
                value: _flipVertical,
                onChanged: (val) => setState(() => _flipVertical = val!),
              ),
              CheckboxListTile(
                title: const Text('Rotate (+/- 15°)'),
                value: _rotate,
                onChanged: (val) => setState(() => _rotate = val!),
              ),
              CheckboxListTile(
                title: const Text('Grayscale'),
                value: _grayscale,
                onChanged: (val) => setState(() => _grayscale = val!),
              ),
            ],
            const SizedBox(height: 32),

            if (_isProcessing) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(_statusMessage, textAlign: TextAlign.center),
            ] else
              ElevatedButton(
                onPressed: _startProcessing,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                ),
                child: const Text('Process Dataset'),
              ),
          ],
        ),
      ),
    );
  }
}
