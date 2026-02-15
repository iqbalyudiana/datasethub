import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class ProcessingService {
  Future<void> processDataset({
    required Directory sourceDir,
    required Directory outputDir,
    required bool resize,
    required int targetWidth,
    required int targetHeight,
    required bool augment,
    required bool flipHorizontal,
    required bool flipVertical,
    required bool rotate,
    required bool grayscale,
    required bool split,
    required double trainSplit,
    required double validSplit,
    required double testSplit,
    required Function(int, int) onProgress, // current, total
  }) async {
    try {
      if (!await sourceDir.exists()) {
        throw Exception('Source directory does not exist');
      }

      // Create output directory
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Get all images
      final List<FileSystemEntity> entities = sourceDir.listSync();
      final List<File> images = entities.whereType<File>().where((file) {
        final lowerPath = file.path.toLowerCase();
        return lowerPath.endsWith('.jpg') ||
            lowerPath.endsWith('.jpeg') ||
            lowerPath.endsWith('.png');
      }).toList();

      if (images.isEmpty) return;

      if (images.isEmpty) return;

      if (augment) {
        // Estimate total operations: original + (original * num_augmentations)
        // This is a bit complex to calculate perfectly upfront without knowing per-image logic,
        // so we'll just update progress as we go.
      }

      int processedCount = 0;

      // Shuffle images if splitting
      if (split) {
        images.shuffle(Random());
      }

      // Determine split indices
      int trainCount = (images.length * trainSplit).round();
      int validCount = (images.length * validSplit).round();
      // Test takes the rest

      for (int i = 0; i < images.length; i++) {
        final file = images[i];

        // Determine destination folder (Train/Valid/Test)
        String subFolder = 'all';
        if (split) {
          if (i < trainCount) {
            subFolder = 'train';
          } else if (i < trainCount + validCount) {
            subFolder = 'valid';
          } else {
            subFolder = 'test';
          }
        }

        final destFolder = Directory(path.join(outputDir.path, subFolder));
        if (!await destFolder.exists()) {
          await destFolder.create(recursive: true);
        }

        // Read image
        final bytes = await file.readAsBytes();
        img.Image? originalImage = img.decodeImage(bytes);

        if (originalImage == null) continue;

        // Resize
        img.Image processedImage = originalImage;
        if (resize) {
          processedImage = img.copyResize(
            originalImage,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.linear,
          );
        }

        // Save processed original
        final fileName = path.basename(file.path);
        final savePath = path.join(destFolder.path, fileName);
        await File(
          savePath,
        ).writeAsBytes(img.encodeJpg(processedImage, quality: 90));

        // Augmentations
        if (augment) {
          if (flipHorizontal) {
            final augmented = img.copyFlip(
              processedImage,
              direction: img.FlipDirection.horizontal,
            );
            final name = '${path.basenameWithoutExtension(fileName)}_flipH.jpg';
            await File(
              path.join(destFolder.path, name),
            ).writeAsBytes(img.encodeJpg(augmented));
          }
          if (flipVertical) {
            final augmented = img.copyFlip(
              processedImage,
              direction: img.FlipDirection.vertical,
            );
            final name = '${path.basenameWithoutExtension(fileName)}_flipV.jpg';
            await File(
              path.join(destFolder.path, name),
            ).writeAsBytes(img.encodeJpg(augmented));
          }
          if (rotate) {
            // Rotate 15 degrees
            final augmented1 = img.copyRotate(processedImage, angle: 15);
            final name1 =
                '${path.basenameWithoutExtension(fileName)}_rot15.jpg';
            await File(
              path.join(destFolder.path, name1),
            ).writeAsBytes(img.encodeJpg(augmented1));

            // Rotate -15 degrees
            final augmented2 = img.copyRotate(processedImage, angle: -15);
            final name2 =
                '${path.basenameWithoutExtension(fileName)}_rotN15.jpg';
            await File(
              path.join(destFolder.path, name2),
            ).writeAsBytes(img.encodeJpg(augmented2));
          }
          if (grayscale) {
            final augmented = img.grayscale(processedImage);
            final name = '${path.basenameWithoutExtension(fileName)}_gray.jpg';
            await File(
              path.join(destFolder.path, name),
            ).writeAsBytes(img.encodeJpg(augmented));
          }
        }

        processedCount++;
        onProgress(processedCount, images.length);
      }
    } catch (e) {
      debugPrint('Error processing dataset: $e');
      rethrow;
    }
  }
}
