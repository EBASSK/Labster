# Estado del dataset

Auditoría generada el 28 de julio de 2026 sobre
`ml/data/instruments`.

## Resumen

- 133 imágenes válidas distribuidas en 10 clases.
- 0 imágenes corruptas.
- 0 grupos de duplicados exactos.
- 0 imágenes idénticas etiquetadas en clases diferentes.
- 44 imágenes tienen al menos un lado menor de 224 píxeles.
- 14 pares son visualmente muy similares según dHash; 9 cruzan clases.
- Split reproducible: 79 entrenamiento, 27 validación y 27 prueba.

Los pares similares entre clases no se eliminan automáticamente. Muchos
instrumentos son transparentes, alargados o fotografiados sobre fondo blanco,
por lo que requieren revisión visual humana.

## Riesgos actuales

Cada clase tiene entre 11 y 16 imágenes. Esto alcanza para validar el
pipeline, pero no para afirmar robustez ante cámaras, fondos e iluminación
reales. La precisión histórica de 95,45 % se calculó con solo 22 imágenes del
dataset anterior y no debe considerarse una métrica de producción.

## Próxima recolección

1. Tomar fotografías nuevas con varios teléfonos.
2. Variar fondo, iluminación, orientación, distancia y presencia de manos.
3. Mantener un conjunto externo que nunca entre en entrenamiento.
4. Revisar primero los 9 pares similares entre clases incluidos en
   `ml/artifacts/dataset_audit.json`.
5. Reentrenar con el entorno fijado en `requirements.txt` y revisar
   `evaluation_metrics.json` y `confusion_matrix.png`.

El modelo no se reemplazó durante aquella auditoría de julio. Fue reentrenado
y publicado posteriormente; véase `../docs/ENTRENAMIENTO_VERIFICADO.md`.
