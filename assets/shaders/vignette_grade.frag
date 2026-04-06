// Fullscreen vignette + warm colour-grade post-process shader.
//
// Uniforms (float indices):
//   0-1  vec2  uResolution  — viewport width / height in pixels
// Sampler (auto-bound by ImageFilter.shader):
//   0    sampler2D uTexture — the composed scene

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;

  vec4 color = texture(uTexture, uv);

  // Radial vignette: darken toward the edges
  vec2  centered = uv - 0.5;
  float vignette  = 1.0 - dot(centered, centered) * 2.1;
  vignette = clamp(vignette, 0.0, 1.0);

  // Subtle warm tint (boost reds, reduce blues slightly)
  color.r = min(color.r * 1.04, 1.0);
  color.b = color.b * 0.94;

  fragColor = vec4(color.rgb * vignette, color.a);
}
