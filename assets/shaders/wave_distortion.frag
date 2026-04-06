// Fullscreen horizontal wave-distortion post-process shader.
//
// Uniforms (float indices):
//   0-1  vec2  uResolution  — viewport width / height in pixels
//   2    float uTime        — elapsed time in seconds (for animation)
// Sampler (auto-bound by ImageFilter.shader):
//   0    sampler2D uTexture — the composed scene

#include <flutter/runtime_effect.glsl>

uniform vec2  uResolution;
uniform float uTime;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;

  float wave = sin(uv.y * 18.0 + uTime * 2.4) * 0.006
             + sin(uv.y *  9.0 - uTime * 1.1) * 0.003;

  vec2 distortedUV = clamp(uv + vec2(wave, 0.0), 0.0, 1.0);
  fragColor = texture(uTexture, distortedUV);
}
