import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/features_list.dart';
import '../di/app_config.dart';
import '../models/feature_item.dart';
import '../widgets/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Currently selected feature for Desktop view
  FeatureItem? _selectedFeature;

  @override
  void initState() {
    super.initState();
    // Default to first feature if available
    if (appFeatures.isNotEmpty) {
      _selectedFeature = appFeatures.first;
    }
  }

  void _onFeatureSelected(FeatureItem feature, bool isMobile) {
    if (isMobile) {
      // Mobile: Push new screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(feature.title)),
            body: feature.builder(context),
          ),
        ),
      );
    } else {
      // Desktop: Update local state
      setState(() {
        _selectedFeature = feature;
      });
    }
  }

  Widget _buildMenuList(bool isMobile) {
    return ListView.builder(
      itemCount: appFeatures.length,
      itemBuilder: (context, index) {
        final feature = appFeatures[index];
        final isSelected = !isMobile && _selectedFeature == feature;

        return ListTile(
          leading: Icon(
            feature.icon,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
          title: Text(
            feature.title,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
          subtitle: Text(
            feature.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          selected: isSelected,
          selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
          onTap: () => _onFeatureSelected(feature, isMobile),
          trailing: isMobile ? const Icon(Icons.chevron_right, size: 16) : null,
        );
      },
    );
  }

  Widget _buildShowcaseArea() {
    if (_selectedFeature == null) {
      return const Center(child: Text('Select a feature to showcase.'));
    }

    return Column(
      children: [
        Expanded(child: ClipRect(child: _selectedFeature!.builder(context))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Just Game Engine Examples'),
        centerTitle: false,
        elevation: 1,
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Open GitHub repo in a new tab
              final url = Uri.parse(
                'https://github.com/just-unknown-dev/just-game-engine-examples',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                throw 'Could not launch $url';
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                const Icon(Icons.code, size: 16),
                const Text('Github'),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive breakpoint (e.g., 800px)
          final isMobile = constraints.maxWidth < 800;
          getIt<AppConfig>().isMobile = isMobile;

          return ResponsiveLayout(
            isMobile: isMobile,
            menuList: _buildMenuList(isMobile),
            showcaseArea: _buildShowcaseArea(),
          );
        },
      ),
    );
  }
}
