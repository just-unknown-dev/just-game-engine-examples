// Per-entity water-ripple shader.
//
// ⚠ Flutter coordinate-space limitation
//   FlutterFragCoord() returns screen-space pixels. canvas.saveLayer for a
//   per-entity ShaderComponent is called inside the camera transform, so the
//   layer's top-left is not (0,0) in screen space. This means
//   uv = FlutterFragCoord().xy / uSize produces values outside [0,1] for
//   most entity positions — all texture samples are clamped to the edge
//   colour and the distortion is invisible.
//
//   FIX: Drive the sine-wave displacement in onRender (canvas.drawLine with
//   animated x-offsets) where coordinates are always layer-local. Keep this
//   shader for post-process use or as a tint-only overlay (set uAmplitude=0).
//
// Uniforms (float indices):
//   0-1  vec2  uSize       — entity bounding-rect width / height in pixels
//   2    float uTime       — elapsed time in seconds
//   3    float uAmplitude  — peak UV displacement (e.g. 0.015)
//   4    float uFrequency  — spatial frequency of the waves (e.g. 15.0)
// Sampler (auto-bound by ImageFilter.shader via canvas.saveLayer):
//   0    sampler2D uTexture — the entity's composited layer

#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;
uniform float uTime;
uniform float uAmplitude;
uniform float uFrequency;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // Three overlapping wave functions for organic-looking ripples
  float w1 = sin(uv.y * uFrequency       + uTime * 2.00) * uAmplitude;
  float w2 = cos(uv.x * uFrequency * 0.8 + uTime * 1.50) * uAmplitude * 0.60;
  float w3 = sin((uv.x + uv.y) * uFrequency * 0.5 + uTime * 3.10) * uAmplitude * 0.35;

  vec2 distortedUV = clamp(uv + vec2(w1 + w3, w2 + w3), 0.0, 1.0);

  vec4 color = texture(uTexture, distortedUV);

  // Subtle blue water tint
  color.rgb = mix(color.rgb, vec3(0.08, 0.40, 0.82) * color.a, 0.18);

  // Specular highlight — bright glint along wave crests
  float spec = max(0.0, sin(w1 * 38.0 + uTime * 5.5)) * 0.13;
  color.rgb = min(color.rgb + spec, vec3(1.0));

  fragColor = color;
}
