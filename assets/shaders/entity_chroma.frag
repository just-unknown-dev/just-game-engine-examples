// Per-entity chromatic aberration shader.
//
// Splits the entity's rendered layer into separate red/green/blue channels,
// offsetting red right and blue left relative to the entity bounds.
//
// Uniforms (float indices):
//   0-1  vec2  uSize      — entity bounding-rect width / height in pixels
//   2    float uStrength  — channel separation in UV units (e.g. 0.012)
// Sampler (auto-bound by ImageFilter.shader via canvas.saveLayer):
//   0    sampler2D uTexture — the entity's composited layer

#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;
uniform float uStrength;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  float r = texture(uTexture, uv + vec2( uStrength, 0.0)).r;
  float g = texture(uTexture, uv                        ).g;
  float b = texture(uTexture, uv - vec2( uStrength, 0.0)).b;
  float a = texture(uTexture, uv                        ).a;

  fragColor = vec4(r, g, b, a);
}
