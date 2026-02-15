import 'package:flutter/material.dart';
import 'dataset_group_screen.dart';
import 'widgets/custom_animations.dart';

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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Dataset Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black45,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal, Colors.tealAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.hub,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16.0,
              crossAxisSpacing: 16.0,
              children: [
                FadeInSlide(
                  index: 0,
                  child: _FeatureCard(
                    title: 'Classification',
                    icon: Icons.category,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DatasetGroupScreen(
                            title: 'Classification',
                            datasetType: 'Classification',
                            icon: Icons.category,
                            color: Colors.blueAccent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                FadeInSlide(
                  index: 1,
                  child: _FeatureCard(
                    title: 'Object Detection',
                    icon: Icons.center_focus_strong,
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DatasetGroupScreen(
                            title: 'Object Detection',
                            datasetType: 'Object Detection',
                            icon: Icons.center_focus_strong,
                            color: Colors.orangeAccent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                FadeInSlide(
                  index: 2,
                  child: _FeatureCard(
                    title: 'Pose Estimation',
                    icon: Icons.accessibility_new,
                    color: Colors.purpleAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming Soon!')),
                      );
                    },
                  ),
                ),
                FadeInSlide(
                  index: 3,
                  child: _FeatureCard(
                    title: 'Segmentation',
                    icon: Icons.layers,
                    color: Colors.greenAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming Soon!')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    "Aplikasi Pengumpul Dataset Berbasis Mobile",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Kumpulkan data gambar untuk melatih model AI dengan mudah. Ambil, labeli, dan simpan.",
                    style: TextStyle(height: 1.5, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, color.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
