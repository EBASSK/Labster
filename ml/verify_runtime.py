"""Comprueba el modelo publicado con tensores creados por Dart, sin cámara."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from preprocessing import preprocess_image, PREPROCESSING
from train_model import predict_tflite, score_predictions

ROOT = Path(__file__).resolve().parents[1]

def main():
    directory = ROOT / 'build/dart_tensors'
    records = json.loads((directory / 'manifest.json').read_text())
    runtime = ROOT / 'assets/models'
    contract = json.loads((runtime / 'model_contract.json').read_text())
    assert contract['preprocessing'] == PREPROCESSING
    assert hashlib.sha256((runtime / 'instrument_model.tflite').read_bytes()).hexdigest() == contract['model_sha256']
    assert hashlib.sha256((runtime / 'labels.txt').read_bytes()).hexdigest() == contract['labels_sha256']
    labels = (runtime / 'labels.txt').read_text().splitlines()
    dart, python, truth = [], [], []
    for item in records:
        dart.append(np.fromfile(directory / item['tensor_file'], dtype='<f4').reshape(224, 224, 3))
        with Image.open(ROOT / 'ml' / item['path']) as image:
            python.append(preprocess_image(image))
        truth.append(labels.index(item['class']))
    dart, python, truth = np.asarray(dart), np.asarray(python), np.asarray(truth)
    ds = predict_tflite(runtime / 'instrument_model.tflite', dart, len(labels))
    ps = predict_tflite(runtime / 'instrument_model.tflite', python, len(labels))
    metrics = score_predictions(ds, truth, labels)
    for row, item in zip(metrics['samples'], records):
        row['path'] = item['path']
    result = {
        'model_sha256': contract['model_sha256'],
        'samples': len(records),
        'tensor_mean_absolute_error': float(np.mean(np.abs(dart-python))),
        'tensor_max_absolute_error': float(np.max(np.abs(dart-python))),
        'score_max_absolute_error': float(np.max(np.abs(ds-ps))),
        'top1_agreement': float(np.mean(ds.argmax(1) == ps.argmax(1))),
        'dart_tflite': metrics,
        'scope': 'Tensores reales de Dart e intérprete TFLite Python; no valida cámara ni runtime Android. Excluye AVIF no admitido por image.',
    }
    destination = ROOT / 'ml/artifacts/runtime_verification.json'
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({key: value for key, value in result.items() if key != 'dart_tflite'}, indent=2))
    if result['top1_agreement'] < 0.95:
        raise RuntimeError('La decodificación móvil cambia demasiadas predicciones')

if __name__ == '__main__':
    main()
