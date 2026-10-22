import 'dart:async';

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
  // Feature highlighted in the list (desktop).
  FeatureItem? _selectedFeature;

  // Feature mounted in the showcase area (desktop). Lags [_selectedFeature]
  // by a frame while the previous demo goes.
  FeatureItem? _shownFeature;

  // Completes once the demo most recently mounted has been disposed.
  Future<void>? _demoGone;

  // Whether a demo page is pushed on top (mobile).
  bool _routeOpen = false;

  @override
  void initState() {
    super.initState();
    // The demo to open on (desktop): `--dart-define=DEMO=<feature title>`,
    // else the first.
    const initial = String.fromEnvironment('DEMO');
    if (appFeatures.isNotEmpty) {
      _selectedFeature = _shownFeature = appFeatures.firstWhere(
        (f) => f.title == initial,
        orElse: () => appFeatures.first,
      );
    }
  }

  void _onDemoMounted(Future<void> gone) => _demoGone = gone;

  // The 2-D demos share one engine and clear its world in `dispose()`.
  // Flutter mounts a new screen before it disposes the one it replaces, so
  // the next demo is only mounted once the previous one has gone —
  // otherwise its cleanup would wipe the new demo's world.
  Future<void> _onFeatureSelected(FeatureItem feature, bool isMobile) async {
    if (isMobile) {
      if (_routeOpen) return;
      _routeOpen = true;
      final previous = _demoGone;
      if (previous != null) await previous;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(feature.title)),
            body: _DemoHost(feature: feature, onMounted: _onDemoMounted),
          ),
        ),
      );
      _routeOpen = false;
    } else {
      if (feature == _selectedFeature && _shownFeature == feature) return;
      final previous = _demoGone;
      setState(() {
        _selectedFeature = feature;
        _shownFeature = null;
      });
      if (previous != null) await previous;
      if (!mounted || _selectedFeature != feature) return;
      setState(() => _shownFeature = feature);
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
          selectedTileColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
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
    final shown = _shownFeature;
    if (shown == null) {
      // The previous demo is on its way out.
      return const ColoredBox(color: Color(0xFF07070F));
    }

    return Column(
      children: [
        Expanded(
          child: ClipRect(
            child: _DemoHost(
              key: ValueKey(shown.title),
              feature: shown,
              onMounted: _onDemoMounted,
            ),
          ),
        ),
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

/// Builds one demo and reports when it has gone: [onMounted] receives a
/// future that completes once the demo's screen has been disposed (a
/// child's `dispose` runs before its parent's).
class _DemoHost extends StatefulWidget {
  const _DemoHost({super.key, required this.feature, required this.onMounted});

  final FeatureItem feature;
  final void Function(Future<void> gone) onMounted;

  @override
  State<_DemoHost> createState() => _DemoHostState();
}

class _DemoHostState extends State<_DemoHost> {
  final Completer<void> _gone = Completer<void>();

  @override
  void initState() {
    super.initState();
    widget.onMounted(_gone.future);
  }

  @override
  void dispose() {
    _gone.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.feature.builder(context);
}
