import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../models/annotation.dart';
import 'qc_service.dart';

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
    required bool brightness,
    required bool blur,
    required bool noise,
    required bool mosaic,
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
    bool filterQuality = false, // Add filter option
    required Function(int, int) onProgress, // current, total
  }) async {
    final qcService = QualityControlService();
    final Set<String> seenHashes = {};
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

      // Try to load classes.txt
      List<String> allClasses = [];
      final classesFile = File(path.join(sourceDir.path, 'classes.txt'));
      if (await classesFile.exists()) {
        final content = await classesFile.readAsString();
        allClasses = content
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        // Fallback or just current class
        allClasses = [className];
      }

      for (int i = 0; i < images.length; i++) {
        final file = images[i];

        // Determine destination folder (Train/Valid/Test)
        String subFolder = '';
        if (split) {
          if (i < trainCount) {
            subFolder = 'train';
          } else if (i < trainCount + validCount) {
            subFolder = 'val'; // Standardize 'val' instead of 'valid'
          } else {
            subFolder = 'test';
          }
        } else {
          subFolder = 'train'; // Default to train if not splitting
        }

        Directory destFolder;
        Directory imagesFolder;
        Directory labelsFolder;

        if (exportFormat == 'yolo') {
          // YOLO Structure: images/split and labels/split
          // e.g. output/images/train
          imagesFolder = Directory(
            path.join(outputDir.path, 'images', subFolder),
          );
          labelsFolder = Directory(
            path.join(outputDir.path, 'labels', subFolder),
          );

          if (!await imagesFolder.exists()) {
            await imagesFolder.create(recursive: true);
          }
          if (!await labelsFolder.exists()) {
            await labelsFolder.create(recursive: true);
          }

          destFolder = imagesFolder; // Images go here
        } else {
          // Tree Structure: split/class_name
          // Maintain legacy 'valid' naming for Tree if desired, assuming 'val' is fine too.
          Directory splitDir = subFolder.isEmpty
              ? outputDir
              : Directory(
                  path.join(
                    outputDir.path,
                    subFolder == 'val' ? 'valid' : subFolder,
                  ),
                );

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

        // QC Checks
        if (filterQuality) {
          // 1. Duplicate Check
          final hash = md5.convert(bytes).toString();
          if (seenHashes.contains(hash)) {
            // Skip duplicate
            onProgress(
              processedCount,
              images.length,
            ); // Still update progress? Or treat as skipped?
            // If we skip, processedCount might not increment if we use it for total.
            // But total is images.length. So we should increment processedCount or just ignore?
            // Let's ignore it for progress but continue loop.
            continue;
          }
          seenHashes.add(hash);
        }

        img.Image? originalImage = img.decodeImage(bytes);

        if (originalImage == null) continue;

        if (filterQuality) {
          // 2. Blur Check
          final blurRes = qcService.checkBlurImage(originalImage);
          if (blurRes.isIssue) continue;

          // 3. Exposure Check
          final darkRes = qcService.checkExposureImage(originalImage);
          if (darkRes.isIssue) continue;
        }

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
          await _applyAugmentations(
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
            brightness: brightness,
            blur: blur,
            noise: noise,
            mosaic: mosaic,
            allImages: images,
            targetWidth: resize ? targetWidth : processedImage.width,
            targetHeight: resize ? targetHeight : processedImage.height,
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

      // Generate dataset.yaml for YOLO
      if (exportFormat == 'yolo') {
        await _generateDatasetYaml(
          outputDir: outputDir,
          allClasses: allClasses,
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
    required bool brightness,
    required bool blur,
    required bool noise,
    required bool mosaic,
    required List<File> allImages,
    required int targetWidth,
    required int targetHeight,
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

    // Advanced Augmentations (Brightness, Blur, Noise)
    if (brightness) {
      // Create a brighter version
      final bright = img.adjustColor(image, brightness: 1.2); // +20%
      await _saveAugmented(
        bright,
        destFolder,
        '${baseName}_bright',
        generateYolo,
        classId,
        annotations,
        exportFormat,
        labelsFolder,
      );

      // Create a darker version
      final dark = img.adjustColor(image, brightness: 0.8); // -20%
      await _saveAugmented(
        dark,
        destFolder,
        '${baseName}_dark',
        generateYolo,
        classId,
        annotations,
        exportFormat,
        labelsFolder,
      );
    }

    if (blur) {
      final blurred = img.gaussianBlur(image, radius: 2);
      await _saveAugmented(
        blurred,
        destFolder,
        '${baseName}_blur',
        generateYolo,
        classId,
        annotations,
        exportFormat,
        labelsFolder,
      );
    }

    if (noise) {
      final noisy = _addNoise(image);
      await _saveAugmented(
        noisy,
        destFolder,
        '${baseName}_noise',
        generateYolo,
        classId,
        annotations,
        exportFormat,
        labelsFolder,
      );
    }

    if (mosaic && allImages.length >= 4) {
      await _createMosaic(
        currentImage: image,
        currentBaseName: baseName,
        currentAnnotations: annotations,
        allImages: allImages,
        destFolder: destFolder,
        labelsFolder: labelsFolder,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        generateYolo: generateYolo,
        classId: classId,
        exportFormat: exportFormat,
      );
    }
  }

  // Helper to save augmented image and labels
  Future<void> _saveAugmented(
    img.Image image,
    Directory destFolder,
    String nameWithoutExt,
    bool generateYolo,
    int classId,
    List<Annotation>? annotations,
    String exportFormat,
    Directory labelsFolder,
  ) async {
    await File(
      path.join(destFolder.path, '$nameWithoutExt.jpg'),
    ).writeAsBytes(img.encodeJpg(image));

    if (annotations != null && annotations.isNotEmpty) {
      // Coordinates don't change for color/blur/noise ops
      await File(
        path.join(labelsFolder.path, '$nameWithoutExt.txt'),
      ).writeAsString(annotations.map((a) => a.toYoloLine()).join('\n'));
    } else if (generateYolo) {
      await File(
        path.join(labelsFolder.path, '$nameWithoutExt.txt'),
      ).writeAsString("$classId 0.5 0.5 1.0 1.0");
    }
  }

  Future<void> _createMosaic({
    required img.Image currentImage,
    required String currentBaseName,
    required List<Annotation>? currentAnnotations,
    required List<File> allImages,
    required Directory destFolder,
    required Directory labelsFolder,
    required int targetWidth,
    required int targetHeight,
    required bool generateYolo,
    required int classId,
    required String exportFormat,
  }) async {
    // 1. Prepare 4 images
    List<img.Image> mosaicImages = [];
    List<List<Annotation>> mosaicAnnotations = [];

    // Slot 0: Current Image
    mosaicImages.add(currentImage);
    mosaicAnnotations.add(currentAnnotations ?? []);

    // Pick 3 random other images
    final rng = Random();
    for (int i = 0; i < 3; i++) {
      final randomFile = allImages[rng.nextInt(allImages.length)];
      final bytes = await randomFile.readAsBytes();
      img.Image? rndImg = img.decodeImage(bytes);
      if (rndImg == null) {
        // Fallback to current image if load fails
        mosaicImages.add(currentImage);
        mosaicAnnotations.add(currentAnnotations ?? []);
        continue;
      }
      mosaicImages.add(rndImg);

      // Load its annotations
      List<Annotation> anns = [];
      final sourceTxtPath = path.setExtension(randomFile.path, '.txt');
      final sourceTxt = File(sourceTxtPath);
      if (await sourceTxt.exists()) {
        final lines = await sourceTxt.readAsLines();
        anns = lines
            .where((l) => l.trim().isNotEmpty)
            .map((l) => Annotation.fromYoloLine(l))
            .toList();
      } else if (generateYolo) {
        anns.add(
          Annotation(
            classId: classId,
            xCenter: 0.5,
            yCenter: 0.5,
            width: 1.0,
            height: 1.0,
          ),
        );
      }
      mosaicAnnotations.add(anns);
    }

    // 2. Create Canvas
    final mosaicCanvas = img.Image(width: targetWidth, height: targetHeight);

    // 3. Place Images & Adjust Labels
    // We strictly use a 2x2 grid for simplicity
    // Top-Left (0,0), Top-Right (w/2, 0), Bottom-Left (0, h/2), Bottom-Right (w/2, h/2)
    final halfW = targetWidth ~/ 2;
    final halfH = targetHeight ~/ 2;

    List<Annotation> finalAnnotations = [];

    final positions = [
      Point(0, 0),
      Point(halfW, 0),
      Point(0, halfH),
      Point(halfW, halfH),
    ];

    for (int i = 0; i < 4; i++) {
      // Resize to fit quadrant
      final resized = img.copyResize(
        mosaicImages[i],
        width: halfW,
        height: halfH,
      );

      // Draw onto canvas
      img.compositeImage(
        mosaicCanvas,
        resized,
        dstX: positions[i].x.toInt(),
        dstY: positions[i].y.toInt(),
      );

      // Adjust Labels
      // New coordinates are scaled by 0.5 and shifted
      // Quadrant offsets as ratio (0.0 or 0.5)
      double offX = (positions[i].x / targetWidth);
      double offY = (positions[i].y / targetHeight);

      for (var ann in mosaicAnnotations[i]) {
        // Scale box by 0.5 (since image is half size)
        double newW = ann.width * 0.5;
        double newH = ann.height * 0.5;
        // Scale center and shift
        double newX = (ann.xCenter * 0.5) + offX;
        double newY = (ann.yCenter * 0.5) + offY;

        finalAnnotations.add(
          Annotation(
            classId: ann.classId,
            xCenter: newX,
            yCenter: newY,
            width: newW,
            height: newH,
          ),
        );
      }
    }

    // 4. Save Mosaic
    final name = '${currentBaseName}_mosaic.jpg';
    await File(
      path.join(destFolder.path, name),
    ).writeAsBytes(img.encodeJpg(mosaicCanvas));

    // 5. Save Labels
    if (finalAnnotations.isNotEmpty) {
      await File(
        path.join(labelsFolder.path, '${currentBaseName}_mosaic.txt'),
      ).writeAsString(finalAnnotations.map((a) => a.toYoloLine()).join('\n'));
    }
  }

  img.Image _addNoise(img.Image image) {
    final noisy = img.Image.from(image);
    final rng = Random();
    for (int y = 0; y < noisy.height; y++) {
      for (int x = 0; x < noisy.width; x++) {
        if (rng.nextDouble() < 0.05) {
          // 5% chance
          // Salt and Pepper
          final type = rng.nextBool();
          noisy.setPixelRgb(
            x,
            y,
            type ? 255 : 0,
            type ? 255 : 0,
            type ? 255 : 0,
          );
        }
      }
    }
    return noisy;
  }

  Future<void> _generateDatasetYaml({
    required Directory outputDir,
    required List<String> allClasses,
  }) async {
    final yamlPath = path.join(outputDir.path, 'dataset.yaml');
    final file = File(yamlPath);

    // Filter duplicates if any
    final uniqueClasses = allClasses.toSet().toList();

    // Create class names string
    final namesStr = uniqueClasses.map((c) => '"$c"').join(', ');

    String content =
        '''
train: images/train
val: images/val
test: images/test

nc: ${uniqueClasses.length}
names: [$namesStr]
''';

    await file.writeAsString(content);
  }
}
