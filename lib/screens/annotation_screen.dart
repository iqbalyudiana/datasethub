import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/annotation.dart';
import '../services/annotation_service.dart';
import '../widgets/annotation_painter.dart';

class AnnotationScreen extends StatefulWidget {
  final File imageFile;

  const AnnotationScreen({super.key, required this.imageFile});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  final AnnotationService _annotationService = AnnotationService();

  List<Annotation> _annotations = [];
  List<String> _classes = ['object'];
  int _selectedClassId = 0;

  // Image Info
  double _imageAspectRatio = 1.0;
  bool _isImageLoaded = false;

  // Drawing State
  bool _isDrawingMode = true;
  Offset? _startPoint;
  Offset? _currentPoint;

  // Interaction State
  int? _selectedAnnotationIndex;
  int? _activeHandleIndex; // 0: TL, 1: TR, 2: BL, 3: BR
  Map<int, Color> _classColors = {};

  // Constants
  static const double _handleHitRadius = 20.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final parentDir = widget.imageFile.parent;

    // Load Classes
    final classes = await _annotationService.loadClasses(parentDir);

    // Load Annotations
    final annotations = await _annotationService.loadAnnotations(
      widget.imageFile,
    );

    // Get Image Dimensions for Aspect Ratio
    final bytes = await widget.imageFile.readAsBytes();
    final image = await decodeImageFromList(bytes);

    if (mounted) {
      setState(() {
        _classes = classes;
        _annotations = annotations;
        _imageAspectRatio = image.width.toDouble() / image.height.toDouble();
        _isImageLoaded = true;
        _generateClassColors();
      });
    }
  }

  void _generateClassColors() {
    _classColors = {};
    for (int i = 0; i < _classes.length; i++) {
      // Generate distinct pastel/bright colors
      final hue = (i * 137.508) % 360;
      _classColors[i] = HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();
    }
  }

  Future<void> _save() async {
    try {
      await _annotationService.saveAnnotations(widget.imageFile, _annotations);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Annotations saved successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    }
  }

  void _manageClasses() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Manage Classes"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final color = _classColors[index] ?? Colors.grey;
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: color, radius: 10),
                      title: Text(_classes[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Prevent deleting if used? Or just warn?
                          // For now, simplify: don't allow deleting if annotations exist for this class
                          bool inUse = _annotations.any(
                            (a) => a.classId == index,
                          );
                          if (inUse) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Class in use, cannot delete"),
                              ),
                            );
                          } else {
                            setDialogState(() {
                              _classes.removeAt(index);
                              _generateClassColors();
                              // Adjust selected class id
                              if (_selectedClassId >= _classes.length) {
                                _selectedClassId = max(0, _classes.length - 1);
                              }
                            });
                            _annotationService.saveClasses(
                              widget.imageFile.parent,
                              _classes,
                            );
                            setState(() {}); // Update parent
                          }
                        },
                      ),
                      onTap: () {
                        // Edit name
                        _editClassName(index);
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _addClass();
                  },
                  child: const Text("Add New Class"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editClassName(int index) {
    final controller = TextEditingController(text: _classes[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Class Name"),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _classes[index] = controller.text;
                });
                _annotationService.saveClasses(
                  widget.imageFile.parent,
                  _classes,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addClass() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("New Class"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "Class Name"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _classes.add(controller.text);
                    _selectedClassId = _classes.length - 1;
                    _generateClassColors();
                  });
                  _annotationService.saveClasses(
                    widget.imageFile.parent,
                    _classes,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _deleteAnnotation(int index) {
    setState(() {
      _annotations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          "Annotate",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isDrawingMode ? Icons.edit : Icons.pan_tool,
              color: _isDrawingMode ? Colors.greenAccent : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isDrawingMode = !_isDrawingMode;
              });
            },
            tooltip: _isDrawingMode ? 'Drawing Mode' : 'Pan/Zoom Mode',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.grey[850],
            child: Row(
              children: [
                Text("Class: ", style: GoogleFonts.inter(color: Colors.white)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedClassId < _classes.length
                          ? _selectedClassId
                          : 0,
                      dropdownColor: Colors.grey[800],
                      style: GoogleFonts.inter(color: Colors.white),
                      items: List.generate(_classes.length, (index) {
                        return DropdownMenuItem(
                          value: index,
                          child: Text(_classes[index]),
                        );
                      }),
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val ?? 0;
                        });
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  onPressed: _manageClasses,
                  tooltip: 'Manage Classes',
                ),
                VerticalDivider(
                  color: Colors.grey[600],
                  indent: 10,
                  endIndent: 10,
                ),
                Text(
                  "${_annotations.length} Boxes",
                  style: GoogleFonts.inter(color: Colors.grey[400]),
                ),
                if (_selectedAnnotationIndex != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () =>
                        _deleteAnnotation(_selectedAnnotationIndex!),
                    tooltip: 'Delete Selected',
                  ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: !_isImageLoaded
                  ? const CircularProgressIndicator()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate fitted image size to maintain aspect ratio
                        final maxWidth = constraints.maxWidth;
                        final maxHeight = constraints.maxHeight;
                        final containerAspectRatio = maxWidth / maxHeight;

                        double drawWidth, drawHeight;

                        if (containerAspectRatio > _imageAspectRatio) {
                          // Container is wider than image -> constrain by height
                          drawHeight = maxHeight;
                          drawWidth = maxHeight * _imageAspectRatio;
                        } else {
                          // Container is taller/narrower -> constrain by width
                          drawWidth = maxWidth;
                          drawHeight = maxWidth / _imageAspectRatio;
                        }

                        final size = Size(drawWidth, drawHeight);

                        return GestureDetector(
                          onTapDown: (details) => _handleTapDown(details, size),
                          onPanStart: (details) =>
                              _handlePanStart(details, size),
                          onPanUpdate: (details) =>
                              _handlePanUpdate(details, size),
                          onPanEnd: (details) => _handlePanEnd(details, size),
                          child: SizedBox(
                            width: drawWidth,
                            height: drawHeight,
                            child: CustomPaint(
                              foregroundPainter: AnnotationPainter(
                                annotations: _annotations,
                                selectedIndex: _selectedAnnotationIndex,
                                classes: _classes,
                                classColors: _classColors,
                                dragStart: _startPoint,
                                dragEnd: _currentPoint,
                                isDrawing:
                                    _isDrawingMode && _startPoint != null,
                              ),
                              child: Image.file(
                                widget.imageFile,
                                width: drawWidth,
                                height: drawHeight,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Interaction Handlers ---

  void _handleTapDown(TapDownDetails details, Size widgetSize) {
    if (_isDrawingMode) return;

    final pos = details.localPosition;

    // 1. Check handles of selected annotation first
    if (_selectedAnnotationIndex != null) {
      final ann = _annotations[_selectedAnnotationIndex!];
      final rect = _denormalize(ann, widgetSize);

      // Check corners (expand hit area)
      final corners = [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ];
      for (int i = 0; i < 4; i++) {
        if ((pos - corners[i]).distance <= _handleHitRadius) {
          // Tapped a handle
          setState(() {
            // Keep selection
          });
          return;
        }
      }
    }

    // 2. Check if tapped inside any annotation (reverse order for top-most)
    int? foundIndex;
    for (int i = _annotations.length - 1; i >= 0; i--) {
      final rect = _denormalize(_annotations[i], widgetSize);
      if (rect.contains(pos)) {
        foundIndex = i;
        break;
      }
    }

    setState(() {
      _selectedAnnotationIndex = foundIndex;
    });
  }

  void _handlePanStart(DragStartDetails details, Size widgetSize) {
    final pos = details.localPosition;
    _activeHandleIndex = null;

    if (_isDrawingMode) {
      setState(() {
        _startPoint = pos;
        _currentPoint = pos;
        _selectedAnnotationIndex = null; // Deselect when drawing
      });
      return;
    }

    // Check handles
    if (_selectedAnnotationIndex != null) {
      final ann = _annotations[_selectedAnnotationIndex!];
      final rect = _denormalize(ann, widgetSize);
      final corners = [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ];
      for (int i = 0; i < 4; i++) {
        if ((pos - corners[i]).distance <= _handleHitRadius) {
          _activeHandleIndex = i;
          return; // Found handle
        }
      }
    }

    // If no handle, maybe moving box
    if (_selectedAnnotationIndex != null) {
      final rect = _denormalize(
        _annotations[_selectedAnnotationIndex!],
        widgetSize,
      );
      if (rect.contains(pos)) {
        // Initiate Move (store offset if needed, or just use delta)
        // _draggingBox = true;
      } else {
        // Tapped outside selected box? Deselect or select another
        // Logic handled in TapDown mostly, but here we confirm drag target
        _selectedAnnotationIndex = null; // Clicked outside
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, Size widgetSize) {
    final pos = details.localPosition;

    // Clamp to bounds
    final dx = pos.dx.clamp(0.0, widgetSize.width);
    final dy = pos.dy.clamp(0.0, widgetSize.height);
    final clampedPos = Offset(dx, dy);

    if (_isDrawingMode) {
      if (_startPoint != null) {
        setState(() {
          _currentPoint = clampedPos;
        });
      }
      return;
    }

    if (_selectedAnnotationIndex == null) return;

    setState(() {
      final index = _selectedAnnotationIndex!;
      final ann = _annotations[index];
      Rect rect = _denormalize(ann, widgetSize);

      if (_activeHandleIndex != null) {
        // Resizing
        double newLeft = rect.left;
        double newTop = rect.top;
        double newRight = rect.right;
        double newBottom = rect.bottom;

        switch (_activeHandleIndex) {
          case 0: // TL
            newLeft = dx;
            newTop = dy;
            break;
          case 1: // TR
            newRight = dx;
            newTop = dy;
            break;
          case 2: // BL
            newLeft = dx;
            newBottom = dy;
            break;
          case 3: // BR
            newRight = dx;
            newBottom = dy;
            break;
        }
        // Normalizing creates min/max so safe to flip
        final newRect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
        _annotations[index] = _normalize(
          newRect,
          widgetSize,
          ann.classId,
          ann.className,
        );
      } else {
        // Moving
        final delta = details.delta;
        final newRect = rect.shift(delta);

        // Bound check
        if (newRect.left >= 0 &&
            newRect.top >= 0 &&
            newRect.right <= widgetSize.width &&
            newRect.bottom <= widgetSize.height) {
          _annotations[index] = _normalize(
            newRect,
            widgetSize,
            ann.classId,
            ann.className,
          );
        }
      }
    });
  }

  void _handlePanEnd(DragEndDetails details, Size widgetSize) {
    if (_isDrawingMode) {
      if (_startPoint != null && _currentPoint != null) {
        if ((_startPoint! - _currentPoint!).distance > 10) {
          final rect = Rect.fromPoints(_startPoint!, _currentPoint!);
          final newAnn = _normalize(
            rect,
            widgetSize,
            _selectedClassId,
            _classes[_selectedClassId],
          );
          setState(() {
            _annotations.add(newAnn);
            _selectedAnnotationIndex =
                _annotations.length - 1; // Auto select new
            // Switch to edit mode automatically? Or stay in draw mode?
            // User requested "Drag area, Resize, Delete" which implies edit mode.
            // But usually drawing is continuous. Let's keep drawing mode active.
            _selectedAnnotationIndex = null;
          });
        }
      }
      setState(() {
        _startPoint = null;
        _currentPoint = null;
      });
    }
    _activeHandleIndex = null;
  }

  // Helpers
  Rect _denormalize(Annotation ann, Size size) {
    return Rect.fromCenter(
      center: Offset(ann.xCenter * size.width, ann.yCenter * size.height),
      width: ann.width * size.width,
      height: ann.height * size.height,
    );
  }

  Annotation _normalize(Rect rect, Size size, int classId, String? className) {
    // Ensure positive width/height
    final l = min(rect.left, rect.right);
    final t = min(rect.top, rect.bottom);
    final w = rect.width.abs();
    final h = rect.height.abs();

    return Annotation(
      classId: classId,
      xCenter: (l + w / 2) / size.width,
      yCenter: (t + h / 2) / size.height,
      width: w / size.width,
      height: h / size.height,
      className: className,
    );
  }
}
