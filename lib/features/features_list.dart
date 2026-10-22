import 'package:flutter/material.dart';
import '../core/models/feature_item.dart';
import 'camera/camera_system_screen.dart';
import 'core_rendering/core_rendering_screen.dart';
import 'package:just_game_engine_examples/features/raycasting/raycasting_engine_screen.dart';

import 'package:just_game_engine_examples/features/animation/animation_system_screen.dart';
import 'package:just_game_engine_examples/features/sprite/sprite_system_screen.dart';
import 'package:just_game_engine_examples/features/particle/particle_system_screen.dart';
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
import 'lighting_2d/lighting_2d_screen.dart';
import 'materials_2d/materials_2d_screen.dart';
import 'timeline/timeline_screen.dart';
import 'scenes/scenes_prefabs_screen.dart';
import 'graphics_3d/graphics_3d_screen.dart';
import 'physics_3d/physics_3d_screen.dart';

// List of features to showcase in the Demo App.
final List<FeatureItem> appFeatures = [
  FeatureItem(
    title: 'Core Engine & Rendering',
    icon: Icons.memory,
    description:
        'Engine lifecycle, time scale, ECS tags, subsystems and the game loop; '
        'primitives, layers, particles, hierarchy, custom drawing and culling.',
    builder: (context) => const CoreRenderingScreen(),
  ),
  FeatureItem(
    title: 'Camera System',
    icon: Icons.videocam,
    description:
        'Virtual cameras and the camera brain: framing, dead/soft zones, group framing, '
        'confiners, triggers, dolly paths, blend lists, impulses & noise.',
    builder: (context) => const CameraSystemScreen(),
  ),
  FeatureItem(
    title: '2D Lighting & Shadows',
    icon: Icons.lightbulb_outline,
    description:
        'Lighting2D ambient light, Light2D point & spot lights, ShadowCaster2D soft shadows '
        'and emissive materials.',
    builder: (context) => const Lighting2DScreen(),
  ),
  FeatureItem(
    title: '2D Materials',
    icon: Icons.texture,
    description:
        'Material2D effects (wave, scroll, palette, outline, glow, dissolve, flash...) '
        'and full-screen ScreenMaterials (pixelate, CRT, scanlines, vignette).',
    builder: (context) => const Materials2DScreen(),
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
    description:
        'SpriteAnimationComponent atlases (TexturePacker / Aseprite) and AnimatorComponent '
        'state machines.',
    builder: (context) => const AnimationSystemScreen(),
  ),
  FeatureItem(
    title: 'Timelines',
    icon: Icons.view_timeline_outlined,
    description:
        'TimelineAsset & TimelinePlayerComponent: property curves, events, activation, '
        'camera shots, nested timelines and playback control.',
    builder: (context) => const TimelineScreen(),
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
    description:
        'RigidBody2D & Collider2D, joints, collision layers, forces and CharacterBody2D.',
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
    description:
        'just_inputs actions & bindings across keyboard, mouse, gamepads and touch; '
        'on-screen controls and rebinding.',
    builder: (context) => const InputSystemScreen(),
  ),
  FeatureItem(
    title: 'Audio Engine',
    icon: Icons.music_note,
    description:
        'Music, SFX, channels and 3D positional sound with a listener.',
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
    description:
        'LevelMapComponent: Tiled .tmx maps, merged map collision, runtime tile edits '
        'and maps built in code.',
    builder: (context) => const TiledMapScreen(),
  ),
  FeatureItem(
    title: 'Scenes & Prefabs',
    icon: Icons.account_tree_outlined,
    description:
        'JSON scenes via SceneLoader, custom component definitions, prefab files, '
        'save/reload round trips and format migration.',
    builder: (context) => const ScenesPrefabsScreen(),
  ),
  FeatureItem(
    title: '3D Graphics',
    icon: Icons.view_in_ar,
    description:
        'Flutter GPU 3D: PBR shapes & materials, lights, sky & fog, glTF models with '
        'skeletal animation, orbit camera rigs.',
    builder: (context) => const Graphics3DScreen(),
  ),
  FeatureItem(
    title: '3D Physics',
    icon: Icons.view_in_ar_outlined,
    description:
        'Jolt-powered RigidBody3D & Collider3D, CharacterBody3D, joints, raycasts '
        'and collision events.',
    builder: (context) => const Physics3DScreen(),
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
