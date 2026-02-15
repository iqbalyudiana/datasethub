import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/localization_service.dart';
import 'screens/annotation_screen.dart';

class DatasetViewerScreen extends StatefulWidget {
  final Directory datasetDir;

  const DatasetViewerScreen({super.key, required this.datasetDir});

  @override
  State<DatasetViewerScreen> createState() => _DatasetViewerScreenState();
}

class _DatasetViewerScreenState extends State<DatasetViewerScreen> {
  List<FileSystemEntity> _images = [];
  final Set<String> _selectedImagePaths = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    try {
      final List<FileSystemEntity> files = widget.datasetDir
          .listSync()
          .where(
            (file) =>
                file.path.toLowerCase().endsWith('.jpg') ||
                file.path.toLowerCase().endsWith('.png') ||
                file.path.toLowerCase().endsWith('.jpeg'),
          )
          .toList();
      setState(() {
        _images = files;
      });
    } catch (e) {
      debugPrint("Error loading images: $e");
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedImagePaths.contains(path)) {
        _selectedImagePaths.remove(path);
        if (_selectedImagePaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedImagePaths.add(path);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          LocalizationService.get('delete_images'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${LocalizationService.get('delete_confirmation')} ${_selectedImagePaths.length} ${LocalizationService.get('images')}?',
          style: GoogleFonts.inter(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              LocalizationService.get('cancel'),
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              LocalizationService.get('delete'),
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final path in _selectedImagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint("Error deleting: $e");
        }
      }
      setState(() {
        _selectedImagePaths.clear();
        _isSelectionMode = false;
      });
      _loadImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderName = widget.datasetDir.path.split('/').last;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedImagePaths.length} ${LocalizationService.get('selected')}'
              : folderName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isSelectionMode
                    ? const SizedBox.shrink()
                    : Text(
                        '${_images.length} ${LocalizationService.get('items')}',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                if (_isSelectionMode)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedImagePaths.length == _images.length) {
                          _selectedImagePaths.clear();
                          _isSelectionMode = false;
                        } else {
                          for (var img in _images) {
                            _selectedImagePaths.add(img.path);
                          }
                        }
                      });
                    },
                    child: Text(
                      _selectedImagePaths.length == _images.length
                          ? "Deselect All"
                          : "Select All",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _images.isEmpty
                ? Center(
                    child: Text(
                      LocalizationService.get('no_images'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final file = _images[index];
                      final isSelected = _selectedImagePaths.contains(
                        file.path,
                      );

                      return GestureDetector(
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(file.path);
                          } else {
                            _showImageDetail(index);
                          }
                        },
                        onLongPress: () => _toggleSelection(file.path),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(file.path),
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                              ),
                            ),
                            if (_isSelectionMode)
                              Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child: isSelected
                                    ? const Center(
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showImageDetail(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _ImageDetailScreen(images: _images, initialIndex: initialIndex),
      ),
    );
  }
}

class _ImageDetailScreen extends StatefulWidget {
  final List<FileSystemEntity> images;
  final int initialIndex;

  const _ImageDetailScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<_ImageDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnnotationScreen(
                    imageFile: File(widget.images[_currentIndex].path),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_square, color: Colors.white),
            label: Text(
              "Annotate",
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              child: Image.file(File(widget.images[index].path)),
            ),
          );
        },
      ),
    );
  }
}
