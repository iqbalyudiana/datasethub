import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'services/structuring_service.dart';
import 'services/localization_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.get('select_dataset'))),
      ); // Potentially add specific error key if needed, or reuse select_dataset as hint
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
          documentsDir = await getExternalStorageDirectory();
        }
        documentsDir ??= await getApplicationDocumentsDirectory();
        final exportDir = Directory(
          '${documentsDir.path}/${widget.datasetType}/Exports',
        );

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
              content: Text(
                '${LocalizationService.get('structuring_complete')} ${zipFile.path}',
              ),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          LocalizationService.get('structuring_title'),
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
              title: "Metadata",
              icon: Icons.list_alt_rounded,
              color: Colors.teal,
              children: [
                CheckboxListTile(
                  title: Text(
                    LocalizationService.get('generate_metadata'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Creates a list of class names in the dataset root',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  value: _enableMetadata,
                  activeColor: Colors.teal,
                  onChanged: (val) => setState(() => _enableMetadata = val!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: "Export",
              icon: Icons.archive_outlined,
              color: Colors.orange,
              children: [
                CheckboxListTile(
                  title: Text(
                    LocalizationService.get('export_zip'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Compresses the dataset into a .zip file',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  value: _enableExport,
                  activeColor: Colors.orange,
                  onChanged: (val) => setState(() => _enableExport = val!),
                ),
              ],
            ),

            const SizedBox(height: 32),

            if (_isProcessing) ...[
              LinearProgressIndicator(value: _progress, color: Colors.teal),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _startStructuring,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    LocalizationService.get('run_structuring'),
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
