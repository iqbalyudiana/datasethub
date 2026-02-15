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
    String exportFormat = 'tree', // 'tree' or 'yolo'
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

        Directory destFolder;
        Directory imagesFolder;
        Directory labelsFolder;

        if (exportFormat == 'yolo') {
          // YOLO Structure: split/images and split/labels
          final splitDir = subFolder.isEmpty
              ? outputDir
              : Directory(path.join(outputDir.path, subFolder));
          imagesFolder = Directory(path.join(splitDir.path, 'images'));
          labelsFolder = Directory(path.join(splitDir.path, 'labels'));

          if (!await imagesFolder.exists()) {
            await imagesFolder.create(recursive: true);
          }
          if (!await labelsFolder.exists()) {
            await labelsFolder.create(recursive: true);
          }

          destFolder = imagesFolder; // Images go here
        } else {
          // Tree Structure: split/class_name
          Directory splitDir = subFolder.isEmpty
              ? outputDir
              : Directory(path.join(outputDir.path, subFolder));

          destFolder = Directory(path.join(splitDir.path, className));
          if (!await destFolder.exists()) {
            await destFolder.create(recursive: true);
          }
          imagesFolder = destFolder;
          labelsFolder =
              destFolder; // In tree format, labels (if valid) might sit with images or just be ignored
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
          final targetDest = exportFormat == 'yolo' ? labelsFolder : destFolder;
          final destTxtPath = path.join(
            targetDest.path,
            '${path.basenameWithoutExtension(finalFileName)}.txt',
          );
          await File(destTxtPath).writeAsString(lines.join('\n'));
        } else if (generateYolo) {
          // Generate dummy only if requested and no manual labels exist
          final targetDest = exportFormat == 'yolo' ? labelsFolder : destFolder;
          final yoloPath = path.join(
            targetDest.path,
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
            exportFormat: exportFormat,
            labelsFolder: exportFormat == 'yolo' ? labelsFolder : destFolder,
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

      // Generate data.yaml for YOLO
      if (exportFormat == 'yolo') {
        await _generateDataYaml(
          outputDir: outputDir,
          className: className,
          classId: classId,
        );
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
    required String exportFormat,
    required Directory labelsFolder,
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
          path.join(labelsFolder.path, '${baseName}_flipH.txt'),
        ).writeAsString(newAnns.map((a) => a.toYoloLine()).join('\n'));
      } else if (generateYolo) {
        await File(
          path.join(labelsFolder.path, '${baseName}_flipH.txt'),
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
          path.join(labelsFolder.path, '${baseName}_flipV.txt'),
        ).writeAsString(newAnns.map((a) => a.toYoloLine()).join('\n'));
      } else if (generateYolo) {
        await File(
          path.join(labelsFolder.path, '${baseName}_flipV.txt'),
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
          path.join(labelsFolder.path, '${baseName}_rot15.txt'),
        ).writeAsString("$classId 0.5 0.5 1.0 1.0");
      }

      final augmented2 = img.copyRotate(image, angle: -15);
      final name2 = '${baseName}_rotN15.jpg';
      await File(
        path.join(destFolder.path, name2),
      ).writeAsBytes(img.encodeJpg(augmented2));
      if (generateYolo) {
        await File(
          path.join(labelsFolder.path, '${baseName}_rotN15.txt'),
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
          path.join(labelsFolder.path, '${baseName}_gray.txt'),
        ).writeAsString("$classId 0.5 0.5 1.0 1.0");
      }
    }
  }

  Future<void> _generateDataYaml({
    required Directory outputDir,
    required String className,
    required int classId,
  }) async {
    // In a real multi-class scenario, we'd overlap or merge yamls.
    // Here we assume single class export per run or simple append.
    // But usually, we process the whole dataset which might have multiple classes.
    // The current ProcessingService processes ONE sourceDir (one class usually) at a time.
    // This is a limitation for generating a GLOBAL data.yaml.
    // However, we can check if data.yaml exists and append the class name if not present.

    final yamlPath = path.join(outputDir.path, 'data.yaml');
    final file = File(yamlPath);

    // We will blindly overwrite or write a simple single-class yaml for now as per requirements
    // To support multi-class properly, we'd need to know ALL classes upfront or
    // read existing yaml.

    // Let's read existing if available to append class?
    // Parsing YAML manually is hard.
    // Let's generic a generic template that works for specific single class runs
    // OR if we assume the user processes multiple classes into the SAME outputDir,
    // we might want to consolidate.

    // For now, simpler approach: Write a specific YAML for THIS class run.
    // WARNING: If user runs multiple classes, this might overwrite.
    // Ideally, specific class names should be collected.

    // Let's assume standard 'classes.txt' exists in outputDir?
    // Or just write a generic one.

    String content =
        '''
train: ./train/images
val: ./valid/images
test: ./test/images

nc: ${classId + 1}
names: ['$className']
''';
    // If we want to support appending, we'd need a more robust system.
    // Given the current architecture (processDataset runs on one folder),
    // we might just write it.

    await file.writeAsString(content);
  }
}
