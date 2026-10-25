"""Regresiones de preprocesamiento y bloqueo de publicación incompleta."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
from PIL import Image
from preprocessing import preprocess_image
import run_pipeline

class PipelineTests(unittest.TestCase):
    def test_rectangular_rgb_matches_dart(self):
        pixels = np.array([[[255, 0, 0], [0, 0, 255]]], dtype=np.uint8)
        result = preprocess_image(Image.fromarray(pixels))
        self.assertEqual(result.shape, (224, 224, 3))
        np.testing.assert_allclose(result[100, 111], [0.5044642857142857, 0, 0.4955357142857143], atol=1e-7)
        np.testing.assert_array_equal(result[0, 0], [1, 0, 0])
        np.testing.assert_array_equal(result[-1, -1], [0, 0, 1])

    def test_missing_metrics_preserves_runtime(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            runtime = root / 'runtime'
            runtime.mkdir()
            (runtime / 'instrument_model.tflite').write_bytes(b'original')
            with patch.object(run_pipeline, 'ARTIFACTS_DIR', root), patch.object(run_pipeline, 'RUNTIME_MODEL_DIR', runtime):
                with self.assertRaises(RuntimeError):
                    run_pipeline.publish_runtime_artifacts()
            self.assertEqual((runtime / 'instrument_model.tflite').read_bytes(), b'original')

    def test_stale_metrics_preserves_runtime(self):
        from preprocessing import PREPROCESSING
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'evaluation_metrics.json').write_text(json.dumps({'preprocessing': PREPROCESSING, 'model_sha256': 'incorrecto'}))
            (root / 'instrument_model.tflite').write_bytes(b'cambiado')
            with patch.object(run_pipeline, 'ARTIFACTS_DIR', root):
                with self.assertRaises(RuntimeError):
                    run_pipeline.publish_runtime_artifacts()

if __name__ == '__main__':
    unittest.main()
