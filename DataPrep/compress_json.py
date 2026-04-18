#!/usr/bin/env python3
"""Compress all bundled JSON files to .json.zlib for reduced app bundle size."""

import os
import zlib
import sys

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "Niya", "Resources", "Data")

def compress_file(json_path):
    """Compress a .json file to .json.zlib and remove the original."""
    zlib_path = json_path + ".zlib"
    with open(json_path, "rb") as f:
        raw = f.read()
    compressed = zlib.compress(raw, level=9)
    with open(zlib_path, "wb") as f:
        f.write(compressed)
    ratio = len(compressed) / len(raw) * 100 if raw else 0
    os.remove(json_path)
    return len(raw), len(compressed), ratio

def main():
    if not os.path.isdir(DATA_DIR):
        print(f"Error: Data directory not found: {DATA_DIR}", file=sys.stderr)
        sys.exit(1)

    total_raw = 0
    total_compressed = 0
    count = 0

    for dirpath, _, filenames in os.walk(DATA_DIR):
        for filename in sorted(filenames):
            if not filename.endswith(".json"):
                continue
            json_path = os.path.join(dirpath, filename)
            rel = os.path.relpath(json_path, DATA_DIR)
            raw_size, comp_size, ratio = compress_file(json_path)
            total_raw += raw_size
            total_compressed += comp_size
            count += 1
            print(f"  {rel}: {raw_size/1024/1024:.1f}MB -> {comp_size/1024/1024:.1f}MB ({ratio:.0f}%)")

    print(f"\nCompressed {count} files")
    print(f"Total: {total_raw/1024/1024:.1f}MB -> {total_compressed/1024/1024:.1f}MB "
          f"({total_compressed/total_raw*100:.0f}%)")
    print(f"Savings: {(total_raw - total_compressed)/1024/1024:.1f}MB")

if __name__ == "__main__":
    main()
