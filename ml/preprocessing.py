"""Contrato RGB compartido con ModelImagePreprocessor de Flutter."""
import numpy as np
from PIL import Image, ImageOps

PREPROCESSING = 'rgb8-bilinear-half-pixel-224-unit-v1'

def preprocess_image(image, size=224):
    """Orienta, convierte a RGB8 y muestrea centros de píxel sin recorte.

    Replica la interpolación explícita de Dart, incluidos bordes y división por
    255. La interpolación conserva fracciones en lugar de redondearlas a bytes.
    """
    pixels = np.asarray(ImageOps.exif_transpose(image).convert('RGB'), dtype=np.float64)
    height, width = pixels.shape[:2]
    xs = np.clip((np.arange(size) + 0.5) * width / size - 0.5, 0, width - 1)
    ys = np.clip((np.arange(size) + 0.5) * height / size - 0.5, 0, height - 1)
    x0, y0 = xs.astype(int), ys.astype(int)
    x1, y1 = np.minimum(x0 + 1, width - 1), np.minimum(y0 + 1, height - 1)
    wx, wy = (xs - x0)[None, :, None], (ys - y0)[:, None, None]
    top = pixels[y0[:, None], x0] * (1 - wx) + pixels[y0[:, None], x1] * wx
    bottom = pixels[y1[:, None], x0] * (1 - wx) + pixels[y1[:, None], x1] * wx
    return ((top * (1 - wy) + bottom * wy) / 255.0).astype(np.float32)
