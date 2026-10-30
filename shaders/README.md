# Monochrome application icons

`monochrome.frag` maps the original icon's luminance into alpha coverage:
55–100% for active windows and 20–65% for inactive windows. Every visible
pixel uses the bar foreground color, with detail represented only by
opacity. Source alpha is preserved for transparent edges and holes; the
parent item does not apply additional dimming in icon mode.

Qt 6 loads the precompiled `monochrome.frag.qsb`. Regenerate it after editing
the shader using `qsb` from Qt Shader Tools (no compiler needed at runtime):

```sh
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o shaders/monochrome.frag.qsb shaders/monochrome.frag
```

Validated with Qt 6.12 on Wayland/OpenGL using transparent render captures:
visible pixels match the chosen foreground within premultiplied 8-bit
rounding, and alpha retains luminance detail within the selected range.
