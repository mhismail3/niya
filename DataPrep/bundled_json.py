"""Read app-bundled JSON that compress_json.py stores as <name>.json.zlib.

Scripts that consume Niya/Resources/Data/<name>.json read through here so they work
whether the plain file (freshly built) or only the compressed one exists.
"""
import json
import os
import zlib


def load(path):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    zpath = path + ".zlib"
    if os.path.exists(zpath):
        with open(zpath, "rb") as f:
            return json.loads(zlib.decompress(f.read()))
    raise FileNotFoundError(f"neither {path} nor {zpath} exists")


def exists(path):
    return os.path.exists(path) or os.path.exists(path + ".zlib")
