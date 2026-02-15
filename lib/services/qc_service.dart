import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

class QualityControlService {
  // Thresholds
  static const double _blurThreshold =
      100.0; // Variance of Laplacian < 100 is likely blurry (heuristic)
  static const double _darkThreshold = 40.0; // Avg luminance < 40 is dark
  static const double _tinyBoxThreshold =
      0.03; // Box dimension < 3% of image is tiny

  // --- Image Quality Checks ---

  /// Checks if an image is likely blurry using Variance of Laplacian.
  /// Returns a score (lower is blurrier) and a boolean verdict.
  Future<QCResult> checkBlur(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return QCResult(isIssue: true, score: 0, message: "Could not decode");
      }
      return checkBlurImage(image);
    } catch (e) {
      return QCResult(isIssue: false, score: -1, message: "Error: $e");
    }
  }

  QCResult checkBlurImage(img.Image image) {
    // Resize for speed (don't need full 4K resolution to detect blur)
    final resized = img.copyResize(image, width: 512);
    final grayscale = img.grayscale(resized);

    // Laplacian Kernel
    // [ 0, -1,  0]
    // [-1,  4, -1]
    // [ 0, -1,  0]
    final laplacian = img.convolution(
      grayscale,
      filter: [0, -1, 0, -1, 4, -1, 0, -1, 0],
      div: 1,
      offset: 0,
    );

    // Calculate Variance
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (var p in laplacian) {
      final val = p.r; // Use red channel (grayscale)
      sum += val;
      sumSq += val * val;
      count++;
    }

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    return QCResult(
      isIssue: variance < _blurThreshold,
      score: variance,
      message: variance < _blurThreshold
          ? "Blurry (Var: ${variance.toStringAsFixed(1)})"
          : "Sharp",
    );
  }

  /// Checks if an image is underexposed (too dark).
  Future<QCResult> checkExposure(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return QCResult(isIssue: true, score: 0, message: "Could not decode");
      }
      return checkExposureImage(image);
    } catch (e) {
      return QCResult(isIssue: false, score: -1, message: "Error");
    }
  }

  QCResult checkExposureImage(img.Image image) {
    // Resize for speed
    final resized = img.copyResize(image, width: 128);

    double totalLuminance = 0;
    int count = 0;

    for (var p in resized) {
      // Luminance = 0.2126*R + 0.7152*G + 0.0722*B
      totalLuminance += (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b);
      count++;
    }

    final avgLuminance = totalLuminance / count;

    return QCResult(
      isIssue: avgLuminance < _darkThreshold,
      score: avgLuminance,
      message: avgLuminance < _darkThreshold
          ? "Underexposed (Lum: ${avgLuminance.toStringAsFixed(1)})"
          : "Normal Check",
    );
  }

  /// Finds duplicate images in a list of files using MD5 hashing.
  /// Returns a map of Hash -> `List<String>` (filenames).
  Future<Map<String, List<File>>> findDuplicates(List<File> images) async {
    Map<String, List<File>> hashes = {};

    for (var file in images) {
      try {
        final bytes = await file.readAsBytes();
        final digest = md5.convert(bytes);
        final hash = digest.toString();

        if (!hashes.containsKey(hash)) {
          hashes[hash] = [];
        }
        hashes[hash]!.add(file);
      } catch (e) {
        debugPrint("Error hashing ${file.path}: $e");
      }
    }

    // Filter to show only duplicates (count > 1)
    hashes.removeWhere((key, value) => value.length < 2);
    return hashes;
  }

  // --- Annotation Quality Checks ---

  /// Analyzes annotations for class imbalance and tiny bounding boxes.
  Future<AnnotationAnalysisResult> analyzeAnnotations(
    Directory datasetDir,
    List<File> images,
  ) async {
    Map<int, int> classCounts = {};
    List<String> tinyBoxFiles = [];
    int totalBoxes = 0;

    for (var imgFile in images) {
      final txtPath = path.setExtension(imgFile.path, '.txt');
      final txtFile = File(txtPath);

      if (!await txtFile.exists()) continue;

      try {
        final lines = await txtFile.readAsLines();
        for (var line in lines) {
          if (line.trim().isEmpty) continue;

          final parts = line.trim().split(' ');
          if (parts.length >= 5) {
            // Count Class
            final classId = int.tryParse(parts[0]) ?? -1;
            classCounts[classId] = (classCounts[classId] ?? 0) + 1;
            totalBoxes++;

            // Check Size
            final w = double.tryParse(parts[3]) ?? 0.0;
            final h = double.tryParse(parts[4]) ?? 0.0;

            if (w < _tinyBoxThreshold || h < _tinyBoxThreshold) {
              tinyBoxFiles.add(path.basename(imgFile.path));
              // Break to avoid adding same file multiple times if it has multiple tiny boxes?
              // Let's allow duplicates if we want count, but for file list, unique is better.
              // We will just add and unique later if needed. Use set?
            }
          }
        }
      } catch (e) {
        debugPrint("Error reading annotation ${txtFile.path}: $e");
      }
    }

    return AnnotationAnalysisResult(
      classCounts: classCounts,
      tinyObjectFiles: tinyBoxFiles.toSet().toList(),
      totalBoxes: totalBoxes,
    );
  }
}

class QCResult {
  final bool isIssue;
  final double score;
  final String message;

  QCResult({required this.isIssue, required this.score, required this.message});
}

class AnnotationAnalysisResult {
  final Map<int, int> classCounts;
  final List<String> tinyObjectFiles;
  final int totalBoxes;

  AnnotationAnalysisResult({
    required this.classCounts,
    required this.tinyObjectFiles,
    required this.totalBoxes,
  });
}
