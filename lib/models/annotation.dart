class Annotation {
  int classId;
  double xCenter;
  double yCenter;
  double width;
  double height;
  String? className; // Optional, for display purposes

  Annotation({
    required this.classId,
    required this.xCenter,
    required this.yCenter,
    required this.width,
    required this.height,
    this.className,
  });

  // Convert from YOLO format line
  factory Annotation.fromYoloLine(String line, {Map<int, String>? classMap}) {
    final parts = line.trim().split(' ');
    if (parts.length < 5) {
      throw FormatException("Invalid YOLO format line: $line");
    }

    final classId = int.parse(parts[0]);
    return Annotation(
      classId: classId,
      xCenter: double.parse(parts[1]),
      yCenter: double.parse(parts[2]),
      width: double.parse(parts[3]),
      height: double.parse(parts[4]),
      className: classMap?[classId],
    );
  }

  // Convert to YOLO format line
  String toYoloLine() {
    return '$classId ${xCenter.toStringAsFixed(6)} ${yCenter.toStringAsFixed(6)} ${width.toStringAsFixed(6)} ${height.toStringAsFixed(6)}';
  }

  @override
  String toString() {
    return 'Annotation(class: $classId, x: $xCenter, y: $yCenter, w: $width, h: $height)';
  }
}
