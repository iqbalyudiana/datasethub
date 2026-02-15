import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class StructuringService {
  Future<List<String>> generateMetadata(Directory datasetDir) async {
    try {
      if (!await datasetDir.exists()) {
        throw Exception('Dataset directory does not exist');
      }

      final Set<String> classes = {};
      final entities = datasetDir.listSync(recursive: true);

      for (var entity in entities) {
        if (entity is Directory) {
          final name = path.basename(entity.path);
          // Skip system folders or the dataset root itself acting weirdly
          if (name.startsWith('.')) continue;

          // Heuristic: If it contains image files, it's likely a class folder
          // But simpler: Just list direct children of 'train', 'test', 'valid' OR root if flat.
        }
      }

      // Let's try a simpler approach:
      // 1. Is it split? (Check for 'train' folder)
      // 2. If split, list dirs inside 'train'.
      // 3. If not split, list dirs inside root.

      final children = datasetDir.listSync();
      bool isSplit = children.any(
        (e) => path.basename(e.path) == 'train' && e is Directory,
      );

      if (isSplit) {
        final trainDir = Directory(path.join(datasetDir.path, 'train'));
        if (await trainDir.exists()) {
          trainDir.listSync().whereType<Directory>().forEach((d) {
            classes.add(path.basename(d.path));
          });
        }
      } else {
        // Flat structure
        children.whereType<Directory>().forEach((d) {
          final name = path.basename(d.path);
          if (name != 'train' && name != 'valid' && name != 'test') {
            classes.add(name);
          }
        });
      }

      final sortedClasses = classes.toList()..sort();

      // Write to classes.txt
      final metadataFile = File(path.join(datasetDir.path, 'classes.txt'));
      await metadataFile.writeAsString(sortedClasses.join('\n'));

      return sortedClasses;
    } catch (e) {
      debugPrint('Error generating metadata: $e');
      rethrow;
    }
  }

  Future<File> exportDataset(
    Directory datasetDir,
    Directory exportDir,
    Function(double) onProgress,
  ) async {
    try {
      if (!await datasetDir.exists()) {
        throw Exception('Dataset directory does not exist');
      }

      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final datasetName = path.basename(datasetDir.path);
      final zipFilePath = path.join(exportDir.path, '$datasetName.zip');

      // Use ZipFileEncoder
      var encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      // We want to verify progress, but ZipFileEncoder.addDirectory is atomic.
      // For better UX with progress, we should manually iterate or just use addDirectory and fake progress?
      // Let's use manual addition for progress if possible, but addDirectory is safer.
      // Given complexity, let's use addDirectory and just indeterminate progress or start/end.
      // But the prompt asked for progress.

      // Manual approach:
      // Get all files
      final files = datasetDir.listSync(recursive: true).whereType<File>();
      final totalFiles = files.length;
      int processed = 0;

      for (var file in files) {
        final relativePath = path.relative(
          file.path,
          from: datasetDir.parent.path,
        );
        await encoder.addFile(file, relativePath);
        processed++;
        if (processed % 10 == 0) {
          // Update every 10 files to not spam
          onProgress(processed / totalFiles);
          await Future.delayed(Duration.zero); // Yield
        }
      }

      encoder.close();

      return File(zipFilePath);
    } catch (e) {
      debugPrint('Error exporting dataset: $e');
      rethrow;
    }
  }
}
