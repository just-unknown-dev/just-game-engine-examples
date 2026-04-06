// Per-entity hit / damage flash shader.
//
// ⚠ Flutter coordinate-space limitation
//   FlutterFragCoord() returns screen-space pixels. For per-entity
//   ShaderComponent, canvas.saveLayer is called inside the camera transform
//   so uv = FlutterFragCoord().xy / uSize produces values outside [0,1] and
//   all texture samples are clamped to the edge colour.
//
//   FIX: Use canvas.saveLayer + BlendMode.srcATop in onRender instead:
//     canvas.saveLayer(localBounds, Paint());
//     paintSprite(canvas);
//     canvas.drawRect(localBounds,
//       Paint()..color = flashColor.withValues(alpha: intensity)
//               ..blendMode = BlendMode.srcATop);
//     canvas.restore();
//
// Overlays the entity's pixels with a configurable flash colour.  Alpha
// transparency is fully preserved so the flash stays within the sprite's
// visible silhouette.
//
// Uniforms (float indices):
//   0-1  vec2  uSize            — entity bounding-rect width / height
//   2    float uFlashIntensity  — blend weight: 0 = original, 1 = full flash
//   3    float uFlashR          — flash colour red   component (0-1)
//   4    float uFlashG          — flash colour green component (0-1)
//   5    float uFlashB          — flash colour blue  component (0-1)
// Sampler (auto-bound by ImageFilter.shader via canvas.saveLayer):
//   0    sampler2D uTexture     — the entity's composited layer

#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;
uniform float uFlashIntensity;
uniform float uFlashR;
uniform float uFlashG;
uniform float uFlashB;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv    = FlutterFragCoord().xy / uSize;
  vec4 src   = texture(uTexture, uv);

  // Only flash pixels that belong to the visible sprite silhouette.
  // step() avoids a conditional branch, keeping the hot path branchless.
  float visible = step(0.01, src.a);

  // Target flash colour in pre-multiplied alpha space.
  // Multiplying by src.a keeps the brightness proportional to the original
  // alpha so transparent edges stay soft.
  vec3 flashTarget = vec3(uFlashR, uFlashG, uFlashB) * src.a;

  float blend  = uFlashIntensity * visible;
  vec3  result = mix(src.rgb, flashTarget, blend);

  fragColor = vec4(result, src.a);
}
