"""Valida datos, entrena el modelo y publica sus artefactos para Flutter."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

from dataset import audit, validate

# Las rutas se resuelven desde este archivo para que el pipeline se pueda lanzar
# tanto desde la raíz del proyecto como desde la carpeta ``ml``.
ML_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ML_ROOT.parent
ARTIFACTS_DIR = ML_ROOT / 'artifacts'
RUNTIME_MODEL_DIR = PROJECT_ROOT / 'assets' / 'models'
REQUIRED_ARTIFACTS = ('instrument_model.tflite', 'labels.txt')


def validate_dataset(minimum_per_class: int = 10) -> None:
    """Detiene el pipeline si el dataset no cumple sus requisitos mínimos.

    Además de contar imágenes válidas, ejecuta la auditoría que detecta archivos
    ilegibles y copias exactas etiquetadas en clases distintas.
    """
    if not validate(minimum_per_class):
        raise RuntimeError('El dataset no cumple el mínimo por clase')

    report = audit()
    if report['invalid_images']:
        raise RuntimeError('El dataset contiene imágenes inválidas')
    if report['cross_class_exact_duplicate_groups']:
        raise RuntimeError('Hay imágenes idénticas etiquetadas en clases distintas')


def train() -> None:
    """Ejecuta el entrenamiento con el mismo intérprete de Python del pipeline."""
    subprocess.run(
        [sys.executable, str(ML_ROOT / 'train_model.py')],
        cwd=PROJECT_ROOT,
        check=True,
    )


def publish_runtime_artifacts() -> None:
    """Copia a Flutter el modelo TFLite y las etiquetas que consume la app.

    La operación verifica primero cada archivo obligatorio para no publicar una
    actualización incompleta que deje modelo y etiquetas desincronizados.
    """
    # La evidencia pertenece al binario exacto que se publica. Un entrenamiento
    # fallido nunca puede reutilizar silenciosamente métricas de otro modelo.
    metrics_path = ARTIFACTS_DIR / 'evaluation_metrics.json'
    if not metrics_path.is_file():
        raise RuntimeError('Faltan métricas verificadas; ejecuta el entrenamiento')
    metrics = json.loads(metrics_path.read_text(encoding='utf-8'))
    from preprocessing import PREPROCESSING
    if metrics.get('preprocessing') != PREPROCESSING:
        raise RuntimeError('El preprocesamiento no coincide con Flutter')
    for filename, key in [('instrument_model.tflite', 'model_sha256'), ('labels.txt', 'labels_sha256')]:
        source = ARTIFACTS_DIR / filename
        if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != metrics.get(key):
            raise RuntimeError(f'Artefacto ausente o no evaluado: {filename}')
    parity = metrics.get('conversion_validation', {})
    if parity.get('top1_agreement', 0) < 0.95 or parity.get('max_absolute_error', 1) > 0.03:
        raise RuntimeError('La conversión no supera la paridad requerida')
    RUNTIME_MODEL_DIR.mkdir(parents=True, exist_ok=True)
    # Primero valida todos los archivos; después actualiza el par modelo/etiquetas.
    for filename in REQUIRED_ARTIFACTS:
        shutil.copy2(ARTIFACTS_DIR / filename, RUNTIME_MODEL_DIR / filename)
        print(f'Publicado: {filename}')
    (RUNTIME_MODEL_DIR / 'model_contract.json').write_text(json.dumps({
        'preprocessing': PREPROCESSING,
        'input_shape': [1, 224, 224, 3], 'output_shape': [1, 10],
        'input_type': 'float32', 'output_type': 'float32',
        'output_semantics': 'softmax_uncalibrated',
        'model_sha256': metrics['model_sha256'],
        'labels_sha256': metrics['labels_sha256'],
        'generated_at': metrics['generated_at'],
    }, indent=2), encoding='utf-8')


def parse_args() -> argparse.Namespace:
    """Procesa los modos abreviados de validación o publicación sin entrenar."""
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        '--validate-only',
        action='store_true',
        help='Solo valida el dataset.',
    )
    mode.add_argument(
        '--copy-only',
        action='store_true',
        help='Solo copia artefactos ya entrenados a Flutter.',
    )
    return parser.parse_args()


def main() -> int:
    """Orquesta validación, entrenamiento y publicación en el orden seguro."""
    args = parse_args()
    if args.copy_only:
        # Este modo supone que los artefactos ya fueron entrenados y revisados.
        publish_runtime_artifacts()
        return 0

    # La calidad del dataset siempre se comprueba antes de invertir tiempo en
    # entrenar o generar archivos destinados a la aplicación.
    validate_dataset()
    if args.validate_only:
        return 0

    train()
    publish_runtime_artifacts()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
