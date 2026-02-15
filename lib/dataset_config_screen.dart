import 'package:flutter/material.dart';
import 'data_capture_screen.dart';

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
        const SnackBar(content: Text('Please enter a dataset name')),
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
      appBar: AppBar(title: const Text('Configure Dataset')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New Dataset',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your data capture parameters.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Dataset Name Section
            const Text(
              'Dataset Name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _folderNameController,
              decoration: const InputDecoration(
                hintText: 'e.g., Cat_Faces',
                prefixIcon: Icon(Icons.folder_open),
              ),
            ),
            const SizedBox(height: 24),

            // Frame Size Section
            const Text(
              'Capture Quality (Frame Size)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.blue.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Frame Size'),
                        Text(
                          '${_frameSize}x$_frameSize',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    Slider(
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
                    Text(
                      _frameSize <= 240
                          ? 'Low Quality (Fast)'
                          : _frameSize <= 480
                          ? 'Medium Quality (Standard)'
                          : _frameSize <= 720
                          ? 'High Quality (HD)'
                          : 'Very High Quality (Full HD)',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Output Resolution Section
            const Text(
              'Save Resolution (Output Size)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.orange.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Output Size'),
                        Text(
                          '${_outputResolution}px',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _outputResolution.toDouble(),
                      min: 64,
                      max: 1080,
                      divisions: 15,
                      label: _outputResolution.toString(),
                      activeColor: Colors.deepOrange,
                      onChanged: (value) {
                        setState(() {
                          _outputResolution = value.toInt();
                        });
                      },
                    ),
                    const Text(
                      'Final image size in pixels.',
                      style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Burst Size Section
            const Text(
              'Burst Mode',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.green.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.burst_mode, color: Colors.green),
                    const SizedBox(width: 16),
                    const Text('Photos per tap:'),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _burstSize,
                      underline: const SizedBox(),
                      items: [1, 5, 10, 20].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            '$value',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Start Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _startCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera),
                    SizedBox(width: 8),
                    Text(
                      'Start Stream Capture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
