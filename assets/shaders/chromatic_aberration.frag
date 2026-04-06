// Fullscreen chromatic aberration post-process shader.
//
// Uniforms (float indices):
//   0-1  vec2  uResolution   — viewport width / height in pixels
//   2    float uStrength      — aberration offset in UV units (e.g. 0.004)
// Sampler (auto-bound by ImageFilter.shader):
//   0    sampler2D uTexture   — the composed scene

#include <flutter/runtime_effect.glsl>

uniform vec2  uResolution;
uniform float uStrength;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;

  float r = texture(uTexture, uv + vec2( uStrength, 0.0)).r;
  float g = texture(uTexture, uv                        ).g;
  float b = texture(uTexture, uv - vec2( uStrength, 0.0)).b;
  float a = texture(uTexture, uv                        ).a;

  fragColor = vec4(r, g, b, a);
}
