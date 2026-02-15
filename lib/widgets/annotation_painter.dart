import 'package:flutter/material.dart';
import '../models/annotation.dart';

class AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final int? selectedIndex;
  final List<String> classes;
  final Map<int, Color> classColors;
  final Offset? dragStart;
  final Offset? dragEnd;
  final bool isDrawing;

  AnnotationPainter({
    required this.annotations,
    required this.selectedIndex,
    required this.classes,
    required this.classColors,
    this.dragStart,
    this.dragEnd,
    this.isDrawing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (annotations.isEmpty && !isDrawing) return;

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    final Paint selectedBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2.0;

    final Paint handlePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final Paint handleBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 1.0;

    for (int i = 0; i < annotations.length; i++) {
      final ann = annotations[i];
      final isSelected = i == selectedIndex;
      // Default to distinct color if map missing
      final color = classColors[ann.classId] ?? Colors.blueAccent;

      // Denormalize
      final w = ann.width * size.width;
      final h = ann.height * size.height;
      final cx = ann.xCenter * size.width;
      final cy = ann.yCenter * size.height;
      final left = cx - w / 2;
      final top = cy - h / 2;

      final rect = Rect.fromLTWH(left, top, w, h);

      // Fill
      fillPaint.color = color.withValues(alpha: isSelected ? 0.3 : 0.1);
      canvas.drawRect(rect, fillPaint);

      // Border
      borderPaint.color = isSelected ? Colors.yellowAccent : color;
      canvas.drawRect(rect, borderPaint);

      if (isSelected) {
        // High contrast border
        canvas.drawRect(rect, selectedBorderPaint);
        _drawHandles(canvas, rect, handlePaint, handleBorderPaint);
      }

      // Label
      final label =
          ann.className ??
          (classes.length > ann.classId
              ? classes[ann.classId]
              : 'Class ${ann.classId}');
      _drawLabel(canvas, rect, label, color, isSelected);
    }

    // Drawing Logic
    if (isDrawing && dragStart != null && dragEnd != null) {
      final rect = Rect.fromPoints(dragStart!, dragEnd!);
      final Paint drawingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.greenAccent
        ..strokeWidth = 2.0;
      final Paint drawingFill = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.greenAccent.withValues(alpha: 0.2);

      canvas.drawRect(rect, drawingFill); // fill
      canvas.drawRect(rect, drawingPaint); // border
    }
  }

  void _drawHandles(Canvas canvas, Rect rect, Paint fill, Paint border) {
    const double radius = 6.0;
    final points = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    for (var p in points) {
      canvas.drawCircle(p, radius, fill);
      canvas.drawCircle(p, radius, border);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Rect rect,
    String label,
    Color color,
    bool isSelected,
  ) {
    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final offset = Offset(rect.left, rect.top - textPainter.height - 4);
    final bgRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    canvas.drawRect(bgRect, Paint()..color = color);
    textPainter.paint(canvas, offset + const Offset(4, 2));
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return oldDelegate.annotations != annotations ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.dragStart != dragStart ||
        oldDelegate.dragEnd != dragEnd ||
        oldDelegate.isDrawing != isDrawing;
  }
}
