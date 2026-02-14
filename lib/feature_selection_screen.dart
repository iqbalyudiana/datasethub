import 'package:flutter/material.dart';
import 'classification_screen.dart';

class FeatureSelectionScreen extends StatelessWidget {
  const FeatureSelectionScreen({super.key});

  final List<Map<String, dynamic>> features = const [
    {'title': 'Classification', 'icon': Icons.category, 'color': Colors.blue},
    {
      'title': 'Object Detection',
      'icon': Icons.center_focus_strong,
      'color': Colors.green,
    },
    {'title': 'Segmentation', 'icon': Icons.pie_chart, 'color': Colors.orange},
    {'title': 'Landmark', 'icon': Icons.touch_app, 'color': Colors.purple},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Feature')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Aplikasi Pengumpul Dataset Berbasis Mobile untuk Training Model AI",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Aplikasi ini adalah aplikasi di smartphone yang membantu pengguna mengumpulkan data gambar untuk melatih model Artificial Intelligence (AI). Melalui kamera HP, pengguna dapat mengambil gambar, memberi label, dan langsung menyimpannya dalam format yang sudah rapi dan siap digunakan untuk training di komputer.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (feature['title'] == 'Classification') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ClassificationScreen(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${feature['title']} selected'),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            feature['icon'],
                            size: 48,
                            color: feature['color'],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            feature['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
