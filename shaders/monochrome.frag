#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 foreground;
    float minimumOpacity;
    float maximumOpacity;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    // Unpremultiply luminance before mapping it to the active/inactive range.
    // Reapply source alpha afterwards to preserve transparent edges and holes.
    vec4 pixel = texture(source, qt_TexCoord0);
    float luminance = clamp(dot(pixel.rgb, vec3(0.299, 0.587, 0.114)) / max(pixel.a, 0.00001), 0.0, 1.0);
    float coverage = pixel.a * mix(minimumOpacity, maximumOpacity, luminance);
    fragColor = foreground * coverage * qt_Opacity;
}
