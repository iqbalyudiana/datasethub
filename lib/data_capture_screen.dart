import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'image_preview_screen.dart';
import 'widgets/custom_animations.dart';

class DataCaptureScreen extends StatefulWidget {
  final String folderName;
  final int frameSize;
  final int outputResolution;
  final int burstSize;
  final String datasetType;

  const DataCaptureScreen({
    super.key,
    required this.folderName,
    required this.frameSize,
    required this.outputResolution,
    required this.burstSize,
    this.datasetType = 'Classification',
  });

  @override
  State<DataCaptureScreen> createState() => _DataCaptureScreenState();
}

class _DataCaptureScreenState extends State<DataCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  int _currentBurstCount = 0;
  bool _isFlashOn = false;
  bool _showBlink = false;
  String? _lastCapturedImagePath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    var status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final firstCamera = cameras.first;
          // Frame Size determines the Capture Quality (ResolutionPreset)
          // Output Resolution determines the saved file size (processed later)
          ResolutionPreset preset;
          if (widget.frameSize <= 240) {
            preset = ResolutionPreset.low; // ~240p (QVGA) - Fast, Low Quality
          } else if (widget.frameSize <= 480) {
            preset = ResolutionPreset.medium; // ~480p (SD) - Standard
          } else if (widget.frameSize <= 720) {
            preset = ResolutionPreset.high; // ~720p (HD) - High Quality
          } else {
            preset = ResolutionPreset.veryHigh; // ~1080p (FHD) - Very High
          }

          _controller = CameraController(
            firstCamera,
            preset,
            enableAudio: false,
            // fps optimization could be added here if needed
          );

          _initializeControllerFuture = _controller!.initialize();
          await _initializeControllerFuture;
          // Set initial flash mode to off
          await _controller!.setFlashMode(FlashMode.off);
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }
        } else {
          _showError('No cameras found');
        }
      } catch (e) {
        _showError('Error initializing camera: $e');
      }
    } else {
      _showError('Camera permission denied');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized || _controller == null) return;

    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        setState(() {
          _isFlashOn = false;
        });
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
        setState(() {
          _isFlashOn = true;
        });
      }
    } catch (e) {
      _showError('Error toggling flash: $e');
    }
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _controller == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _currentBurstCount = 0;
    });

    try {
      await _initializeControllerFuture;

      // Save to application directory
      // Use logical structure: /Documents/{datasetType}/{folderName}/{timestamp}.jpg
      // Note: User wanted app internal storage but visible.
      // We will use: getExternalStorageDirectory (Android) or getApplicationDocumentsDirectory (others)
      // And append formatted path.

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      }
      directory ??= await getApplicationDocumentsDirectory();

      // Create folder structure: .../{datasetType}/{folderName}
      final datasetDir = Directory(
        '${directory.path}/${widget.datasetType}/${widget.folderName}',
      );
      if (!await datasetDir.exists()) {
        await datasetDir.create(recursive: true);
      }

      List<XFile> capturedFiles = [];

      // Phase 1: Rapid Capture
      // To achieve stable capture, we use a fixed 300ms delay.
      for (int i = 0; i < widget.burstSize; i++) {
        if (!mounted) break;

        // Fast capture
        final xFile = await _controller!.takePicture();
        capturedFiles.add(xFile);

        // Haptic Feedback
        await HapticFeedback.mediumImpact();

        // Visual feedback (Blink)
        setState(() {
          _showBlink = true;
        });
        await Future.delayed(const Duration(milliseconds: 50));
        setState(() {
          _showBlink = false;
        });

        // Minimal delay for stability (50ms)
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Phase 2: Processing & Saving
      if (mounted) {
        if (widget.burstSize > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing images... please wait.')),
          );
        }
      }

      for (int i = 0; i < capturedFiles.length; i++) {
        if (!mounted) break;

        setState(() {
          _currentBurstCount = i + 1;
        });

        final imageFile = File(capturedFiles[i].path);
        // Decode image
        final rawImage = img.decodeImage(await imageFile.readAsBytes());

        if (rawImage != null) {
          // 1. Crop
          final size = rawImage.width < rawImage.height
              ? rawImage.width
              : rawImage.height;
          final croppedImage = img.copyCrop(
            rawImage,
            x: (rawImage.width - size) ~/ 2,
            y: (rawImage.height - size) ~/ 2,
            width: size,
            height: size,
          );

          // 2. Resize
          final resizedImage = img.copyResize(
            croppedImage,
            width: widget.outputResolution,
            height: widget.outputResolution,
          );

          // Generate Metadata
          final now = DateTime.now();
          final timestampStr =
              "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
          final fileName =
              "${widget.folderName}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}_${now.millisecond.toString().padLeft(3, '0')}.jpg";

          // Draw Timestamp (Watermark)
          img.drawString(
            resizedImage,
            timestampStr,
            font: img.arial24,
            x: 20,
            y: resizedImage.height - 40,
            color: img.ColorRgb8(255, 255, 0), // Yellow for visibility
          );

          final savePath = '${datasetDir.path}/$fileName';

          // For Single Shot: Preview logic
          if (widget.burstSize == 1) {
            // Temporarily save to cache for preview
            final tempDir = await getTemporaryDirectory();
            final tempPath = '${tempDir.path}/temp_preview.jpg';
            await File(tempPath).writeAsBytes(img.encodeJpg(resizedImage));

            if (mounted) {
              // Ignore the lint about async gap for now as we are inside a logic flow
              // Navigate to Preview
              final shouldSave = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => ImagePreviewScreen(
                    imagePath: tempPath,
                    onSave: () => Navigator.pop(context, true),
                    onRetake: () => Navigator.pop(
                      context,
                      false,
                    ), // Returns false to discard
                  ),
                ),
              );

              if (shouldSave == true) {
                await File(tempPath).copy(savePath);
                await _saveMetadata(savePath, now); // Save Metadata
              }
            }
          } else {
            // Burst Mode: Auto Save directly
            await File(savePath).writeAsBytes(img.encodeJpg(resizedImage));
            await _saveMetadata(savePath, now); // Save Metadata
          }

          if (mounted) {
            setState(() {
              _lastCapturedImagePath = savePath;
            });
          }

          // Delete original temp file from camera
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        }
      }

      if (mounted && widget.burstSize > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved ${capturedFiles.length} images to ${widget.folderName}',
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Error capturing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentBurstCount = 0;
        });
      }
    }
  }

  Future<void> _saveMetadata(String imagePath, DateTime timestamp) async {
    try {
      final file = File(imagePath);
      final jsonPath = imagePath.replaceAll('.jpg', '.json');

      final metadata = {
        'filename': file.uri.pathSegments.last,
        'timestamp': timestamp.toIso8601String(),
        'dataset_type': widget.datasetType,
        'folder_name': widget.folderName,
        'output_resolution': widget.outputResolution,
        'frame_size': widget.frameSize,
        'capture_type': widget.burstSize > 1
            ? 'Burst (${widget.burstSize})'
            : 'Single',
      };

      await File(jsonPath).writeAsString(jsonEncode(metadata));
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.folderName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.outputResolution}px • ${widget.frameSize}x Quality',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.black54,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white),
        actions: [
          if (_isCameraInitialized)
            IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: _toggleFlash,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _isCameraInitialized
              ? CameraPreview(_controller!)
              : const Center(child: CircularProgressIndicator()),

          // Professional Scanner Overlay (CustomPainter)
          if (_isCameraInitialized)
            CustomPaint(
              painter: ScannerOverlayPainter(
                boxSize: MediaQuery.of(context).size.width * 0.9,
                borderRadius: 20,
              ),
              child: Container(),
            ),

          // Corner Guides (Separate from Painter to keep them white and crisp on top)
          if (_isCameraInitialized)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // No border, just corners
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CornerGuide(rotation: 0),
                        _CornerGuide(rotation: 90),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "${widget.frameSize}x${widget.frameSize}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CornerGuide(rotation: -90),
                        _CornerGuide(rotation: 180),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Gallery Thumbnail (Bottom Left)
          if (_lastCapturedImagePath != null)
            Positioned(
              left: 30,
              bottom: 30,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImagePreviewScreen(
                        imagePath: _lastCapturedImagePath!,
                        onSave: () =>
                            Navigator.pop(context), // Just close preview
                        onRetake: () => Navigator.pop(context), // Just close
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    image: DecorationImage(
                      image: FileImage(File(_lastCapturedImagePath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      'Processing $_currentBurstCount/${widget.burstSize}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Saving to storage...',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Blink Overlay
          if (_showBlink) Container(color: Colors.white.withValues(alpha: 0.8)),
        ],
      ),
      floatingActionButton: ScaleButton(
        onTap: _takePicture,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 4),
              ),
              child: const Center(
                child: Icon(Icons.circle, size: 50, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _CornerGuide extends StatelessWidget {
  final double rotation;

  const _CornerGuide({required this.rotation});

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: AlwaysStoppedAnimation(rotation / 360),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white, width: 4),
            left: BorderSide(color: Colors.white, width: 4),
          ),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double boxSize;
  final double borderRadius;

  ScannerOverlayPainter({required this.boxSize, this.borderRadius = 20.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the scan window rect centered in the canvas
    final scanWindow = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: boxSize,
      height: boxSize,
    );

    // 1. Create a path for the entire screen
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 2. Create a path for the rounded scan window
    final scanWindowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)),
      );

    // 3. Subtract the scan window path from the background path
    final path = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanWindowPath,
    );

    // 4. Draw the resulting path with a semi-transparent black paint
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
