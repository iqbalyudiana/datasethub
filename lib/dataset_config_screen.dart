import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data_capture_screen.dart';
import 'services/localization_service.dart';

class DatasetConfigScreen extends StatefulWidget {
  final String datasetType;

  const DatasetConfigScreen({super.key, this.datasetType = 'Classification'});

  @override
  State<DatasetConfigScreen> createState() => _DatasetConfigScreenState();
}

class _DatasetConfigScreenState extends State<DatasetConfigScreen> {
  final _folderNameController = TextEditingController();
  int _frameSize = 224;
  int _outputResolution = 224;
  int _burstSize = 1;

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  void _startCapture() {
    if (_folderNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.get('enter_name_error'),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataCaptureScreen(
          folderName: _folderNameController.text,
          frameSize: _frameSize,
          outputResolution: _outputResolution,
          burstSize: _burstSize,
          datasetType: widget.datasetType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          LocalizationService.get('configure_dataset'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.get('new_dataset'),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1C1E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LocalizationService.get('setup_params'),
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Dataset Name Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationService.get('dataset_name'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1C1E),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _folderNameController,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: LocalizationService.get('enter_name_hint'),
                      hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                      prefixIcon: const Icon(
                        Icons.folder_open_rounded,
                        color: Colors.blueAccent,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Frame Size Section
            _buildConfigCard(
              title: LocalizationService.get('capture_quality'),
              value: '${_frameSize}x$_frameSize',
              color: const Color(0xFF2196F3),
              icon: Icons.high_quality_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF2196F3),
                      inactiveTrackColor: const Color(0xFFE3F2FD),
                      thumbColor: const Color(0xFF2196F3),
                      overlayColor: const Color(0x292196F3),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: _frameSize.toDouble(),
                      min: 128,
                      max: 1080,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() {
                          _frameSize = value.toInt();
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _frameSize <= 240
                          ? LocalizationService.get('low_quality')
                          : _frameSize <= 480
                          ? LocalizationService.get('medium_quality')
                          : _frameSize <= 720
                          ? LocalizationService.get('high_quality')
                          : LocalizationService.get('very_high_quality'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Output Resolution Section
            _buildConfigCard(
              title: LocalizationService.get('save_resolution'),
              value: '${_outputResolution}px',
              color: const Color(0xFFFF9800),
              icon: Icons.photo_size_select_large_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.datasetType == 'Object Detection')
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "YOLO Presets:",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [416, 640, 1280].map((res) {
                                  final isSelected = _outputResolution == res;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        "${res}px",
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFFFF9800),
                                      backgroundColor: Colors.grey[100],
                                      onSelected: (bool selected) {
                                        if (selected) {
                                          setState(() {
                                            _outputResolution = res;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFFF9800),
                      inactiveTrackColor: const Color(0xFFFFF3E0),
                      thumbColor: const Color(0xFFFF9800),
                      overlayColor: const Color(0x29FF9800),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: _outputResolution.toDouble(),
                      min: 64,
                      max: 1280, // Increased max to cover 1280
                      divisions: (1280 - 64) ~/ 32, // More granular
                      onChanged: (value) {
                        setState(() {
                          _outputResolution = value.toInt();
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      LocalizationService.get('resolution_hint'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFF57C00),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Burst Size Section
            _buildConfigCard(
              title: LocalizationService.get('burst_mode'),
              value: '$_burstSize ${LocalizationService.get('burst_shots')}',
              color: const Color(0xFF4CAF50),
              icon: Icons.burst_mode_rounded,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(LocalizationService.get('photos_per_tap')),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _burstSize,
                          icon: const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Color(0xFF4CAF50),
                          ),
                          items: [1, 5, 10, 20].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                '$value',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _burstSize = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Start Button
            SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed: _startCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0xFF00695C).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_rounded, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      LocalizationService.get('start_stream'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1F4F9),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1C1E),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
