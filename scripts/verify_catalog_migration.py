"""Ejecuta en SQLite real el SQL de migración extraído del servicio Dart.

Comprueba conservación de datos; no sustituye una instalación Android real.
"""
import re
import sqlite3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'lib/services/database_service.dart').read_text(encoding='utf-8')
tables = re.findall(r"await db\s*\.execute\(\s*'''(.*?)'''\)", source, re.S)
section = source.split('Future<void> _addCatalogColumns')[1].split('Future<void> installCatalog')[0]
statements = re.findall(r"await db\s*\.execute\(\s*'([^']+)'\)", section)
assert len(tables) == 2 and len(statements) == 3
with sqlite3.connect(':memory:') as db:
    for sql in tables:
        db.execute(sql)
    db.execute("INSERT INTO scan_history (id,image_path,predicted_instrument,confidence,is_favorite,user_notes) VALUES ('old','photo.jpg','Pipeta',0.9,1,'Conservar')")
    db.execute("INSERT INTO instruments (id,name,description) VALUES (7,'Instrumento previo','Texto original')")
    old_scan = db.execute('SELECT * FROM scan_history').fetchall()
    for sql in statements:
        db.execute(sql)
    assert db.execute('SELECT * FROM scan_history').fetchall() == old_scan
    assert db.execute('SELECT id,name,description,catalog_key,educational_json FROM instruments').fetchone() == (7,'Instrumento previo','Texto original',None,None)
    db.execute("INSERT INTO instruments (name,catalog_key) VALUES ('Nuevo','stable-id')")
    try:
        db.execute("INSERT INTO instruments (name,catalog_key) VALUES ('Duplicado','stable-id')")
    except sqlite3.IntegrityError:
        pass
    else:
        raise AssertionError('La clave educativa permite duplicados')
print('OK: migracion SQLite conserva historial, favorito, notas y catalogo previo; claves unicas.')
