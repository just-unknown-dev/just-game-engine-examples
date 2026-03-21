import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';

class CameraZoomControls extends StatefulWidget {
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
  State<CameraZoomControls> createState() => _CameraZoomControlsState();
}

class _CameraZoomControlsState extends State<CameraZoomControls> {
  void _setZoom(double zoom) {
    widget.camera.setZoom(zoom);
    setState(() {});
  }

  void _zoomIn() {
    _setZoom(widget.camera.zoom + widget.zoomStep);
  }

  void _zoomOut() {
    _setZoom(widget.camera.zoom - widget.zoomStep);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final delta = event.scrollDelta.dy;
    if (delta == 0) return;

    final direction = delta > 0 ? -1.0 : 1.0;
    _setZoom(widget.camera.zoom + (widget.scrollZoomFactor * direction));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'camera-zoom-in',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'camera-zoom-out',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
