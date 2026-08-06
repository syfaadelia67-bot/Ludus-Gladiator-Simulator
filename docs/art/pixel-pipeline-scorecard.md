# Planilla de resultados del pipeline Pixel 64

Esta planilla acompaña a `pixel-pipeline-evaluation.md`. Debe completarse únicamente con mediciones observadas durante la prueba local. Los campos sin evidencia permanecen como `Pendiente`.

## Entorno de prueba

| Dato | Valor |
| --- | --- |
| Fecha y hora | Pendiente |
| Sistema operativo | Pendiente |
| CPU | Pendiente |
| GPU | Pendiente |
| RAM | Pendiente |
| Godot | 4.5.2 |
| Resolución del editor | Pendiente |
| Commit evaluado | Pendiente |
| Operador | Pendiente |

## Versiones y procedencia

| Pipeline | Versión exacta | Fuente | Licencia verificada | Instalación local aislada |
| --- | --- | --- | --- | --- |
| Gator Sprite Studio | Pendiente | Pendiente | Pendiente | Pendiente |
| Pixel-Prof | Pendiente | Pendiente | Pendiente | Pendiente |
| Pixelorama + Importality | Pendiente | Pendiente | Pendiente | Pendiente |

## Cronometraje

Usar un cronómetro continuo por tarea. Pausar solamente por interrupciones externas y registrar cada pausa. No sumar tiempos estimados.

| Tarea | Gator | Pixel-Prof | Pixelorama + Importality |
| --- | ---: | ---: | ---: |
| Instalación y configuración | Pendiente | Pendiente | Pendiente |
| Cuerpo adulto base | Pendiente | Pendiente | Pendiente |
| `idle`, 4 cuadros | Pendiente | Pendiente | Pendiente |
| `attack`, 5 cuadros | Pendiente | Pendiente | Pendiente |
| Variante de casco | Pendiente | Pendiente | Pendiente |
| Corrección de un cuadro exportado | Pendiente | Pendiente | Pendiente |
| Reexportación visible en Godot | Pendiente | Pendiente | Pendiente |
| **Tiempo total medido** | Pendiente | Pendiente | Pendiente |

## Integridad del documento fuente

| Prueba | Gator | Pixel-Prof | Pixelorama + Importality |
| --- | --- | --- | --- |
| Siete capas conservadas | Pendiente | Pendiente | Pendiente |
| Orden de capas conservado | Pendiente | Pendiente | Pendiente |
| Nombres de animaciones conservados | Pendiente | Pendiente | Pendiente |
| Duraciones por cuadro conservadas | Pendiente | Pendiente | Pendiente |
| Paleta conservada | Pendiente | Pendiente | Pendiente |
| 20 undo sin corrupción | Pendiente | Pendiente | Pendiente |
| 20 redo sin corrupción | Pendiente | Pendiente | Pendiente |
| Cierre y reapertura fiables | Pendiente | Pendiente | Pendiente |
| Dos exportaciones idénticas sin cambios | Pendiente | Pendiente | Pendiente |

Para verificar exportaciones deterministas, registrar SHA-256 de cada archivo:

| Archivo | Exportación 1 | Exportación 2 | Coinciden |
| --- | --- | --- | --- |
| Gator | Pendiente | Pendiente | Pendiente |
| Pixel-Prof | Pendiente | Pendiente | Pendiente |
| Pixelorama + Importality | Pendiente | Pendiente | Pendiente |

## Contrato técnico 64 × 64

| Comprobación | Gator | Pixel-Prof | Pixelorama + Importality |
| --- | --- | --- | --- |
| Lienzo exacto 64 × 64 | Pendiente | Pendiente | Pendiente |
| Altura visible 57–61 px | Pendiente | Pendiente | Pendiente |
| Pivote de pies estable | Pendiente | Pendiente | Pendiente |
| Equipo conserva alineación | Pendiente | Pendiente | Pendiente |
| Escala ×2 nítida | Pendiente | Pendiente | Pendiente |
| Escala ×4 nítida | Pendiente | Pendiente | Pendiente |
| Escala ×6 nítida | Pendiente | Pendiente | Pendiente |
| Fondo claro legible | Pendiente | Pendiente | Pendiente |
| Fondo oscuro legible | Pendiente | Pendiente | Pendiente |

## Revisión de proporciones adultas

Evaluar cada resultado a escala nativa y ampliada. Una respuesta negativa exige corrección y repetición antes de puntuar la herramienta.

| Criterio | Gator | Pixel-Prof | Pixelorama + Importality |
| --- | --- | --- | --- |
| Cabeza claramente menor que un diseño chibi | Pendiente | Pendiente | Pendiente |
| Piernas visualmente largas | Pendiente | Pendiente | Pendiente |
| Hombros y torso de adulto | Pendiente | Pendiente | Pendiente |
| Silueta de gladiador reconocible | Pendiente | Pendiente | Pendiente |
| Armas y escudos legibles | Pendiente | Pendiente | Pendiente |
| Ninguna pose parece infantil | Pendiente | Pendiente | Pendiente |

## Integración con Godot

| Prueba | Gator | Pixel-Prof | Pixelorama + Importality |
| --- | --- | --- | --- |
| Importación sin errores | Pendiente | Pendiente | Pendiente |
| Reimportación automática | Pendiente | Pendiente | Pendiente |
| `SpriteFrames` reproducible | Pendiente | Pendiente | Pendiente |
| Cinco animaciones reproducibles | Pendiente | Pendiente | Pendiente |
| Cambio de casco durante animación | Pendiente | Pendiente | Pendiente |
| Cambio de arma durante animación | Pendiente | Pendiente | Pendiente |
| Cambio de escudo durante animación | Pendiente | Pendiente | Pendiente |
| Proyecto arranca sin la herramienta | Pendiente | Pendiente | Pendiente |

## Incidencias

Registrar una fila por incidencia, incluso cuando haya solución.

| ID | Pipeline | Severidad | Acción que la provoca | Resultado observado | Solución o estado |
| --- | --- | --- | --- | --- | --- |
| PP-001 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |

Severidades permitidas:

- `Bloqueante`: pérdida de datos, corrupción, imposibilidad de exportar o dependencia de runtime.
- `Alta`: rompe pivotes, capas, tags o una animación completa.
- `Media`: requiere corrección manual repetitiva o un reinicio.
- `Baja`: inconveniente visual o de flujo sin pérdida de información.

## Puntuación respaldada por evidencia

La puntuación no sustituye los umbrales de descarte. Una herramienta con una condición bloqueante queda descartada aunque su total sea alto.

| Categoría | Peso | Gator | Pixel-Prof | Pixelorama + Importality |
| --- | ---: | ---: | ---: | ---: |
| Integridad y estabilidad | 30 | Pendiente | Pendiente | Pendiente |
| Integración reproducible con Godot | 25 | Pendiente | Pendiente | Pendiente |
| Productividad medida | 20 | Pendiente | Pendiente | Pendiente |
| Calidad del resultado adulto | 15 | Pendiente | Pendiente | Pendiente |
| Licencia y riesgo de dependencia | 10 | Pendiente | Pendiente | Pendiente |
| **Total sobre 100** | **100** | Pendiente | Pendiente | Pendiente |

Cada categoría se califica de 0 a 10 y se multiplica por su peso. Toda calificación debe enlazar una medición, captura o incidencia de esta misma prueba.

## Decisión

- Ganador: Pendiente.
- Segunda opción: Pendiente.
- Herramientas descartadas: Pendiente.
- Motivo principal: Pendiente.
- Condiciones para adopción: Pendiente.
- Recomendación sobre fusionar Pixel 64 a `main`: Pendiente.

## Evidencias versionables

Solo se aceptan:

- PNG y spritesheets creados para Ludus;
- recursos `.tres` o `.res` propios;
- escena comparativa independiente de plugins;
- hashes y resultados de comandos;
- capturas que no revelen claves, rutas privadas ni material propietario.

No se aceptan plugins, cachés, ejecutables, licencias propietarias redistribuidas ni configuración local del editor.
