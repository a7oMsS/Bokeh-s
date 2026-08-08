extends RefCounted
class_name VignetteEnums

## A diferencia de Bokeh (forma, estilo, tamaño, personalidad, color), los
## Vignette son deliberadamente sobrios: solo tres ejes, sin forma ni color
## propios. La variedad caótica vive en Bokeh; aquí la uniformidad es el punto.

## Cuánta densidad (vida) tiene un Vignette. Un valor más alto no cambia su
## apariencia, solo cuánto aguanta antes de dispersarse.
enum Hardness { SOFT, NORMAL, DENSE, RANDOM }

## Bracket grueso de tamaño visual, igual que FigureEnums.SizeCategory pero
## con una variación mucho más sutil entre categorías.
enum SizeCategory { SMALL, MEDIUM, LARGE, RANDOM }

## Comportamiento de movimiento. SEEKER existe en el enum para no tener que
## tocar esta arquitectura después, pero no se activa todavía — no estaría
## desbloqueado dentro de la ventana del demo (10-15 min).
enum PersonalityType { STATIC, DRIFTING, SEEKER, RANDOM }
