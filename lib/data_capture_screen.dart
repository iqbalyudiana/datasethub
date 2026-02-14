import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class DataCaptureScreen extends StatefulWidget {
  final String folderName;
  final int frameSize;
  final int outputResolution;

  const DataCaptureScreen({
    super.key,
    required this.folderName,
    required this.frameSize,
    required this.outputResolution,
  });

  @override
  State<DataCaptureScreen> createState() => _DataCaptureScreenState();
}

class _DataCaptureScreenState extends State<DataCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

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
          _controller = CameraController(
            firstCamera,
            ResolutionPreset.veryHigh, // Uses highest res available
            enableAudio: false,
          );

          _initializeControllerFuture = _controller!.initialize();
          await _initializeControllerFuture;
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

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _controller == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _initializeControllerFuture;

      final xFile = await _controller!.takePicture();
      final File imageFile = File(xFile.path);

      // Process image in background would be better, but doing here for simplicity
      final rawImage = img.decodeImage(await imageFile.readAsBytes());

      if (rawImage != null) {
        // 1. Crop to square (center)
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

        // 2. Resize to output resolution
        final resizedImage = img.copyResize(
          croppedImage,
          width: widget.outputResolution,
          height: widget.outputResolution,
        );

        // Auto Naming: dataset_YYYYMMDD_HHMMSS.jpg
        final now = DateTime.now();
        final timestamp =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
        final fileName = "${widget.folderName}_$timestamp.jpg";

        // Auto Save: ApplicationDocumentsDirectory/dataset/{folderName}
        final directory = await getApplicationDocumentsDirectory();
        final datasetDir = Directory(
          '${directory.path}/dataset/${widget.folderName}',
        );
        if (!await datasetDir.exists()) {
          await datasetDir.create(recursive: true);
        }

        final savePath = '${datasetDir.path}/$fileName';
        await File(savePath).writeAsBytes(img.encodeJpg(resizedImage));

        // Delete original temp file
        await imageFile.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved: $fileName to ${widget.folderName}')),
          );
        }
      }
    } catch (e) {
      _showError('Error capturing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Capture: ${widget.folderName} (${widget.outputResolution}px)',
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _isCameraInitialized
              ? CameraPreview(_controller!)
              : const Center(child: CircularProgressIndicator()),

          // Square Overlay Guide
          if (_isCameraInitialized)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    "${widget.frameSize}x${widget.frameSize} Frame",
                    style: const TextStyle(
                      color: Colors.white,
                      backgroundColor: Colors.black45,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
