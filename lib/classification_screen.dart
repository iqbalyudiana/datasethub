import 'package:flutter/material.dart';
import 'dataset_config_screen.dart';

class ClassificationScreen extends StatelessWidget {
  const ClassificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classification')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DatasetConfigScreen(),
                ),
              );
            },
            child: const _LayerCard(
              title: 'Layer 1: Data Capture',
              items: ['Camera module', 'Frame handler', 'Auto naming'],
              color: Colors.blueAccent,
            ),
          ),
          SizedBox(height: 16),
          _LayerCard(
            title: 'Layer 2: Dataset Processing',
            items: ['Resize engine', 'Split engine', 'Augmentation engine'],
            color: Colors.orangeAccent,
          ),
          SizedBox(height: 16),
          _LayerCard(
            title: 'Layer 3: Dataset Structuring',
            items: ['Folder generator', 'Metadata manager', 'Export builder'],
            color: Colors.greenAccent,
          ),
        ],
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;

  const _LayerCard({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Divider(),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(item, style: const TextStyle(fontSize: 16)),
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
