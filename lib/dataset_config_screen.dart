import 'package:flutter/material.dart';
import 'data_capture_screen.dart';

class DatasetConfigScreen extends StatefulWidget {
  const DatasetConfigScreen({super.key});

  @override
  State<DatasetConfigScreen> createState() => _DatasetConfigScreenState();
}

class _DatasetConfigScreenState extends State<DatasetConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _folderController = TextEditingController();
  int _selectedFrameSize = 224;
  int _selectedResolution = 224;

  final List<Map<String, dynamic>> _frameOptions = [
    {'value': 128, 'label': '128 x 128 (Ringan dan cepat, eksperimen awal)'},
    {'value': 160, 'label': '160 x 160 (Model mobile ringan)'},
    {'value': 224, 'label': '224 x 224 (Standar paling umum)'},
    {'value': 256, 'label': '256 x 256 (Detail lebih baik)'},
    {'value': 299, 'label': '299 x 299 (Model tertentu)'},
    {'value': 384, 'label': '384 x 384 (Model modern akurasi tinggi)'},
  ];

  final List<Map<String, dynamic>> _resolutionOptions = [
    {'value': 128, 'label': '128 x 128 (Dataset kecil / eksperimen cepat)'},
    {'value': 224, 'label': '224 x 224 (Standar banyak CNN)'},
    {'value': 256, 'label': '256 x 256 (Detail sedikit lebih baik)'},
    {'value': 299, 'label': '299 x 299 (Model tertentu seperti Inception)'},
    {'value': 384, 'label': '384 x 384 (Model modern / akurasi tinggi)'},
  ];

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  void _startCapture() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DataCaptureScreen(
            folderName: _folderController.text,
            frameSize: _selectedFrameSize,
            outputResolution: _selectedResolution,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dataset Configuration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _folderController,
                decoration: const InputDecoration(
                  labelText: 'Dataset Name (New Folder)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Cat_V1',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a dataset name';
                  }
                  // Basic regex for valid folder names
                  if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(value)) {
                    return 'Only alphanumeric, underscore, and hyphen allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Frame Size (Preview Guide)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedFrameSize,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _frameOptions.map((option) {
                  return DropdownMenuItem<int>(
                    value: option['value'] as int,
                    child: Text(
                      option['label'] as String,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                isExpanded: true,
                onChanged: (value) {
                  setState(() {
                    _selectedFrameSize = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Output Resolution (Save Size)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedResolution,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _resolutionOptions.map((option) {
                  return DropdownMenuItem<int>(
                    value: option['value'] as int,
                    child: Text(
                      option['label'] as String,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                isExpanded: true,
                onChanged: (value) {
                  setState(() {
                    _selectedResolution = value!;
                  });
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _startCapture,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Data Capture',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
