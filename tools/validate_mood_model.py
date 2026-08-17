#!/usr/bin/env python3
"""Run behavioral checks against Recall's bundled contextual mood model.

Requires numpy, onnxruntime, and tokenizers. These are validation-only tools;
they are not application dependencies.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import onnxruntime as ort
from tokenizers import Tokenizer


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app" / "assets" / "models"
MODEL = ASSETS / "recall_goemotions_v2.onnx"
TOKENIZER = ASSETS / "recall_roberta_tokenizer_v2.json"
LABELS = [
    "admiration",
    "amusement",
    "anger",
    "annoyance",
    "approval",
    "caring",
    "confusion",
    "curiosity",
    "desire",
    "disappointment",
    "disapproval",
    "disgust",
    "embarrassment",
    "excitement",
    "fear",
    "gratitude",
    "grief",
    "joy",
    "love",
    "nervousness",
    "optimism",
    "pride",
    "realization",
    "relief",
    "remorse",
    "sadness",
    "surprise",
    "neutral",
]
MOODS = {
    "admiration": "warm",
    "amusement": "joyful",
    "anger": "intense",
    "annoyance": "intense",
    "approval": "calm",
    "caring": "warm",
    "confusion": "tense",
    "curiosity": "surprised",
    "desire": "joyful",
    "disappointment": "reflective",
    "disapproval": "intense",
    "disgust": "intense",
    "embarrassment": "reflective",
    "excitement": "joyful",
    "fear": "tense",
    "gratitude": "warm",
    "grief": "reflective",
    "joy": "joyful",
    "love": "warm",
    "nervousness": "tense",
    "optimism": "joyful",
    "pride": "joyful",
    "realization": "surprised",
    "relief": "calm",
    "remorse": "reflective",
    "sadness": "reflective",
    "surprise": "surprised",
    "neutral": "clear",
}
CASES = {
    "bad": "clear",
    "a bad thing happened today": "reflective",
    "This is bad": "intense",
    "This is good": "warm",
    "I feel happy today": "joyful",
    "I feel sad today": "reflective",
    "I love my family": "warm",
    "I am nervous about tomorrow": "tense",
    "What a surprise": "surprised",
    "I bought milk and bread": "clear",
    "The meeting moved from two to three": "clear",
}


def mood_for(logits: np.ndarray) -> tuple[str, float]:
    grouped: dict[str, float] = {}
    for label, score in zip(LABELS, logits, strict=True):
        mood = MOODS[label]
        grouped[mood] = max(grouped.get(mood, -math.inf), float(score))
    ranked = sorted(grouped.items(), key=lambda item: item[1], reverse=True)
    winner, winner_logit = ranked[0]
    confidence = 1.0 / (1.0 + math.exp(-winner_logit))
    if winner == "clear" or confidence < 0.64 or winner_logit - ranked[1][1] < 0.35:
        return "clear", confidence
    return winner, confidence


def main() -> None:
    tokenizer = Tokenizer.from_str(TOKENIZER.read_text(encoding="utf-8"))
    session = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])
    failures = []
    for text, expected in CASES.items():
        encoding = tokenizer.encode(text)
        ids = np.array([encoding.ids], dtype=np.int64)
        mask = np.array([encoding.attention_mask], dtype=np.int64)
        logits = session.run(
            None,
            {"input_ids": ids, "attention_mask": mask},
        )[0][0]
        actual, confidence = mood_for(logits)
        print(f"{actual:10} {confidence:.3f}  {text}")
        if actual != expected:
            failures.append(f"{text!r}: expected {expected}, got {actual}")
    if failures:
        raise SystemExit("\n".join(failures))


if __name__ == "__main__":
    main()
