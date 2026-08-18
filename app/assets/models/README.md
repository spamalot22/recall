# Recall mood model

Recall bundles a quantized MiniLMv2 transformer that performs contextual
emotion classification entirely on the Android device. Note text is tokenized
in Dart, and only token IDs cross the private Flutter-to-Android method channel.
No note content or inference result is sent over the network.

Production builds currently keep this native classifier disabled while its
runtime is validated across supported physical devices. Functional automatic
colours and manual colour selection remain available. Development builds can
opt in with `--dart-define=ENABLE_CONTEXTUAL_MOODS=true`.

## Artifacts

- `recall_goemotions_v2.onnx`: quantized six-layer MiniLMv2 model, 28
  GoEmotions labels, SHA-256
  `594ac3bf3c82e2ea187e50982ea2f811ede5377eaad0c8ad23bc04ee8a2486c6`.
- `recall_roberta_tokenizer_v2.json`: matching byte-level BPE tokenizer,
  SHA-256
  `b374924beb422033e02af444719785d778d2511bc7aaa4e9741cb9d580d6567e`.

The artifacts come from
[`minuva/MiniLMv2-goemotions-v2-onnx`][model] at immutable revision
`4fea72b9ec71ba8d84b88e0efa2ace3dcc733bfc`. Its model card reports a test F1
of 0.482 and Apache-2.0 licensing. Run `tools/fetch_mood_model.py` to retrieve
and verify the exact artifacts, and `tools/validate_mood_model.py` to run
Recall's behavioral checks.

The model was fine-tuned on the English [GoEmotions][goemotions] dataset.
GoEmotions was created by Google Research and is distributed under [CC BY
4.0][cc-by]. The model is a third-party derivative, is not an official Google
model, and should not be treated as a general assessment of a person's
emotional state. Recall only uses its result to choose an optional note colour.

[model]: https://huggingface.co/minuva/MiniLMv2-goemotions-v2-onnx
[goemotions]: https://github.com/google-research/google-research/tree/master/goemotions
[cc-by]: https://creativecommons.org/licenses/by/4.0/
