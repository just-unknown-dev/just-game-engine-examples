// Per-entity vertex-wave (UV-displacement) shader.
//
// ⚠ Flutter coordinate-space limitation
//   FlutterFragCoord() returns screen-space pixels. For per-entity
//   ShaderComponent, canvas.saveLayer is called inside the camera transform
//   so uv = FlutterFragCoord().xy / uSize produces values outside [0,1].
//   The distorted UV is clamped to edge pixels — sway is invisible.
//
//   FIX: Simulate vertex displacement by drawing horizontal slices in onRender,
//   each translated by the same sine formula as this shader:
//     for (double y = top; y < bottom; y += sliceH) {
//       final uvY = (y - top) / height;       // 0=tip, 1=root
//       final xOff = sin(uvY * 3.8 + t * speed) * strength * (1-uvY) * width;
//       canvas.save();
//       canvas.clipRect(Rect.fromLTWH(left, y, width, sliceH));
//       canvas.translate(xOff, 0);
//       paintSprite(canvas);
//       canvas.restore();
//     }
//
// Simulates mesh-vertex displacement by warping the entity's texture sampling
// coordinates as a function of height within the bounding rect.  The top of
// the sprite sways more than the base, mimicking how wind affects a tree,
// swaying UI element, or screen-shake distortion.
//
// Displacement model (pseudo vertex-shader):
//   x_displaced = x + sin(y_normalised * freq + time * speed) * strength
//                     * (1 - y_normalised)   ← sway factor: 0 at bottom, 1 at top
//
// Uniforms (float indices):
//   0-1  vec2  uSize      — entity bounding-rect width / height in pixels
//   2    float uTime      — elapsed time in seconds
//   3    float uStrength  — peak horizontal displacement in UV units (e.g. 0.035)
//   4    float uSpeed     — animation speed multiplier (e.g. 1.5)
// Sampler (auto-bound by ImageFilter.shader via canvas.saveLayer):
//   0    sampler2D uTexture — the entity's composited layer

#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;
uniform float uTime;
uniform float uStrength;
uniform float uSpeed;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2  uv          = FlutterFragCoord().xy / uSize;

  // swayFactor = 1 at top (uv.y == 0), 0 at bottom (uv.y == 1)
  float swayFactor  = 1.0 - uv.y;

  // Primary horizontal sway
  float swayX = sin(uv.y * 3.8 + uTime * uSpeed) * uStrength * swayFactor;

  // Secondary subtle vertical compression (like a breeze puffing the canopy)
  float swayY = cos(uv.x * 2.4 + uTime * uSpeed * 0.55) * uStrength * swayFactor * 0.22;

  vec2 distortedUV = clamp(uv + vec2(swayX, swayY), 0.0, 1.0);

  fragColor = texture(uTexture, distortedUV);
}
