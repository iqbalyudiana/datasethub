import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dataset_config_screen.dart';
import 'dataset_viewer_screen.dart';
import 'dataset_processing_screen.dart';
import 'dataset_structuring_screen.dart';
import 'widgets/custom_animations.dart';

class DatasetGroupScreen extends StatefulWidget {
  final String title;
  final String datasetType;
  final IconData icon;
  final Color color;

  const DatasetGroupScreen({
    super.key,
    required this.title,
    required this.datasetType,
    required this.icon,
    required this.color,
  });

  @override
  State<DatasetGroupScreen> createState() => _DatasetGroupScreenState();
}

class _DatasetGroupScreenState extends State<DatasetGroupScreen> {
  List<FileSystemEntity> _datasets = [];
  bool _isLoading = true;
  final Set<String> _selectedPaths = {};
  bool _isSelectionMode = false;

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

      final datasetDir = Directory('${directory.path}/${widget.datasetType}');

      if (await datasetDir.exists()) {
        final List<FileSystemEntity> entities = datasetDir
            .listSync()
            .whereType<Directory>()
            .toList();
        setState(() {
          _datasets = entities;
          _isLoading = false;
          _selectedPaths.clear();
          _isSelectionMode = false;
        });
      } else {
        setState(() {
          _datasets = [];
          _isLoading = false;
          _selectedPaths.clear();
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading datasets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  Future<void> _deleteSelectedDatasets() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Datasets'),
        content: Text(
          'Are you sure you want to delete ${_selectedPaths.length} folder(s)? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      for (final path in _selectedPaths) {
        try {
          final dir = Directory(path);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (e) {
          debugPrint('Error deleting $path: $e');
        }
      }

      await _loadDatasets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedPaths.length} Selected' : widget.title,
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedPaths.clear();
                    _isSelectionMode = false;
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteSelectedDatasets,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDatasets,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (!_isSelectionMode) ...[
              FadeInSlide(
                index: 0,
                child: _LayerCard(
                  title: ' Data Capture ',
                  subtitle: 'Capture images using camera',
                  icon: Icons.camera_alt,
                  color: Colors.blueAccent,
                  items: const [
                    'Camera module',
                    'Frame handler',
                    'Auto naming',
                  ],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DatasetConfigScreen(
                          datasetType: widget.datasetType,
                        ),
                      ),
                    ).then((_) => _loadDatasets());
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Layer 2
              FadeInSlide(
                index: 1,
                child: _LayerCard(
                  title: 'Dataset Processing',
                  subtitle: 'Pre-process captured data',
                  icon: Icons.settings_system_daydream,
                  color: Colors.orangeAccent,
                  items: const [
                    'Resize engine',
                    'Split engine',
                    'Augmentation engine',
                  ],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DatasetProcessingScreen(
                          datasetType: widget.datasetType,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Layer 3
              FadeInSlide(
                index: 2,
                child: _LayerCard(
                  title: 'Dataset Structuring',
                  subtitle: 'Organize and export',
                  icon: Icons.folder_special,
                  color: Colors.greenAccent,
                  items: const [
                    'Folder generator',
                    'Metadata manager',
                    'Export builder',
                  ],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DatasetStructuringScreen(
                          datasetType: widget.datasetType,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              FadeInSlide(
                index: 3,
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Captured Datasets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_datasets.isEmpty)
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No datasets found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Data Capture" to start collecting images.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _datasets.length,
                itemBuilder: (context, index) {
                  final folder = _datasets[index];
                  final folderName = folder.path.split('/').last;
                  final isSelected = _selectedPaths.contains(folder.path);

                  return Card(
                    elevation: isSelected ? 4 : 0,
                    color: isSelected ? Colors.blue.shade50 : Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.blue : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.folder, color: widget.color),
                      ),
                      title: Text(
                        folderName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: FutureBuilder<int>(
                        future: Directory(folder.path).list().length,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              '${snapshot.data} images',
                              style: TextStyle(color: Colors.grey[600]),
                            );
                          }
                          return const Text('Calculating...');
                        },
                      ),
                      trailing: _isSelectionMode
                          ? Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected ? Colors.blue : Colors.grey,
                            )
                          : const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                      onLongPress: () {
                        setState(() {
                          _isSelectionMode = true;
                          _toggleSelection(folder.path);
                        });
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(folder.path);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DatasetViewerScreen(
                                datasetDir: Directory(folder.path),
                              ),
                            ),
                          ).then((_) => _loadDatasets());
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final List<String> items;
  final Color color;
  final VoidCallback? onTap;

  const _LayerCard({
    required this.title,
    required this.subtitle,
    this.icon,
    required this.items,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon ?? Icons.layers, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: color.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
