import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dataset_group_screen.dart';
import 'widgets/custom_animations.dart';
import 'services/localization_service.dart';

class FeatureSelectionScreen extends StatelessWidget {
  const FeatureSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Lighter background
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              ValueListenableBuilder<Locale>(
                valueListenable: LocalizationService.localeNotifier,
                builder: (context, locale, child) {
                  final isEn = locale.languageCode == 'en';
                  return GestureDetector(
                    onTap: () {
                      final next = isEn
                          ? const Locale('id')
                          : const Locale('en');
                      LocalizationService.changeLocale(next);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEn ? 'EN' : 'ID',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
              title: Text(
                LocalizationService.get('feature_selection_title'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text on gradient
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF00695C), // Dark Teal
                      const Color(0xFF009688), // Teal
                      const Color(0xFF80CBC4), // Light Teal
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Icon(
                        Icons.hub,
                        size: 240,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Premium Edition",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 20.0,
              crossAxisSpacing: 20.0,
              children: [
                FadeInSlide(
                  index: 0,
                  child: _FeatureCard(
                    title: LocalizationService.get('classification_title'),
                    subtitle: LocalizationService.get(
                      'classification_subtitle',
                    ),
                    icon: Icons.category_rounded,
                    color: const Color(0xFF2196F3),
                    gradientColors: [
                      const Color(0xFF2196F3).withValues(alpha: 0.1),
                      const Color(0xFFE3F2FD),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DatasetGroupScreen(
                            title: LocalizationService.get(
                              'classification_title',
                            ),
                            datasetType: 'Classification',
                            icon: Icons.category_rounded,
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                FadeInSlide(
                  index: 1,
                  child: _FeatureCard(
                    title: LocalizationService.get('detection_title'),
                    subtitle: LocalizationService.get('detection_subtitle'),
                    icon: Icons.view_in_ar_rounded,
                    color: const Color(0xFFFF9800),
                    gradientColors: [
                      const Color(0xFFFF9800).withValues(alpha: 0.1),
                      const Color(0xFFFFF3E0),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DatasetGroupScreen(
                            title: LocalizationService.get('detection_title'),
                            datasetType: 'Object Detection',
                            icon: Icons.view_in_ar_rounded,
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                FadeInSlide(
                  index: 2,
                  child: _FeatureCard(
                    title: LocalizationService.get('pose_title'),
                    subtitle: LocalizationService.get('pose_subtitle'),
                    icon: Icons.accessibility_new_rounded,
                    color: const Color(0xFF9C27B0),
                    gradientColors: [
                      const Color(0xFF9C27B0).withValues(alpha: 0.1),
                      const Color(0xFFF3E5F5),
                    ],
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(LocalizationService.get('coming_soon')),
                        ),
                      );
                    },
                  ),
                ),
                FadeInSlide(
                  index: 3,
                  child: _FeatureCard(
                    title: LocalizationService.get('segmentation_title'),
                    subtitle: LocalizationService.get('segmentation_subtitle'),
                    icon: Icons.layers_rounded,
                    color: const Color(0xFF4CAF50),
                    gradientColors: [
                      const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      const Color(0xFFE8F5E9),
                    ],
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(LocalizationService.get('coming_soon')),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 48,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          LocalizationService.get('mobile_collector_title'),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1C1E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          LocalizationService.get('mobile_collector_desc'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
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
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  icon,
                  size: 100,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 28, color: color),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1C1E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
