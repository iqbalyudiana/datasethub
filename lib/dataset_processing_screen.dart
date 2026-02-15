// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/processing_service.dart';
import 'services/localization_service.dart';

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

  // Options
  bool _enableResize = true;
  final TextEditingController _widthController = TextEditingController(
    text: '224',
  );
  final TextEditingController _heightController = TextEditingController(
    text: '224',
  );
  bool _enableSplit = false;
  RangeValues _splitValues = const RangeValues(70, 90);

  bool _enableAugmentation = false;
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  bool _rotate = false;
  bool _grayscale = false;

  // Automated Labeling Options
  bool _generateLabels = true;
  bool _normalizeNames = true;
  bool _generateYolo = false;
  final TextEditingController _classIdController = TextEditingController(
    text: '0',
  );
  String _exportFormat = 'tree'; // 'tree' or 'yolo'

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
        generateLabels: _generateLabels,
        normalizeNames: _normalizeNames,
        generateYolo: _generateYolo,
        classId: int.tryParse(_classIdController.text) ?? 0,
        exportFormat: _exportFormat,
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
            content: Text(
              '${LocalizationService.get('processing_complete')} ${outputDir.path}',
            ),
            backgroundColor: Colors.green,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          LocalizationService.get('processing_title'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dataset Selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  hint: Text(
                    LocalizationService.get('select_dataset'),
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                  value: _selectedDatasetPath,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                  items: _datasets.map((entity) {
                    final name = entity.path.split('/').last;
                    return DropdownMenuItem(
                      value: entity.path,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDatasetPath = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              title: LocalizationService.get('preprocessing'),
              icon: Icons.aspect_ratio_rounded,
              color: Colors.blue,
              children: [
                SwitchListTile(
                  title: Text(
                    LocalizationService.get('resize_images'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  value: _enableResize,
                  activeTrackColor: Colors.blue,
                  onChanged: (val) => setState(() => _enableResize = val),
                ),
                if (_enableResize)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            decoration: const InputDecoration(
                              labelText: 'Width (px)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height (px)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: LocalizationService.get('automated_labeling'),
              icon: Icons.label_important_outline_rounded,
              color: Colors.purple,
              children: [
                SwitchListTile(
                  title: Text(
                    LocalizationService.get('normalize_filenames'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Rename to ClassName_0001.jpg',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  value: _normalizeNames,
                  activeTrackColor: Colors.purple,
                  onChanged: (val) => setState(() => _normalizeNames = val),
                ),
                SwitchListTile(
                  title: Text(
                    LocalizationService.get('generate_csv'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Creates dataset.csv',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  value: _generateLabels,
                  activeTrackColor: Colors.purple,
                  onChanged: (val) => setState(() => _generateLabels = val),
                ),
                SwitchListTile(
                  title: Text(
                    LocalizationService.get('generate_yolo'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Creates .txt per image (Default Box)',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  value: _generateYolo,
                  activeTrackColor: Colors.purple,
                  onChanged: (val) => setState(() => _generateYolo = val),
                ),
                if (_generateYolo)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: TextField(
                      controller: _classIdController,
                      decoration: const InputDecoration(
                        labelText: 'Class ID (Index)',
                        helperText: 'Integer ID for this class (e.g., 0, 1, 2)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: 'Export Format',
              icon: Icons.output_rounded,
              color: Colors.teal,
              children: [
                RadioListTile<String>(
                  title: const Text('Standard (Tree Structure)'),
                  subtitle: const Text('train/class_name/image.jpg'),
                  value: 'tree',
                  groupValue: _exportFormat,
                  activeColor: Colors.teal,
                  onChanged: (val) => setState(() => _exportFormat = val!),
                ),
                RadioListTile<String>(
                  title: const Text('YOLO Format'),
                  subtitle: const Text('data.yaml, train/images, train/labels'),
                  value: 'yolo',
                  groupValue: _exportFormat,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() {
                      _exportFormat = val!;
                      if (_exportFormat == 'yolo') {
                        _generateYolo = true;
                        _generateLabels = false;
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: LocalizationService.get('data_split'),
              icon: Icons.call_split_rounded,
              color: Colors.orange,
              children: [
                SwitchListTile(
                  title: Text(
                    LocalizationService.get('enable_splitting'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  value: _enableSplit,
                  activeTrackColor: Colors.orange,
                  onChanged: (val) => setState(() => _enableSplit = val),
                ),
                if (_enableSplit) ...[
                  RangeSlider(
                    values: _splitValues,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: Colors.orange,
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
                        Text(
                          'Train: ${_splitValues.start.round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Valid: ${(_splitValues.end - _splitValues.start).round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Test: ${(100 - _splitValues.end).round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: LocalizationService.get('augmentation'),
              icon: Icons.auto_fix_high_rounded,
              color: Colors.pink,
              children: [
                SwitchListTile(
                  title: Text(
                    LocalizationService.get('enable_augmentation'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  value: _enableAugmentation,
                  activeTrackColor: Colors.pink,
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
              ],
            ),
            const SizedBox(height: 32),

            if (_isProcessing) ...[
              LinearProgressIndicator(
                value: _progress,
                color: const Color(0xFF00695C),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF00695C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _startProcessing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    LocalizationService.get('start_processing'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1F4F9),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
