#!/usr/bin/env python3
"""Train Recall's compact emotion model from the GoEmotions TSV files.

The generated model contains quantized one-vs-rest logistic classifiers over
hashed word unigrams and bigrams. Runtime feature extraction is implemented in
pure Dart, which keeps inference offline and avoids a native ML dependency.
"""

from __future__ import annotations

import argparse
import math
import random
import re
import struct
from array import array
from pathlib import Path


BUCKETS = 32768
LABELS = 28
TOKEN_PATTERN = re.compile(r"[a-z]+(?:'[a-z]+)?|[0-9]+")


def fnv1a(text: str) -> int:
    value = 0x811C9DC5
    for byte in text.encode("utf-8"):
        value ^= byte
        value = (value * 0x01000193) & 0xFFFFFFFF
    return value


def features(text: str) -> set[int]:
    words = TOKEN_PATTERN.findall(text.lower())
    values = {fnv1a(f"u:{word}") % BUCKETS for word in words}
    values.update(
        fnv1a(f"b:{left}_{right}") % BUCKETS
        for left, right in zip(words, words[1:])
    )
    return values


def load_rows(path: Path):
    with path.open(encoding="utf-8") as source:
        for line in source:
            text, raw_labels, _ = line.rstrip("\n").split("\t")
            yield text, {int(value) for value in raw_labels.split(",")}


def _sigmoid(value: float) -> float:
    if value >= 0:
        return 1.0 / (1.0 + math.exp(-min(value, 30.0)))
    exponent = math.exp(max(value, -30.0))
    return exponent / (1.0 + exponent)


def train(path: Path):
    rows = [(features(text), labels) for text, labels in load_rows(path)]
    positive_docs = [sum(label in labels for _, labels in rows) for label in range(LABELS)]
    weights = [array("f", [0]) * BUCKETS for _ in range(LABELS)]
    biases = [math.log((count + 1) / (len(rows) - count + 1)) for count in positive_docs]
    positive_weights = [min(8.0, (len(rows) - count) / count) for count in positive_docs]
    randomizer = random.Random(22071996)

    for epoch in range(5):
        randomizer.shuffle(rows)
        learning_rate = 0.16 / (1.0 + epoch * 0.45)
        for row_features, labels in rows:
            feature_scale = 1.0 / math.sqrt(max(1, len(row_features)))
            for label in range(LABELS):
                label_weights = weights[label]
                score = biases[label] + feature_scale * sum(
                    label_weights[feature] for feature in row_features
                )
                target = 1.0 if label in labels else 0.0
                sample_weight = positive_weights[label] if target else 1.0
                gradient = (_sigmoid(score) - target) * sample_weight
                biases[label] -= learning_rate * gradient
                step = learning_rate * gradient * feature_scale
                for feature in row_features:
                    value = label_weights[feature]
                    label_weights[feature] = value - step - learning_rate * 1e-5 * value

    models = []
    for label in range(LABELS):
        label_weights = weights[label]
        scale = max(max(abs(value) for value in label_weights) / 127.0, 1e-9)
        quantized = bytes(
            (max(-127, min(127, round(value / scale))) & 0xFF)
            for value in label_weights
        )
        models.append((biases[label], scale, quantized))
    return models


def write_model(path: Path, models) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as output:
        output.write(b"RCLM")
        output.write(struct.pack("<HHI", 1, LABELS, BUCKETS))
        for prior, scale, weights in models:
            output.write(struct.pack("<ff", prior, scale))
            output.write(weights)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    write_model(args.output, train(args.data / "train.tsv"))


if __name__ == "__main__":
    main()
