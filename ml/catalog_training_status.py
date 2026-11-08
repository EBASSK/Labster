"""Informa la cobertura real de datos para ampliar el reconocimiento al catálogo.

Las referencias encontradas en internet no cuentan como imágenes aprobadas.
Este inventario no modifica etiquetas, pesos ni métricas del modelo instalado.
"""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    catalog = json.loads((ROOT / 'assets/catalog/instruments.json').read_text(encoding='utf-8'))
    active = (ROOT / 'assets/models/labels.txt').read_text(encoding='utf-8').splitlines()
    source = ROOT / 'ml/data_sources/commons_candidates.json'
    candidates = json.loads(source.read_text(encoding='utf-8-sig')) if source.exists() else []
    counts = Counter(item['proposedClass'] for item in candidates if item['reviewStatus'] == 'pending')
    rows = []
    for item in catalog:
        folder = ROOT / 'ml/data/instruments' / item['id']
        files = [p for p in folder.glob('*') if p.suffix.lower() in {'.jpg', '.jpeg', '.png', '.webp', '.avif'}]
        rows.append({
            'id': item['id'], 'name': item['name'],
            'in_installed_model': item['id'] in active,
            'local_image_files': len(files),
            'unreviewed_source_candidates': counts[item['id']],
        })
    report = {
        'catalog_classes': len(catalog), 'installed_classes': len(active),
        'missing_training_classes': [r['id'] for r in rows if not r['local_image_files']],
        'scope': 'Inventario de archivos, no evaluación de precisión ni validación de imágenes. Las referencias remotas requieren revisión de contenido, licencia y duplicados.',
        'classes': rows,
    }
    path = ROOT / 'ml/data_sources/catalog_training_status.json'
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"Catálogo: {len(catalog)} clases; modelo instalado: {len(active)}.")
    print(f"Clases sin fotografías de entrenamiento: {len(report['missing_training_classes'])}.")
    print(f'Referencias pendientes de revisión: {sum(counts.values())}.')
    return 1 if report['missing_training_classes'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
