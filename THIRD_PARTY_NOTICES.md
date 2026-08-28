# Third-party notices

## Recall compact GoEmotions model

Recall includes a compact classifier trained from the Google Research
GoEmotions dataset. GoEmotions is Copyright 2020 Google LLC and licensed under
the Creative Commons Attribution 4.0 International License. A copy is included
at `app/assets/licenses/CC-BY-4.0.txt`.

## MiniLMv2 GoEmotions ONNX model

Recall includes the quantized model and tokenizer from
[`minuva/MiniLMv2-goemotions-v2-onnx`][model], identified by immutable revision
`4fea72b9ec71ba8d84b88e0efa2ace3dcc733bfc`. The model card declares the
artifacts under the Apache License 2.0.
A copy is included at `app/assets/licenses/Apache-2.0.txt`.

The model is trained on [GoEmotions][goemotions], Copyright 2020 Google LLC.
GoEmotions is licensed under the [Creative Commons Attribution 4.0
International License][cc-by]. A copy is included at
`app/assets/licenses/CC-BY-4.0.txt`.

## ONNX Runtime

Android inference uses [Microsoft ONNX Runtime][onnx-runtime], licensed under
the MIT License. A copy is included at
`app/assets/licenses/ONNX-Runtime-MIT.txt`.

[model]: https://huggingface.co/minuva/MiniLMv2-goemotions-v2-onnx
[goemotions]: https://github.com/google-research/google-research/tree/master/goemotions
[cc-by]: https://creativecommons.org/licenses/by/4.0/
[onnx-runtime]: https://github.com/microsoft/onnxruntime
