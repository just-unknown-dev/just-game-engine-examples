import 'package:flutter/material.dart';
import '../core/models/feature_item.dart';
import 'camera/camera_system_screen.dart';
import 'core_engine/core_engine_screen.dart';
import 'rendering/rendering_engine_screen.dart';
import 'raycasting/raycasting_engine_screen.dart';

import 'animation/animation_system_screen.dart';
import 'sprite/sprite_system_screen.dart';
import 'particle/particle_system_screen.dart';
import 'physics/physics_engine_screen.dart';
import 'input/input_system_screen.dart';
import 'audio/audio_engine_screen.dart';
import 'tiled/tiled_map_screen.dart';
import 'parallax/parallax_system_screen.dart';
import 'post_processing/post_processing_screen.dart';
import 'shaders/shader_screen.dart';
import 'storage/storage_signals_screen.dart';
import 'database/database_signals_screen.dart';
import 'effects/deterministic_effects_screen.dart';
import 'narrative/narrative_system_screen.dart';

// List of features to showcase in the Demo App.
final List<FeatureItem> appFeatures = [
  FeatureItem(
    title: 'Core Engine',
    icon: Icons.memory,
    description: 'Showcases the Entity-Component-System (ECS) architecture.',
    builder: (context) => const CoreEngineScreen(),
  ),
  FeatureItem(
    title: 'Rendering Engine',
    icon: Icons.brush,
    description: 'Basic shape drawing and camera transformations.',
    builder: (context) => const RenderingEngineScreen(),
  ),
  FeatureItem(
    title: 'Camera System',
    icon: Icons.videocam,
    description:
        'Spring follow, lookahead, multi-target, trauma shake, path, rooms, cinematic, screen effects & world bounds.',
    builder: (context) => const CameraSystemScreen(),
  ),
  FeatureItem(
    title: 'Sprite System',
    icon: Icons.image,
    description: 'Loading and rendering static 2D sprites.',
    builder: (context) => const SpriteSystemScreen(),
  ),
  FeatureItem(
    title: 'Animation System',
    icon: Icons.animation,
    description: 'Sprite sheet frame-by-frame animations.',
    builder: (context) => const AnimationSystemScreen(),
  ),
  FeatureItem(
    title: 'Particle System',
    icon: Icons.blur_on,
    description: 'Visual effects like explosions, fire, and smoke.',
    builder: (context) => const ParticleSystemScreen(),
  ),
  FeatureItem(
    title: 'Physics Engine',
    icon: Icons.sports_basketball,
    description: 'Rigid body dynamics and collision detection.',
    builder: (context) => const PhysicsEngineScreen(),
  ),
  FeatureItem(
    title: 'Raycasting Engine',
    icon: Icons.linear_scale_rounded,
    description: 'Ray casting and hit detection showcase.',
    builder: (context) => const RaycastingEngineScreen(),
  ),
  FeatureItem(
    title: 'Input System',
    icon: Icons.gamepad,
    description: 'Keyboard, mouse, touch, and controller inputs.',
    builder: (context) => const InputSystemScreen(),
  ),
  FeatureItem(
    title: 'Audio Engine',
    icon: Icons.music_note,
    description: 'BGM and SFX playback handling.',
    builder: (context) => const AudioEngineScreen(),
  ),
  FeatureItem(
    title: 'Parallax System',
    icon: Icons.layers,
    description: 'Multi-layer scrolling backgrounds with depth illusion.',
    builder: (context) => const ParallaxSystemScreen(),
  ),
  FeatureItem(
    title: 'Post-Processing',
    icon: Icons.auto_fix_high,
    description: 'Fullscreen & per-entity shader effects via ShaderComponent.',
    builder: (context) => const PostProcessingScreen(),
  ),
  FeatureItem(
    title: 'Custom Shaders',
    icon: Icons.blur_circular,
    description: 'Real GLSL shaders loaded via FragmentProgram.fromAsset.',
    builder: (context) => const ShaderScreen(),
  ),
  FeatureItem(
    title: 'Tiled Map',
    icon: Icons.map,
    description: 'Loading and parsing .tmx map files.',
    builder: (context) => const TiledMapScreen(),
  ),
  FeatureItem(
    title: 'Deterministic Effects',
    icon: Icons.auto_awesome_motion,
    description:
        'ECS-driven deterministic effects: Move, Scale, Rotate, Fade, ColorTint, Shake, Path, Sequence, Parallel, Repeat & composites.',
    builder: (context) => const DeterministicEffectsScreen(),
  ),
  FeatureItem(
    title: 'Storage & Signals',
    icon: Icons.save,
    description: 'just_storage with reactive Signals.',
    builder: (context) => const StorageSignalsScreen(),
  ),
  FeatureItem(
    title: 'Database & Signals',
    icon: Icons.storage,
    description: 'just_database paired with reactive Signals.',
    builder: (context) => const DatabaseSignalsScreen(),
  ),
  FeatureItem(
    title: 'Narrative & Dialogue',
    icon: Icons.chat_bubble_outline_rounded,
    description:
        'Yarn Spinner 2.x parser, branching dialogue, variables, custom commands, '
        'reactive NarrativeSignals, ECS integration, and built-in dialogue widgets.',
    builder: (context) => const NarrativeSystemScreen(),
  ),
];
