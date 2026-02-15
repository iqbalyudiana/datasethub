import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../models/annotation.dart';

class AnnotationService {
  // Load annotations from a .txt file corresponding to an image
  Future<List<Annotation>> loadAnnotations(File imageFile) async {
    final txtPath = path.setExtension(imageFile.path, '.txt');
    final txtFile = File(txtPath);

    if (!await txtFile.exists()) {
      return [];
    }

    try {
      final lines = await txtFile.readAsLines();
      return lines
          .where((line) => line.trim().isNotEmpty)
          .map((line) => Annotation.fromYoloLine(line))
          .toList();
    } catch (e) {
      debugPrint("Error loading annotations for ${imageFile.path}: $e");
      return [];
    }
  }

  // Save annotations to a .txt file
  Future<void> saveAnnotations(
    File imageFile,
    List<Annotation> annotations,
  ) async {
    final txtPath = path.setExtension(imageFile.path, '.txt');
    final txtFile = File(txtPath);

    if (annotations.isEmpty) {
      if (await txtFile.exists()) {
        await txtFile.delete(); // Remove file if no annotations
      }
      return;
    }

    try {
      final content = annotations.map((a) => a.toYoloLine()).join('\n');
      await txtFile.writeAsString(content);
    } catch (e) {
      debugPrint("Error saving annotations for ${imageFile.path}: $e");
      rethrow;
    }
  }

  // Manage classes.txt
  Future<List<String>> loadClasses(Directory datasetDir) async {
    // Look for classes.txt in the dataset directory or parent
    File classesFile = File(path.join(datasetDir.path, 'classes.txt'));

    // Check parent if not found (common for split datasets)
    if (!await classesFile.exists()) {
      final parentFile = File(path.join(datasetDir.parent.path, 'classes.txt'));
      if (await parentFile.exists()) {
        classesFile = parentFile;
      }
    }

    if (!await classesFile.exists()) {
      return ['object']; // Default class if none defined
    }

    try {
      final content = await classesFile.readAsString();
      return content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim())
          .toList();
    } catch (e) {
      debugPrint("Error loading classes: $e");
      return ['object'];
    }
  }

  Future<void> saveClasses(Directory datasetDir, List<String> classes) async {
    final classesFile = File(path.join(datasetDir.path, 'classes.txt'));
    try {
      await classesFile.writeAsString(classes.join('\n'));
    } catch (e) {
      debugPrint("Error saving classes: $e");
      rethrow;
    }
  }
}
