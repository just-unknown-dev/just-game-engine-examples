import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';

/// Delegates to [GameCameraControls] from the engine package.
///
/// All workspace screens continue to import this file unchanged.
/// The performance-correct implementation lives in [GameCameraControls].
class CameraZoomControls extends StatelessWidget {
  const CameraZoomControls({
    super.key,
    required this.camera,
    required this.child,
    this.zoomStep = 0.1,
    this.scrollZoomFactor = 0.1,
  });

  final Camera camera;
  final Widget child;
  final double zoomStep;
  final double scrollZoomFactor;

  @override
  Widget build(BuildContext context) {
    return GameCameraControls(
      camera: camera,
      enablePan: false,
      enablePinch: true,
      showZoomLevel: true,
      child: child,
    );
  }
}
