import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../models/annotation.dart';

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
    // Automated Labeling Options
    bool generateLabels = false,
    bool normalizeNames = false,
    bool generateYolo = false,
    int classId = 0, // Default to 0 if not specified
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

      int processedCount = 0;

      // Shuffle images if splitting
      if (split) {
        images.shuffle(Random());
      }

      // Determine split indices
      int trainCount = (images.length * trainSplit).round();
      int validCount = (images.length * validSplit).round();
      // Test takes the rest

      // CSV Buffer
      StringBuffer csvBuffer = StringBuffer();
      if (generateLabels) {
        csvBuffer.writeln('filename,class');
      }

      // Get class name from parent folder name (assuming sourceDir is the class folder)
      String className = path.basename(sourceDir.path);

      for (int i = 0; i < images.length; i++) {
        final file = images[i];

        // Determine destination folder (Train/Valid/Test)
        String subFolder = '';
        if (split) {
          if (i < trainCount) {
            subFolder = 'train';
          } else if (i < trainCount + validCount) {
            subFolder = 'valid';
          } else {
            subFolder = 'test';
          }
        }

        Directory destFolder = subFolder.isEmpty
            ? outputDir
            : Directory(path.join(outputDir.path, subFolder));

        // Create Class Subfolder to preserve hierarchy
        destFolder = Directory(path.join(destFolder.path, className));

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

        // Generate Filename
        String finalFileName = path.basename(file.path);
        if (normalizeNames) {
          final extension = path.extension(file.path);
          finalFileName =
              '${className}_${i.toString().padLeft(4, '0')}$extension';
        }

        final savePath = path.join(destFolder.path, finalFileName);

        // Save Image
        await File(
          savePath,
        ).writeAsBytes(img.encodeJpg(processedImage, quality: 90));

        // Generate CSV Entry
        if (generateLabels) {
          csvBuffer.writeln('$finalFileName,$className');
        }

        // Generate/Copy YOLO Label
        final sourceTxtPath = path.setExtension(file.path, '.txt');
        final sourceTxt = File(sourceTxtPath);
        List<Annotation> annotations = [];

        if (await sourceTxt.exists()) {
          // Read existing manual annotations
          final lines = await sourceTxt.readAsLines();
          annotations = lines
              .where((l) => l.trim().isNotEmpty)
              .map((l) => Annotation.fromYoloLine(l))
              .toList();

          // Write to destination
          final destTxtPath = path.join(
            destFolder.path,
            '${path.basenameWithoutExtension(finalFileName)}.txt',
          );
          await File(destTxtPath).writeAsString(lines.join('\n'));
        } else if (generateYolo) {
          // Generate dummy only if requested and no manual labels exist
          final yoloPath = path.join(
            destFolder.path,
            '${path.basenameWithoutExtension(finalFileName)}.txt',
          );
          await File(yoloPath).writeAsString("$classId 0.5 0.5 1.0 1.0");
          // Create dummy annotation object for augmentation
          annotations.add(
            Annotation(
              classId: classId,
              xCenter: 0.5,
              yCenter: 0.5,
              width: 1.0,
              height: 1.0,
            ),
          );
        }

        // Augmentations (Only if NOT splitting test set, usually we don't augment test set)
        // But here we apply generally.
        // Note: Renaming logic for normalized augmentation needs to be handled.

        if (augment) {
          _applyAugmentations(
            image: processedImage,
            destFolder: destFolder,
            baseName: path.basenameWithoutExtension(finalFileName),
            flipH: flipHorizontal,
            flipV: flipVertical,
            rot: rotate,
            gray: grayscale,
            generateYolo: generateYolo,
            classId: classId,
            annotations: annotations,
          );
        }

        processedCount++;
        onProgress(processedCount, images.length);
      }

      // Write CSV
      if (generateLabels) {
        final csvPath = path.join(outputDir.path, '${className}_labels.csv');
        // If file exists, append? For now, we just write.
        // In a real scenario, we might want to merge.
        // But since this is per-folder processing, we might be writing per class.
        // Let's write as ${className}_labels.csv to be safe.
        await File(csvPath).writeAsString(csvBuffer.toString());
      }
    } catch (e) {
      debugPrint('Error processing dataset: $e');
      rethrow;
    }
  }

  Future<void> _applyAugmentations({
    required img.Image image,
    required Directory destFolder,
    required String baseName,
    required bool flipH,
    required bool flipV,
    required bool rot,
    required bool gray,
    required bool generateYolo,
    required int classId,
    List<Annotation>? annotations,
  }) async {
    if (flipH) {
      final augmented = img.copyFlip(
        image,
        direction: img.FlipDirection.horizontal,
      );
      final name = '${baseName}_flipH.jpg';
      await File(
        path.join(destFolder.path, name),
      ).writeAsBytes(img.encodeJpg(augmented));

      if (annotations != null && annotations.isNotEmpty) {
        final newAnns = annotations.map((a) {
          return Annotation(
            classId: a.classId,
            xCenter: 1.0 - a.xCenter, // Flip X
            yCenter: a.yCenter,
            width: a.width,
            height: a.height,
          );
        }).toList();
        await File(
          path.join(destFolder.path, '${baseName}_flipH.txt'),
        ).writeAsString(newAnns.map((a) => a.toYoloLine()).join('\n'));
      } else if (generateYolo) {
        await File(
          path.join(destFolder.path, '${baseName}_flipH.txt'),
        ).writeAsString("$classId 0.5 0.5 1.0 1.0");
      }
    }
    if (flipV) {
      final augmented = img.copyFlip(
        image,
        direction: img.FlipDirection.vertical,
      );
      final name = '${baseName}_flipV.jpg';
      await File(
        path.join(destFolder.path, name),
      ).writeAsBytes(img.encodeJpg(augmented));

      if (annotations != null && annotations.isNotEmpty) {
        final newAnns = annotations.map((a) {
          return Annotation(
            classId: a.classId,
            xCenter: a.xCenter,
            yCenter: 1.0 - a.yCenter, // Flip Y
            width: a.width,
            height: a.height,
          );
        }).toList();
        await File(
          path.join(destFolder.path, '${baseName}_flipV.txt'),
        ).writeAsString(newAnns.map((a) => a.toYoloLine()).join('\n'));
      } else if (generateYolo) {
        await File(
          path.join(destFolder.path, '${baseName}_flipV.txt'),
        ).writeAsString("$classId 0.5 0.5 1.0 1.0");
      }
    }
    if (rot) {
      final augmented1 = img.copyRotate(image, angle: 15);
      final name1 = '${baseName}_rot15.jpg';
      await File(
        path.join(destFolder.path, name1),
      ).writeAsBytes(img.encodeJpg(augmented1));
      if (generateYolo) {
        await File(
          path.join(destFolder.path, '${baseName}_rot15.txt'),
        ).writeAsString("$classId 0.5 0.5 1.0 1.0");
      }

      final augmented2 = img.copyRotate(image, angle: -15);
      final name2 = '${baseName}_rotN15.jpg';
      await File(
        path.join(destFolder.path, name2),
      ).writeAsBytes(img.encodeJpg(augmented2));
      if (generateYolo) {
        await File(
          path.join(destFolder.path, '${baseName}_rotN15.txt'),
        ).writeAsString("$classId 0.5 0.5 1.0 1.0");
      }
    }
    if (gray) {
      final augmented = img.grayscale(image);
      final name = '${baseName}_gray.jpg';
      await File(
        path.join(destFolder.path, name),
      ).writeAsBytes(img.encodeJpg(augmented));
      if (generateYolo) {
        await File(
          path.join(destFolder.path, '${baseName}_gray.txt'),
        ).writeAsString("$classId 0.5 0.5 1.0 1.0");
      }
    }
  }
}
