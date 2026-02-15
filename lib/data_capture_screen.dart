import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
import 'image_preview_screen.dart';
import 'widgets/custom_animations.dart';
import 'services/localization_service.dart';

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

enum CaptureMode { manual, interval, motion }

class _DataCaptureScreenState extends State<DataCaptureScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  int _currentBurstCount = 0;
  bool _isFlashOn = false;
  bool _showBlink = false;
  String? _lastCapturedImagePath;
  late AnimationController _focusController;
  late Animation<double> _focusAnimation;

  // Advanced Camera Settings
  FocusMode _focusMode = FocusMode.auto;
  ExposureMode _exposureMode = ExposureMode.auto;
  CaptureMode _captureMode = CaptureMode.manual;

  // Strategy Params
  int _intervalDurationMs = 1000;
  double _motionSensitivity = 50.0; // Threshold 0-100

  // Strategy State
  Timer? _intervalTimer;
  bool _isCapturingActive = false;
  // Motion Capture Logic (Placeholder)
  // img.Image? _previousMotionFrame;
  // bool _isMotionProcessing = false;
  // int _motionCooldown = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _focusAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
    );
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
            imageFormatGroup: Platform.isAndroid
                ? ImageFormatGroup.jpeg
                : ImageFormatGroup.bgra8888,
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
          _showError(LocalizationService.get('no_cameras'));
        }
      } catch (e) {
        _showError('${LocalizationService.get('camera_init_error')}: $e');
      }
    } else {
      _showError('Camera permission denied');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusController.dispose();
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
        await HapticFeedback.heavyImpact();

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
            SnackBar(
              content: Text(LocalizationService.get('processing_images')),
              backgroundColor: Colors.black87,
            ),
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
          // 1. Crop (Always Center Crop for Square Output)
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
            interpolation: img.Interpolation.cubic,
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
              '${LocalizationService.get('saved_images')} ${capturedFiles.length} ${LocalizationService.get('images')} to ${widget.folderName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('${LocalizationService.get('capture_error')}: $e');
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
    final size = MediaQuery.of(context).size;
    final squareSize = math.min(size.width, size.height) * 0.9;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.folderName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellowAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.frameSize}x ${LocalizationService.get('quality')}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.yellowAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'To: ${widget.outputResolution}px',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        toolbarHeight: 70,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isCameraInitialized)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(
                  _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: _isFlashOn ? Colors.yellow : Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
                onPressed: _toggleFlash,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
              ),
              onPressed: _showSettings,
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _isCameraInitialized
              ? CameraPreview(_controller!)
              : const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                ),

          // Professional Scanner Overlay (CustomPainter)
          if (_isCameraInitialized)
            CustomPaint(
              painter: ScannerOverlayPainter(
                boxSize: squareSize,
                borderRadius: 24,
              ),
              child: Container(),
            ),

          // Corner Guides (Animated Pulse)
          if (_isCameraInitialized)
            Center(
              child: ScaleTransition(
                scale: _focusAnimation,
                child: Container(
                  width: squareSize,
                  height: squareSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
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
                      // Center Reticle
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
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
            ),

          // Gallery Thumbnail (Bottom Left)
          if (_lastCapturedImagePath != null)
            Positioned(
              left: 30,
              bottom: 40,
              child: ScaleButton(
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Helper Info
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.burstSize > 1
                      ? "${LocalizationService.get('burst_mode')}: ${widget.burstSize} ${LocalizationService.get('burst_shots')}"
                      : LocalizationService.get('single_shot'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${LocalizationService.get('processing_images')} $_currentBurstCount/${widget.burstSize}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocalizationService.get('saving'),
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Blink Overlay
          if (_showBlink) Container(color: Colors.white.withValues(alpha: 0.5)),
        ],
      ),
      floatingActionButton: ScaleButton(
        onTap: () {
          if (_captureMode == CaptureMode.manual) {
            _takePicture();
          } else {
            _toggleCaptureState();
          }
        },
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: _isCapturingActive
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isCapturingActive ? Colors.redAccent : Colors.white,
              width: 4,
            ),
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _isCapturingActive ? Colors.red : Colors.white,
                shape: _isCapturingActive
                    ? BoxShape.rectangle
                    : BoxShape.circle,
                borderRadius: _isCapturingActive
                    ? BorderRadius.circular(16)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isCapturingActive ? Icons.stop : Icons.camera,
                  color: _isCapturingActive
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.8),
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _toggleCaptureState() {
    if (_isCapturingActive) {
      _stopCaptureStrategies();
    } else {
      setState(() {
        _isCapturingActive = true;
      });
      if (_captureMode == CaptureMode.interval) {
        _startIntervalCapture();
      } else if (_captureMode == CaptureMode.motion) {
        _startMotionCapture();
      }
    }
  }

  void _startIntervalCapture() {
    _intervalTimer = Timer.periodic(
      Duration(milliseconds: _intervalDurationMs),
      (timer) {
        if (mounted && _isCapturingActive && !_isProcessing) {
          _takePicture();
        }
      },
    );
  }

  void _startMotionCapture() {
    // Placeholder for Motion Capture
    // Real implementation would require startImageStream and pixel analysis
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Motion Capture logic to be implemented")),
    );
    // Auto-stop for now since it's not implemented
    setState(() {
      _isCapturingActive = false;
    });
  }

  void _stopCaptureStrategies() {
    _intervalTimer?.cancel();
    _intervalTimer = null;
    setState(() {
      _isCapturingActive = false;
    });
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Camera Settings",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Focus & Exposure Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Focus",
                              style: GoogleFonts.inter(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: Text(
                                _focusMode == FocusMode.auto
                                    ? "Auto"
                                    : "Locked",
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                              value: _focusMode == FocusMode.auto,
                              activeTrackColor: Colors.tealAccent,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setModalState(() {
                                  _focusMode = val
                                      ? FocusMode.auto
                                      : FocusMode.locked;
                                });
                                _updateFocusMode(_focusMode);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Exposure",
                              style: GoogleFonts.inter(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: Text(
                                _exposureMode == ExposureMode.auto
                                    ? "Auto"
                                    : "Locked",
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                              value: _exposureMode == ExposureMode.auto,
                              activeTrackColor: Colors.tealAccent,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setModalState(() {
                                  _exposureMode = val
                                      ? ExposureMode.auto
                                      : ExposureMode.locked;
                                });
                                _updateExposureMode(_exposureMode);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 32),

                  // Capture Mode
                  Text(
                    "Capture Mode",
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CaptureMode.values.map((mode) {
                        final isSelected = _captureMode == mode;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              mode.name.toUpperCase(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.teal,
                            backgroundColor: Colors.grey[800],
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  _captureMode = mode;
                                });
                                _updateCaptureMode(mode);
                                setState(() {});
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Conditional Params
                  if (_captureMode == CaptureMode.interval) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Interval: ${_intervalDurationMs}ms",
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    Slider(
                      value: _intervalDurationMs.toDouble(),
                      min: 500,
                      max: 5000,
                      divisions: 9,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        setModalState(() => _intervalDurationMs = val.toInt());
                        setState(() {});
                      },
                    ),
                  ],

                  if (_captureMode == CaptureMode.motion) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Sensitivity: ${_motionSensitivity.toInt()}%",
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    Slider(
                      value: _motionSensitivity,
                      min: 10,
                      max: 100,
                      divisions: 9,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        setModalState(() => _motionSensitivity = val);
                        setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateFocusMode(FocusMode mode) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFocusMode(mode);
    }
  }

  Future<void> _updateExposureMode(ExposureMode mode) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setExposureMode(mode);
    }
  }

  void _updateCaptureMode(CaptureMode mode) {
    _stopCaptureStrategies();
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: const Border(
            top: BorderSide(color: Colors.white, width: 4),
            left: BorderSide(color: Colors.white, width: 4),
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
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
      ..color = Colors.black
          .withValues(alpha: 0.7) // Darker for better focus
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
