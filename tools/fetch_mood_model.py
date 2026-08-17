#!/usr/bin/env python3
"""Fetch Recall's pinned mood model artifacts and verify their hashes."""

from __future__ import annotations

import argparse
import hashlib
import urllib.request
from pathlib import Path


REVISION = "4fea72b9ec71ba8d84b88e0efa2ace3dcc733bfc"
BASE_URL = (
    "https://huggingface.co/minuva/MiniLMv2-goemotions-v2-onnx/resolve/"
    f"{REVISION}"
)
ARTIFACTS = {
    "model_optimized_quantized.onnx": (
        "recall_goemotions_v2.onnx",
        "594ac3bf3c82e2ea187e50982ea2f811ede5377eaad0c8ad23bc04ee8a2486c6",
    ),
    "tokenizer.json": (
        "recall_roberta_tokenizer_v2.json",
        "b374924beb422033e02af444719785d778d2511bc7aaa4e9741cb9d580d6567e",
    ),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download(source_name: str, destination: Path, expected_hash: str) -> None:
    if destination.exists() and sha256(destination) == expected_hash:
        print(f"verified {destination}")
        return

    temporary = destination.with_suffix(destination.suffix + ".download")
    request = urllib.request.Request(
        f"{BASE_URL}/{source_name}?download=true",
        headers={"User-Agent": "Recall mood model fetcher"},
    )
    try:
        with urllib.request.urlopen(request) as response, temporary.open("wb") as output:
            while block := response.read(1024 * 1024):
                output.write(block)
        actual_hash = sha256(temporary)
        if actual_hash != expected_hash:
            raise RuntimeError(
                f"hash mismatch for {source_name}: {actual_hash} != {expected_hash}"
            )
        temporary.replace(destination)
        print(f"downloaded {destination}")
    finally:
        temporary.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("app/assets/models"),
        help="destination asset directory",
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for source_name, (destination_name, expected_hash) in ARTIFACTS.items():
        download(source_name, args.output / destination_name, expected_hash)


if __name__ == "__main__":
    main()
