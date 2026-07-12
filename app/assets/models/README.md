# Recall mood model

`recall_goemotions_v1.bin` is a compact, quantized emotion classifier trained
from the English GoEmotions dataset. It contains no note content and performs
all inference locally on the device.

The model uses 32,768 hashed unigram and bigram features with 28 one-vs-rest
logistic classifiers. Run `tools/train_mood_model.py` against the official
GoEmotions `data` directory to reproduce it.

GoEmotions was created by Google Research and is distributed under the
[Creative Commons Attribution 4.0 International license][cc-by]. The dataset
and its documentation are available from the [GoEmotions repository][source].
Recall's model is a modified, trained, and quantized derivative; it is not an
official Google model and Google does not endorse it.

[cc-by]: https://creativecommons.org/licenses/by/4.0/
[source]: https://github.com/google-research/google-research/tree/master/goemotions
