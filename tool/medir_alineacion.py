"""Mide el desfase entre la voz grabada en el celular y el instrumental
(Pb-13, Sp-16 y Sp-19).

La grabación de la prueba integration_test/alineacion_test.dart contiene el
instrumental captado por el micrófono. La correlación cruzada con el
instrumental original indica cuántos milisegundos quedó corrido: si la
grabación está alineada, el desfase es cercano a 0 (meta: 100 ms o menos).
Requiere FFmpeg y numpy. Uso:
    python tool/medir_alineacion.py <voz.wav> <instrumental.m4a>
"""

import subprocess
import sys

import numpy as np

MUESTRAS_POR_SEGUNDO = 8000
META_MS = 100


def pcm(ruta, segundos=None):
    """Audio en mono a 8 kHz, decodificado con FFmpeg."""
    comando = [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-i",
        ruta,
        "-ac",
        "1",
        "-ar",
        str(MUESTRAS_POR_SEGUNDO),
    ]
    if segundos:
        comando += ["-t", str(segundos)]
    salida = subprocess.run(
        comando + ["-f", "f32le", "-"], capture_output=True, check=True
    ).stdout
    return np.frombuffer(salida, dtype=np.float32)


def desfase_ms(grabado, original):
    """Milisegundos que el instrumental aparece corrido en la grabación."""
    n = 1 << int(np.ceil(np.log2(len(grabado) + len(original))))
    correlacion = np.fft.irfft(
        np.fft.rfft(grabado, n) * np.conj(np.fft.rfft(original, n)), n
    )
    retraso = int(np.argmax(correlacion))
    if retraso > n // 2:
        retraso -= n
    return retraso * 1000 / MUESTRAS_POR_SEGUNDO


def main(voz, instrumental):
    grabado = pcm(voz)
    original = pcm(instrumental, len(grabado) / MUESTRAS_POR_SEGUNDO + 2)
    ms = desfase_ms(grabado, original)
    print(
        f"grabacion de {len(grabado) / MUESTRAS_POR_SEGUNDO:.1f} s: "
        f"desfase {ms:+.0f} ms (meta {META_MS} ms)"
    )
    return abs(ms) <= META_MS


if __name__ == "__main__":
    sys.exit(0 if main(sys.argv[1], sys.argv[2]) else 1)
