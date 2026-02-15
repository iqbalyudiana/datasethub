import 'dart:io';
import 'package:flutter/material.dart';

class DatasetViewerScreen extends StatefulWidget {
  final Directory datasetDir;

  const DatasetViewerScreen({super.key, required this.datasetDir});

  @override
  State<DatasetViewerScreen> createState() => _DatasetViewerScreenState();
}

class _DatasetViewerScreenState extends State<DatasetViewerScreen> {
  List<File> _images = [];
  bool _isLoading = true;
  final Set<String> _selectedImagePaths = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      if (await widget.datasetDir.exists()) {
        final List<FileSystemEntity> entities = widget.datasetDir
            .listSync()
            .toList();

        final images = entities.whereType<File>().where((file) {
          final lowerPath = file.path.toLowerCase();
          return lowerPath.endsWith('.jpg') ||
              lowerPath.endsWith('.jpeg') ||
              lowerPath.endsWith('.png');
        }).toList();

        // Sort by modification time (newest first)
        images.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );

        if (mounted) {
          setState(() {
            _images = images;
            _isLoading = false;
            _selectedImagePaths.clear();
            _isSelectionMode = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _images = [];
            _isLoading = false;
            _selectedImagePaths.clear();
            _isSelectionMode = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading images: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      }
    });
  }

  Future<void> _deleteSelectedImages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Images'),
        content: Text(
          'Are you sure you want to delete ${_selectedImagePaths.length} image(s)? This cannot be undone.',
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

      for (final path in _selectedImagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting $path: $e');
        }
      }

      await _loadImages();
    }
  }

  void _openGallery(int index) {
    if (_isSelectionMode) {
      _toggleSelection(_images[index].path);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _GalleryPhotoViewWrapper(images: _images, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderName = widget.datasetDir.path.split('/').last;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              _isSelectionMode
                  ? '${_selectedImagePaths.length} Selected'
                  : folderName,
            ),
            pinned: true,
            expandedHeight: 120.0,
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedImagePaths.clear();
                        _isSelectionMode = false;
                      });
                    },
                  )
                : const BackButton(),
            actions: [
              if (_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: _deleteSelectedImages,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade800, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: _isSelectionMode
                  ? null
                  : Text(
                      '${_images.length} items',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_images.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No images found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final imageFile = _images[index];
                  final isSelected = _selectedImagePaths.contains(
                    imageFile.path,
                  );

                  return GestureDetector(
                    onTap: () => _openGallery(index),
                    onLongPress: () {
                      setState(() {
                        _isSelectionMode = true;
                        _toggleSelection(imageFile.path);
                      });
                    },
                    child: Hero(
                      tag: imageFile.path,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.blueAccent,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                imageFile,
                                fit: BoxFit.cover,
                                cacheWidth: 300, // Optimize memory
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }, childCount: _images.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryPhotoViewWrapper extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const _GalleryPhotoViewWrapper({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_GalleryPhotoViewWrapper> createState() =>
      _GalleryPhotoViewWrapperState();
}

class _GalleryPhotoViewWrapperState extends State<_GalleryPhotoViewWrapper> {
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
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
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
          final imageFile = widget.images[index];
          return Hero(
            tag: imageFile.path,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(imageFile, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
