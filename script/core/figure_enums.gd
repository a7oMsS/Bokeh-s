extends RefCounted
class_name FigureEnums

## Figure body shape, mapped directly to the shader's "shape" uniform index.
enum Shape { CIRCLE, SQUARE, TRIANGLE, STAR5, STAR4, HEXAGON, RHOMBUS, HEART, RANDOM }

## Rendering style, mapped to a shader material in Figure.base_materials.
enum Style { SOLID, GRADIENT, OUTLINE, OUTLINE_GRADIENT, RANDOM }

## Coarse size bracket used to roll an actual pixel size.
enum SizeCategory { SMALL, MEDIUM, LARGE, RANDOM }

## Behavior script attached to a figure after it spawns.
enum PersonalityType { STATIC, BOUNCE, BLINK, VIBRATION, COLOR_SHIFT, RANDOM }

## Depth-of-field state a figure occupies or drifts towards.
enum Depth { MID, NEAR, FAR }
