🔦 The Last Light
The Last Light es un videojuego de supervivencia y exploración desarrollado para la consola de fantasía PICO-8. El jugador controla a un minero atrapado en una cueva interminable donde la gestión de la luz es la única diferencia entre la vida y la muerte.

🕹️ Mecánicas de Juego
Gestión de Combustible: La linterna consume energía constantemente. Debes recolectar Carbón para evitar quedar a oscuras.

Recolección de Recursos: Explora la penumbra en busca de Oro y Zafiros para aumentar tu puntuación y cumplir los objetivos.

La Chispa: Una mecánica de emergencia que permite iluminar brevemente los alrededores para planificar el movimiento.

Muerte Permanente: Si el combustible se agota totalmente, la oscuridad consume al minero y la partida termina.

🛠️ Requerimientos Técnicos Implementados

1. Penumbra con Técnicas de Dithering
   Se utiliza la manipulación del registro fillp() de PICO-8 para crear un efecto de transparencia técnica:

Patrones de Puntos: El juego aplica patrones de entrelazado (tablero de ajedrez) para mezclar el color de la luz con el negro del fondo.

Transiciones Atmosféricas: Esto permite una transición visual fluida que simula cómo la luz se desvanece en la distancia.

2. Modo de Juego Procedural
   El entorno se construye de forma dinámica en cada partida:

Generación Aleatoria de Niveles: La posición de los recursos se calcula mediante algoritmos de probabilidad, asegurando que el mapa sea distinto en cada intento.

Mutación de Identidad: Al recolectar un ítem, el sistema no solo lo reubica, sino que puede transformar su tipo (de carbón a zafiro, por ejemplo), alterando la economía del nivel en tiempo real.

Siembra Dinámica: Los recursos se generan "bajo demanda" al iniciar la escena de juego, evitando estructuras estáticas.

🚀 Instalación y Ejecución
Copia el código fuente en un archivo con extensión .p8.

Abre PICO-8.

Carga el archivo con el comando load nombre_del_archivo.p8.

Escribe run y presiona Enter para comenzar la exploración.

⌨️ Controles
Flechas: Movimiento del minero.

Z: Iniciar el juego / Activar la Chispa (según la escena).

Desarrollado como proyecto de exploración técnica en Lua para PICO-8.
