Directory Structure:

└── ./
    ├── scripts
    │   ├── benchmark.py
    │   └── redact.py
    ├── tests
    │   ├── __init__.py
    │   ├── test_encoding.py
    │   ├── test_helpers.py
    │   ├── test_misc.py
    │   ├── test_offsets.py
    │   ├── test_pickle.py
    │   └── test_simple_public.py
    ├── tiktoken
    │   ├── __init__.py
    │   ├── _educational.py
    │   ├── core.py
    │   ├── load.py
    │   ├── model.py
    │   └── registry.py
    ├── tiktoken_ext
    │   └── openai_public.py
    └── setup.py



---
File: /scripts/benchmark.py
---

import base64
import functools
import gzip
import json
import os
import random
import time
from typing import Any, cast

import blobfile

import tiktoken


def benchmark_batch(documents: list[str]) -> None:
    num_threads = int(os.environ["RAYON_NUM_THREADS"])
    num_bytes = sum(map(len, map(str.encode, documents)))
    print(f"num_threads: {num_threads}, num_bytes: {num_bytes}")

    enc = tiktoken.get_encoding("gpt2")
    enc.encode("warmup")

    start = time.perf_counter_ns()
    enc.encode_ordinary_batch(documents, num_threads=num_threads)
    end = time.perf_counter_ns()
    print(f"tiktoken \t{num_bytes / (end - start) * 1e9} bytes / s")

    import transformers

    hf_enc = cast(Any, transformers).GPT2TokenizerFast.from_pretrained("gpt2")
    hf_enc.model_max_length = 1e30  # silence!
    hf_enc.encode("warmup")

    start = time.perf_counter_ns()
    hf_enc(documents)
    end = time.perf_counter_ns()
    print(f"huggingface \t{num_bytes / (end - start) * 1e9} bytes / s")





---
File: /scripts/redact.py
---

import argparse
import re
import subprocess
from pathlib import Path


def redact_file(path: Path, dry_run: bool) -> None:
    if not path.exists() or path.is_dir():
        return

    text = path.read_text()
    if not text:
        return

    first_line = text.splitlines()[0]
    if "redact" in first_line:
        if not dry_run:
            path.unlink()
        print(f"Deleted {path}")
        return

    pattern = "|".join(
        r" *" + re.escape(x)
        for x in [
            "# ===== redact-beg =====\n",
            "# ===== redact-end =====\n",
            "<!--- redact-beg -->\n",
            "<!--- redact-end -->\n",
        ]
    )

    if re.search(pattern, text):
        redacted_text = "".join(re.split(pattern, text)[::2])
        if not dry_run:
            path.write_text(redacted_text)
        print(f"Redacted {path}")
        return

    print(f"Skipped {path}")


def redact(dry_run: bool) -> None:
    tiktoken_root = Path(__file__).parent.parent
    assert tiktoken_root.name == "tiktoken"
    assert (tiktoken_root / "pyproject.toml").exists()

    try:
        output = subprocess.check_output(["git", "ls-files"], cwd=tiktoken_root, text=True)
        paths = [Path(p) for p in output.splitlines()]
    except subprocess.CalledProcessError:
        paths = list(tiktoken_root.glob("**/*"))

    for path in paths:
        redact_file(path, dry_run=dry_run)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", type=lambda x: not x or x[0].lower() != "f", default=True)
    args = parser.parse_args()
    redact(args.dry_run)
    if args.dry_run:
        print("Dry run, use --dry-run=false to actually redact files")


if __name__ == "__main__":
    main()



---
File: /tests/__init__.py
---




---
File: /tests/test_encoding.py
---

# Note that there are more actual tests, they're just not currently public :-)

from typing import Callable

import hypothesis
import hypothesis.strategies as st
import pytest

import tiktoken

from .test_helpers import ENCODING_FACTORIES, MAX_EXAMPLES


def test_simple():
    enc = tiktoken.get_encoding("gpt2")
    assert enc.encode("hello world") == [31373, 995]
    assert enc.decode([31373, 995]) == "hello world"
    assert enc.encode("hello <|endoftext|>", allowed_special="all") == [31373, 220, 50256]

    enc = tiktoken.get_encoding("cl100k_base")
    assert enc.encode("hello world") == [15339, 1917]
    assert enc.decode([15339, 1917]) == "hello world"
    assert enc.encode("hello <|endoftext|>", allowed_special="all") == [15339, 220, 100257]

    for enc_name in tiktoken.list_encoding_names():
        enc = tiktoken.get_encoding(enc_name)
        for token in range(min(10_000, enc.max_token_value - 1)):
            assert enc.encode_single_token(enc.decode_single_token_bytes(token)) == token


def test_simple_repeated():
    enc = tiktoken.get_encoding("gpt2")
    assert enc.encode("0") == [15]
    assert enc.encode("00") == [405]
    assert enc.encode("000") == [830]
    assert enc.encode("0000") == [2388]
    assert enc.encode("00000") == [20483]
    assert enc.encode("000000") == [10535]
    assert enc.encode("0000000") == [24598]
    assert enc.encode("00000000") == [8269]
    assert enc.encode("000000000") == [10535, 830]
    assert enc.encode("0000000000") == [8269, 405]
    assert enc.encode("00000000000") == [8269, 830]
    assert enc.encode("000000000000") == [8269, 2388]
    assert enc.encode("0000000000000") == [8269, 20483]
    assert enc.encode("00000000000000") == [8269, 10535]
    assert enc.encode("000000000000000") == [8269, 24598]
    assert enc.encode("0000000000000000") == [25645]
    assert enc.encode("00000000000000000") == [8269, 10535, 830]


def test_simple_regex():
    enc = tiktoken.get_encoding("cl100k_base")
    assert enc.encode("rer") == [38149]
    assert enc.encode("'rer") == [2351, 81]
    assert enc.encode("today\n ") == [31213, 198, 220]
    assert enc.encode("today\n \n") == [31213, 27907]
    assert enc.encode("today\n  \n") == [31213, 14211]


def test_basic_encode():
    enc = tiktoken.get_encoding("r50k_base")
    assert enc.encode("hello world") == [31373, 995]

    enc = tiktoken.get_encoding("p50k_base")
    assert enc.encode("hello world") == [31373, 995]

    enc = tiktoken.get_encoding("cl100k_base")
    assert enc.encode("hello world") == [15339, 1917]
    assert enc.encode(" \x850") == [220, 126, 227, 15]


def test_encode_empty():
    enc = tiktoken.get_encoding("r50k_base")
    assert enc.encode("") == []


def test_encode_bytes():
    enc = tiktoken.get_encoding("cl100k_base")
    assert enc._encode_bytes(b" \xec\x8b\xa4\xed") == [62085]
    for i in range(10):
        bytestring = b"\x80" * i
        assert enc.decode_bytes(enc._encode_bytes(bytestring)) == bytestring


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
@hypothesis.given(bytestring=st.binary())
@hypothesis.settings(deadline=None)
def test_hyp_encode_bytes(make_enc: Callable[[], tiktoken.Encoding], bytestring: bytes):
    enc = make_enc()
    assert enc.decode_bytes(enc._encode_bytes(bytestring)) == bytestring


def test_encode_surrogate_pairs():
    enc = tiktoken.get_encoding("cl100k_base")

    assert enc.encode("👍") == [9468, 239, 235]
    # surrogate pair gets converted to codepoint
    assert enc.encode("\ud83d\udc4d") == [9468, 239, 235]

    # lone surrogate just gets replaced
    assert enc.encode("\ud83d") == enc.encode("�")


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
def test_catastrophically_repetitive(make_enc: Callable[[], tiktoken.Encoding]):
    enc = make_enc()
    for c in ["^", "0", "a", "'s", " ", "\n"]:
        big_value = c * 10_000
        assert big_value == enc.decode(enc.encode(big_value))

        big_value = " " + big_value
        assert big_value == enc.decode(enc.encode(big_value))

        big_value = big_value + "\n"
        assert big_value == enc.decode(enc.encode(big_value))


# ====================
# Roundtrip
# ====================


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
def test_basic_roundtrip(make_enc):
    enc = make_enc()
    for value in (
        "hello",
        "hello ",
        "hello  ",
        " hello",
        " hello ",
        " hello  ",
        "hello world",
        "请考试我的软件！12345",
    ):
        assert value == enc.decode(enc.encode(value))
        assert value == enc.decode(enc.encode_ordinary(value))


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
@hypothesis.given(text=st.text())
@hypothesis.settings(deadline=None)
def test_hyp_roundtrip(make_enc: Callable[[], tiktoken.Encoding], text):
    enc = make_enc()

    assert text == enc.decode(enc.encode(text))


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
def test_single_token_roundtrip(make_enc: Callable[[], tiktoken.Encoding]):
    enc = make_enc()

    for token in range(enc.n_vocab):
        try:
            token_bytes = enc.decode_single_token_bytes(token)
        except KeyError:
            continue
        assert enc.encode_single_token(token_bytes) == token


# ====================
# Special tokens
# ====================


def test_special_token():
    enc = tiktoken.get_encoding("cl100k_base")

    eot = enc.encode_single_token("<|endoftext|>")
    assert eot == enc.eot_token
    fip = enc.encode_single_token("<|fim_prefix|>")
    fim = enc.encode_single_token("<|fim_middle|>")

    text = "<|endoftext|> hello <|fim_prefix|>"
    assert eot not in enc.encode(text, disallowed_special=())
    with pytest.raises(ValueError):
        enc.encode(text)
    with pytest.raises(ValueError):
        enc.encode(text, disallowed_special="all")
    with pytest.raises(ValueError):
        enc.encode(text, disallowed_special={"<|endoftext|>"})
    with pytest.raises(ValueError):
        enc.encode(text, disallowed_special={"<|fim_prefix|>"})

    text = "<|endoftext|> hello <|fim_prefix|> there <|fim_middle|>"
    tokens = enc.encode(text, disallowed_special=())
    assert eot not in tokens
    assert fip not in tokens
    assert fim not in tokens

    tokens = enc.encode(text, allowed_special="all", disallowed_special=())
    assert eot in tokens
    assert fip in tokens
    assert fim in tokens

    tokens = enc.encode(text, allowed_special="all", disallowed_special="all")
    assert eot in tokens
    assert fip in tokens
    assert fim in tokens

    tokens = enc.encode(text, allowed_special={"<|fim_prefix|>"}, disallowed_special=())
    assert eot not in tokens
    assert fip in tokens
    assert fim not in tokens

    tokens = enc.encode(text, allowed_special={"<|endoftext|>"}, disallowed_special=())
    assert eot in tokens
    assert fip not in tokens
    assert fim not in tokens

    tokens = enc.encode(text, allowed_special={"<|fim_middle|>"}, disallowed_special=())
    assert eot not in tokens
    assert fip not in tokens
    assert fim in tokens


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
@hypothesis.given(text=st.text())
@hypothesis.settings(deadline=None, max_examples=MAX_EXAMPLES)
def test_hyp_special_ordinary(make_enc, text: str):
    enc = make_enc()
    assert enc.encode_ordinary(text) == enc.encode(text, disallowed_special=())


# ====================
# Batch encoding
# ====================


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
def test_batch_encode(make_enc: Callable[[], tiktoken.Encoding]):
    enc = make_enc()
    text1 = "hello world"
    text2 = "goodbye world"

    assert enc.encode_batch([text1]) == [enc.encode(text1)]
    assert enc.encode_batch([text1, text2]) == [enc.encode(text1), enc.encode(text2)]

    assert enc.encode_ordinary_batch([text1]) == [enc.encode_ordinary(text1)]
    assert enc.encode_ordinary_batch([text1, text2]) == [
        enc.encode_ordinary(text1),
        enc.encode_ordinary(text2),
    ]


@pytest.mark.parametrize("make_enc", ENCODING_FACTORIES)
@hypothesis.given(batch=st.lists(st.text()))
@hypothesis.settings(deadline=None)
def test_hyp_batch_roundtrip(make_enc: Callable[[], tiktoken.Encoding], batch):
    enc = make_enc()

    encoded = enc.encode_batch(batch)
    assert encoded == [enc.encode(t) for t in batch]
    decoded = enc.decode_batch(encoded)
    assert decoded == batch



---
File: /tests/test_helpers.py
---

import bisect
import functools
import os

import pytest

import tiktoken

MAX_EXAMPLES: int = int(os.environ.get("TIKTOKEN_MAX_EXAMPLES", "100"))

ENCODINGS = ["r50k_base", "cl100k_base"]
SOME_ENCODINGS = ["cl100k_base"]


ENCODING_FACTORIES = [
    pytest.param(functools.partial(tiktoken.get_encoding, name), id=name) for name in ENCODINGS
]
SOME_ENCODING_FACTORIES = [
    pytest.param(functools.partial(tiktoken.get_encoding, name), id=name) for name in SOME_ENCODINGS
]





---
File: /tests/test_misc.py
---

import subprocess
import sys

import tiktoken


def test_encoding_for_model():
    enc = tiktoken.encoding_for_model("gpt2")
    assert enc.name == "gpt2"
    enc = tiktoken.encoding_for_model("text-davinci-003")
    assert enc.name == "p50k_base"
    enc = tiktoken.encoding_for_model("text-davinci-edit-001")
    assert enc.name == "p50k_edit"
    enc = tiktoken.encoding_for_model("gpt-3.5-turbo-0301")
    assert enc.name == "cl100k_base"
    enc = tiktoken.encoding_for_model("gpt-4")
    assert enc.name == "cl100k_base"
    enc = tiktoken.encoding_for_model("gpt-4o")
    assert enc.name == "o200k_base"


def test_optional_blobfile_dependency():
    prog = """
import tiktoken
import sys
assert "blobfile" not in sys.modules
"""
    subprocess.check_call([sys.executable, "-c", prog])



---
File: /tests/test_offsets.py
---

from typing import Callable

import hypothesis
import pytest
from hypothesis import strategies as st

import tiktoken

from .test_helpers import MAX_EXAMPLES, SOME_ENCODING_FACTORIES


def _common_prefix_len(a, b):
    i = 0
    while i < len(a) and i < len(b) and a[i] == b[i]:
        i += 1
    return i


def _token_offsets_reference(enc, tokens):
    text = enc.decode(tokens, errors="strict")
    res = []
    for i in range(len(tokens)):
        prefix = enc.decode(tokens[:i], errors="ignore")
        res.append(_common_prefix_len(text, prefix))
    return res


@pytest.mark.parametrize("make_enc", SOME_ENCODING_FACTORIES)
@hypothesis.given(data=st.data())
@hypothesis.settings(deadline=None, max_examples=MAX_EXAMPLES)
def test_hyp_offsets(make_enc: Callable[[], tiktoken.Encoding], data):
    enc = make_enc()

    tokens_st = st.lists(
        st.integers(0, enc.n_vocab - 1).filter(
            lambda x: x in enc._special_tokens.values() or x in enc._mergeable_ranks.values()
        ),
        min_size=1,
        max_size=20,
    )
    tokens = data.draw(tokens_st)

    # This is a dumb hack to make sure that our tokens are a valid UTF-8 string
    # We could potentially drop this, see the TODO in decode_with_offsets
    tokens = enc.encode(enc.decode(tokens, errors="ignore"), allowed_special="all")
    assert enc.decode_with_offsets(tokens)[1] == _token_offsets_reference(enc, tokens)


def test_basic_offsets():
    enc = tiktoken.get_encoding("cl100k_base")

    prompt = "hello world"
    p, o = enc.decode_with_offsets(enc.encode(prompt))
    assert p == prompt
    assert o == [0, 5]

    prompt = "hello world<|endoftext|> green cow"
    p, o = enc.decode_with_offsets(enc.encode(prompt, allowed_special="all"))
    assert p == prompt
    assert o == [0, 5, 11, 24, 30]

    prompt = "我非常渴望与人工智能一起工作"
    p, o = enc.decode_with_offsets(enc.encode(prompt))
    assert p == prompt
    assert o == [0, 1, 2, 3, 3, 4, 4, 5, 6, 7, 8, 8, 9, 10, 11, 12, 13]

    # contains the interesting tokens b'\xe0\xae\xbf\xe0\xae' and b'\xe0\xaf\x8d\xe0\xae'
    # in which \xe0 is the start of a 3-byte UTF-8 character
    prompt = "நடிகர் சூர்யா"
    p, o = enc.decode_with_offsets(enc.encode(prompt))
    assert p == prompt
    assert o == [0, 0, 1, 1, 2, 3, 4, 4, 5, 6, 7, 8, 8, 9, 9, 10, 11, 12, 12]

    # contains the interesting token b'\xa0\xe9\x99\xa4'
    # in which \xe9 is the start of a 3-byte UTF-8 character and \xa0 is a continuation byte
    prompt = " Ġ除"
    p, o = enc.decode_with_offsets(enc.encode(prompt))
    assert p == prompt
    assert o == [0, 1]



---
File: /tests/test_pickle.py
---

import tiktoken


def test_pickle():
    import pickle

    enc_old = tiktoken.get_encoding("r50k_base")
    enc_new = pickle.loads(pickle.dumps(enc_old))
    assert enc_old.encode("hello world") == enc_new.encode("hello world")

    enc_old = tiktoken.Encoding(
        name="custom_enc",
        pat_str=enc_old._pat_str,
        mergeable_ranks=enc_old._mergeable_ranks,
        special_tokens={"<|pickle|>": 100_000},
    )
    enc_new = pickle.loads(pickle.dumps(enc_old))
    assert enc_old.encode("hello world") == enc_new.encode("hello world")
    assert (
        enc_old.encode("<|pickle|>", allowed_special="all")
        == enc_new.encode("<|pickle|>", allowed_special="all")
        == [100_000]
    )



---
File: /tests/test_simple_public.py
---

import subprocess
import sys

import tiktoken


def test_simple():
    # Note that there are more actual tests, they're just not currently public :-)
    enc = tiktoken.get_encoding("gpt2")
    assert enc.encode("hello world") == [31373, 995]
    assert enc.decode([31373, 995]) == "hello world"
    assert enc.encode("hello <|endoftext|>", allowed_special="all") == [31373, 220, 50256]

    enc = tiktoken.get_encoding("cl100k_base")
    assert enc.encode("hello world") == [15339, 1917]
    assert enc.decode([15339, 1917]) == "hello world"
    assert enc.encode("hello <|endoftext|>", allowed_special="all") == [15339, 220, 100257]

    for enc_name in tiktoken.list_encoding_names():
        enc = tiktoken.get_encoding(enc_name)
        for token in range(10_000):
            assert enc.encode_single_token(enc.decode_single_token_bytes(token)) == token


def test_encoding_for_model():
    enc = tiktoken.encoding_for_model("gpt2")
    assert enc.name == "gpt2"
    enc = tiktoken.encoding_for_model("text-davinci-003")
    assert enc.name == "p50k_base"
    enc = tiktoken.encoding_for_model("text-davinci-edit-001")
    assert enc.name == "p50k_edit"
    enc = tiktoken.encoding_for_model("gpt-3.5-turbo-0301")
    assert enc.name == "cl100k_base"


def test_optional_blobfile_dependency():
    prog = """
import tiktoken
import sys
assert "blobfile" not in sys.modules
"""
    subprocess.check_call([sys.executable, "-c", prog])



---
File: /tiktoken/__init__.py
---

# This is the public API of tiktoken
from .core import Encoding as Encoding
from .model import encoding_for_model as encoding_for_model
from .model import encoding_name_for_model as encoding_name_for_model
from .registry import get_encoding as get_encoding
from .registry import list_encoding_names as list_encoding_names

__version__ = "0.9.0"



---
File: /tiktoken/_educational.py
---

"""This is an educational implementation of the byte pair encoding algorithm."""

from __future__ import annotations

import collections

import regex

import tiktoken


class SimpleBytePairEncoding:
    def __init__(self, *, pat_str: str, mergeable_ranks: dict[bytes, int]) -> None:
        """Creates an Encoding object."""
        # A regex pattern string that is used to split the input text
        self.pat_str = pat_str
        # A dictionary mapping token bytes to their ranks. The ranks correspond to merge priority
        self.mergeable_ranks = mergeable_ranks

        self._decoder = {token: token_bytes for token_bytes, token in mergeable_ranks.items()}
        self._pat = regex.compile(pat_str)

    def encode(self, text: str, visualise: str | None = "colour") -> list[int]:
        """Encodes a string into tokens.

        >>> enc.encode("hello world")
        [388, 372]
        """
        # Use the regex to split the text into (approximately) words
        words = self._pat.findall(text)
        tokens = []
        for word in words:
            # Turn each word into tokens, using the byte pair encoding algorithm
            word_bytes = word.encode("utf-8")
            word_tokens = bpe_encode(self.mergeable_ranks, word_bytes, visualise=visualise)
            tokens.extend(word_tokens)
        return tokens

    def decode_bytes(self, tokens: list[int]) -> bytes:
        """Decodes a list of tokens into bytes.

        >>> enc.decode_bytes([388, 372])
        b'hello world'
        """
        return b"".join(self._decoder[token] for token in tokens)

    def decode(self, tokens: list[int]) -> str:
        """Decodes a list of tokens into a string.

        Decoded bytes are not guaranteed to be valid UTF-8. In that case, we replace
        the invalid bytes with the replacement character "�".

        >>> enc.decode([388, 372])
        'hello world'
        """
        return self.decode_bytes(tokens).decode("utf-8", errors="replace")

    def decode_tokens_bytes(self, tokens: list[int]) -> list[bytes]:
        """Decodes a list of tokens into a list of bytes.

        Useful for visualising how a string is tokenised.

        >>> enc.decode_tokens_bytes([388, 372])
        [b'hello', b' world']
        """
        return [self._decoder[token] for token in tokens]

    @staticmethod
    def train(training_data: str, vocab_size: int, pat_str: str):
        """Train a BPE tokeniser on some data!"""
        mergeable_ranks = bpe_train(data=training_data, vocab_size=vocab_size, pat_str=pat_str)
        return SimpleBytePairEncoding(pat_str=pat_str, mergeable_ranks=mergeable_ranks)

    @staticmethod
    def from_tiktoken(encoding):
        if isinstance(encoding, str):
            encoding = tiktoken.get_encoding(encoding)
        return SimpleBytePairEncoding(
            pat_str=encoding._pat_str, mergeable_ranks=encoding._mergeable_ranks
        )


def bpe_encode(
    mergeable_ranks: dict[bytes, int], input: bytes, visualise: str | None = "colour"
) -> list[int]:
    parts = [bytes([b]) for b in input]
    while True:
        # See the intermediate merges play out!
        if visualise:
            if visualise in ["colour", "color"]:
                visualise_tokens(parts)
            elif visualise == "simple":
                print(parts)

        # Iterate over all pairs and find the pair we want to merge the most
        min_idx = None
        min_rank = None
        for i, pair in enumerate(zip(parts[:-1], parts[1:])):
            rank = mergeable_ranks.get(pair[0] + pair[1])
            if rank is not None and (min_rank is None or rank < min_rank):
                min_idx = i
                min_rank = rank

        # If there were no pairs we could merge, we're done!
        if min_rank is None:
            break
        assert min_idx is not None

        # Otherwise, merge that pair and leave the rest unchanged. Then repeat.
        parts = parts[:min_idx] + [parts[min_idx] + parts[min_idx + 1]] + parts[min_idx + 2 :]

    if visualise:
        print()

    tokens = [mergeable_ranks[part] for part in parts]
    return tokens


def bpe_train(
    data: str, vocab_size: int, pat_str: str, visualise: str | None = "colour"
) -> dict[bytes, int]:
    # First, add tokens for each individual byte value
    if vocab_size < 2**8:
        raise ValueError("vocab_size must be at least 256, so we can encode all bytes")
    ranks = {}
    for i in range(2**8):
        ranks[bytes([i])] = i

    # Splinter up our data into lists of bytes
    # data = "Hello world"
    # words = [
    #     [b'H', b'e', b'l', b'l', b'o'],
    #     [b' ', b'w', b'o', b'r', b'l', b'd']
    # ]
    words: list[list[bytes]] = [
        [bytes([b]) for b in word.encode("utf-8")] for word in regex.findall(pat_str, data)
    ]

    # Now, use our data to figure out which merges we should make
    while len(ranks) < vocab_size:
        # Find the most common pair. This will become our next token
        stats = collections.Counter()
        for piece in words:
            for pair in zip(piece[:-1], piece[1:]):
                stats[pair] += 1

        most_common_pair = max(stats, key=lambda x: stats[x])
        token_bytes = most_common_pair[0] + most_common_pair[1]
        token = len(ranks)
        # Add the new token!
        ranks[token_bytes] = token

        # Now merge that most common pair in all the words. That is, update our training data
        # to reflect our decision to make that pair into a new token.
        new_words = []
        for word in words:
            new_word = []
            i = 0
            while i < len(word) - 1:
                if (word[i], word[i + 1]) == most_common_pair:
                    # We found our pair! Merge it
                    new_word.append(token_bytes)
                    i += 2
                else:
                    new_word.append(word[i])
                    i += 1
            if i == len(word) - 1:
                new_word.append(word[i])
            new_words.append(new_word)
        words = new_words

        # See the intermediate merges play out!
        if visualise:
            print(f"The current most common pair is {most_common_pair[0]} + {most_common_pair[1]}")
            print(f"So we made {token_bytes} our {len(ranks)}th token")
            if visualise in ["colour", "color"]:
                print("Now the first fifty words in our training data look like:")
                visualise_tokens([token for word in words[:50] for token in word])
            elif visualise == "simple":
                print("Now the first twenty words in our training data look like:")
                for word in words[:20]:
                    print(word)
            print("\n")

    return ranks


def visualise_tokens(token_values: list[bytes]) -> None:
    background = [f"\u001b[48;5;{i}m" for i in [167, 179, 185, 77, 80, 68, 134]]
    # If token boundaries do not occur at unicode character boundaries, it's unclear how best to
    # visualise the token. Here, we'll just use the unicode replacement character to represent some
    # fraction of a character.
    unicode_token_values = [x.decode("utf-8", errors="replace") for x in token_values]

    running_length = 0
    last_color = None
    for token in unicode_token_values:
        color = background[running_length % len(background)]
        if color == last_color:
            color = background[(running_length + 1) % len(background)]
            assert color != last_color
        last_color = color
        running_length += len(token)
        print(color + token, end="")
    print("\u001b[0m")


def train_simple_encoding():
    gpt2_pattern = (
        r"""'s|'t|'re|'ve|'m|'ll|'d| ?[\p{L}]+| ?[\p{N}]+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"""
    )
    with open(__file__) as f:
        data = f.read()

    enc = SimpleBytePairEncoding.train(data, vocab_size=600, pat_str=gpt2_pattern)

    print("This is the sequence of merges performed in order to encode 'hello world':")
    tokens = enc.encode("hello world")
    assert enc.decode(tokens) == "hello world"
    assert enc.decode_bytes(tokens) == b"hello world"
    assert enc.decode_tokens_bytes(tokens) == [b"hello", b" world"]

    return enc



---
File: /tiktoken/core.py
---

from __future__ import annotations

import functools
from concurrent.futures import ThreadPoolExecutor
from typing import TYPE_CHECKING, AbstractSet, Collection, Literal, NoReturn, Sequence

import regex

from tiktoken import _tiktoken

if TYPE_CHECKING:
    import numpy as np
    import numpy.typing as npt


class Encoding:
    def __init__(
        self,
        name: str,
        *,
        pat_str: str,
        mergeable_ranks: dict[bytes, int],
        special_tokens: dict[str, int],
        explicit_n_vocab: int | None = None,
    ):
        """Creates an Encoding object.

        See openai_public.py for examples of how to construct an Encoding object.

        Args:
            name: The name of the encoding. It should be clear from the name of the encoding
                what behaviour to expect, in particular, encodings with different special tokens
                should have different names.
            pat_str: A regex pattern string that is used to split the input text.
            mergeable_ranks: A dictionary mapping mergeable token bytes to their ranks. The ranks
                must correspond to merge priority.
            special_tokens: A dictionary mapping special token strings to their token values.
            explicit_n_vocab: The number of tokens in the vocabulary. If provided, it is checked
                that the number of mergeable tokens and special tokens is equal to this number.
        """
        self.name = name

        self._pat_str = pat_str
        self._mergeable_ranks = mergeable_ranks
        self._special_tokens = special_tokens

        self.max_token_value = max(
            max(mergeable_ranks.values()), max(special_tokens.values(), default=0)
        )
        if explicit_n_vocab:
            assert len(mergeable_ranks) + len(special_tokens) == explicit_n_vocab
            assert self.max_token_value == explicit_n_vocab - 1

        self._core_bpe = _tiktoken.CoreBPE(mergeable_ranks, special_tokens, pat_str)

    def __repr__(self) -> str:
        return f"<Encoding {self.name!r}>"

    # ====================
    # Encoding
    # ====================

    def encode_ordinary(self, text: str) -> list[int]:
        """Encodes a string into tokens, ignoring special tokens.

        This is equivalent to `encode(text, disallowed_special=())` (but slightly faster).

        ```
        >>> enc.encode_ordinary("hello world")
        [31373, 995]
        """
        try:
            return self._core_bpe.encode_ordinary(text)
        except UnicodeEncodeError:
            # See comment in encode
            text = text.encode("utf-16", "surrogatepass").decode("utf-16", "replace")
            return self._core_bpe.encode_ordinary(text)

    def encode(
        self,
        text: str,
        *,
        allowed_special: Literal["all"] | AbstractSet[str] = set(),  # noqa: B006
        disallowed_special: Literal["all"] | Collection[str] = "all",
    ) -> list[int]:
        """Encodes a string into tokens.

        Special tokens are artificial tokens used to unlock capabilities from a model,
        such as fill-in-the-middle. So we want to be careful about accidentally encoding special
        tokens, since they can be used to trick a model into doing something we don't want it to do.

        Hence, by default, encode will raise an error if it encounters text that corresponds
        to a special token. This can be controlled on a per-token level using the `allowed_special`
        and `disallowed_special` parameters. In particular:
        - Setting `disallowed_special` to () will prevent this function from raising errors and
          cause all text corresponding to special tokens to be encoded as natural text.
        - Setting `allowed_special` to "all" will cause this function to treat all text
          corresponding to special tokens to be encoded as special tokens.

        ```
        >>> enc.encode("hello world")
        [31373, 995]
        >>> enc.encode("<|endoftext|>", allowed_special={"<|endoftext|>"})
        [50256]
        >>> enc.encode("<|endoftext|>", allowed_special="all")
        [50256]
        >>> enc.encode("<|endoftext|>")
        # Raises ValueError
        >>> enc.encode("<|endoftext|>", disallowed_special=())
        [27, 91, 437, 1659, 5239, 91, 29]
        ```
        """
        if allowed_special == "all":
            allowed_special = self.special_tokens_set
        if disallowed_special == "all":
            disallowed_special = self.special_tokens_set - allowed_special
        if disallowed_special:
            if not isinstance(disallowed_special, frozenset):
                disallowed_special = frozenset(disallowed_special)
            if match := _special_token_regex(disallowed_special).search(text):
                raise_disallowed_special_token(match.group())

        try:
            return self._core_bpe.encode(text, allowed_special)
        except UnicodeEncodeError:
            # BPE operates on bytes, but the regex operates on unicode. If we pass a str that is
            # invalid UTF-8 to Rust, it will rightfully complain. Here we do a quick and dirty
            # fixup for any surrogate pairs that may have sneaked their way into the text.
            # Technically, this introduces a place where encode + decode doesn't roundtrip a Python
            # string, but given that this is input we want to support, maybe that's okay.
            # Also we use errors="replace" to handle weird things like lone surrogates.
            text = text.encode("utf-16", "surrogatepass").decode("utf-16", "replace")
            return self._core_bpe.encode(text, allowed_special)

    def encode_to_numpy(
        self,
        text: str,
        *,
        allowed_special: Literal["all"] | AbstractSet[str] = set(),  # noqa: B006
        disallowed_special: Literal["all"] | Collection[str] = "all",
    ) -> npt.NDArray[np.uint32]:
        """Encodes a string into tokens, returning a numpy array.

        Avoids the overhead of copying the token buffer into a Python list.
        """
        if allowed_special == "all":
            allowed_special = self.special_tokens_set
        if disallowed_special == "all":
            disallowed_special = self.special_tokens_set - allowed_special
        if disallowed_special:
            if not isinstance(disallowed_special, frozenset):
                disallowed_special = frozenset(disallowed_special)
            if match := _special_token_regex(disallowed_special).search(text):
                raise_disallowed_special_token(match.group())

        import numpy as np

        buffer = self._core_bpe.encode_to_tiktoken_buffer(text, self.special_tokens_set)
        return np.frombuffer(buffer, dtype=np.uint32)

    def encode_ordinary_batch(self, text: list[str], *, num_threads: int = 8) -> list[list[int]]:
        """Encodes a list of strings into tokens, in parallel, ignoring special tokens.

        This is equivalent to `encode_batch(text, disallowed_special=())` (but slightly faster).

        ```
        >>> enc.encode_ordinary_batch(["hello world", "goodbye world"])
        [[31373, 995], [11274, 16390, 995]]
        ```
        """
        encoder = functools.partial(self.encode_ordinary)
        with ThreadPoolExecutor(num_threads) as e:
            return list(e.map(encoder, text))

    def encode_batch(
        self,
        text: list[str],
        *,
        num_threads: int = 8,
        allowed_special: Literal["all"] | AbstractSet[str] = set(),  # noqa: B006
        disallowed_special: Literal["all"] | Collection[str] = "all",
    ) -> list[list[int]]:
        """Encodes a list of strings into tokens, in parallel.

        See `encode` for more details on `allowed_special` and `disallowed_special`.

        ```
        >>> enc.encode_batch(["hello world", "goodbye world"])
        [[31373, 995], [11274, 16390, 995]]
        ```
        """
        if allowed_special == "all":
            allowed_special = self.special_tokens_set
        if disallowed_special == "all":
            disallowed_special = self.special_tokens_set - allowed_special
        if not isinstance(disallowed_special, frozenset):
            disallowed_special = frozenset(disallowed_special)

        encoder = functools.partial(
            self.encode, allowed_special=allowed_special, disallowed_special=disallowed_special
        )
        with ThreadPoolExecutor(num_threads) as e:
            return list(e.map(encoder, text))

    def encode_with_unstable(
        self,
        text: str,
        *,
        allowed_special: Literal["all"] | AbstractSet[str] = set(),  # noqa: B006
        disallowed_special: Literal["all"] | Collection[str] = "all",
    ) -> tuple[list[int], list[list[int]]]:
        """Encodes a string into stable tokens and possible completion sequences.

        Note that the stable tokens will only represent a substring of `text`.

        See `encode` for more details on `allowed_special` and `disallowed_special`.

        This API should itself be considered unstable.

        ```
        >>> enc.encode_with_unstable("hello fanta")
        ([31373], [(277, 4910), (5113, 265), ..., (8842,)])

        >>> text = "..."
        >>> stable_tokens, completions = enc.encode_with_unstable(text)
        >>> assert text.encode().startswith(enc.decode_bytes(stable_tokens))
        >>> assert all(enc.decode_bytes(stable_tokens + seq).startswith(text.encode()) for seq in completions)
        ```
        """
        if allowed_special == "all":
            allowed_special = self.special_tokens_set
        if disallowed_special == "all":
            disallowed_special = self.special_tokens_set - allowed_special
        if disallowed_special:
            if not isinstance(disallowed_special, frozenset):
                disallowed_special = frozenset(disallowed_special)
            if match := _special_token_regex(disallowed_special).search(text):
                raise_disallowed_special_token(match.group())

        return self._core_bpe.encode_with_unstable(text, allowed_special)

    def encode_single_token(self, text_or_bytes: str | bytes) -> int:
        """Encodes text corresponding to a single token to its token value.

        NOTE: this will encode all special tokens.

        Raises `KeyError` if the token is not in the vocabulary.

        ```
        >>> enc.encode_single_token("hello")
        31373
        ```
        """
        if isinstance(text_or_bytes, str):
            text_or_bytes = text_or_bytes.encode("utf-8")
        return self._core_bpe.encode_single_token(text_or_bytes)

    # ====================
    # Decoding
    # ====================

    def decode_bytes(self, tokens: Sequence[int]) -> bytes:
        """Decodes a list of tokens into bytes.

        ```
        >>> enc.decode_bytes([31373, 995])
        b'hello world'
        ```
        """
        return self._core_bpe.decode_bytes(tokens)

    def decode(self, tokens: Sequence[int], errors: str = "replace") -> str:
        """Decodes a list of tokens into a string.

        WARNING: the default behaviour of this function is lossy, since decoded bytes are not
        guaranteed to be valid UTF-8. You can control this behaviour using the `errors` parameter,
        for instance, setting `errors=strict`.

        ```
        >>> enc.decode([31373, 995])
        'hello world'
        ```
        """
        return self._core_bpe.decode_bytes(tokens).decode("utf-8", errors=errors)

    def decode_single_token_bytes(self, token: int) -> bytes:
        """Decodes a token into bytes.

        NOTE: this will decode all special tokens.

        Raises `KeyError` if the token is not in the vocabulary.

        ```
        >>> enc.decode_single_token_bytes(31373)
        b'hello'
        ```
        """
        return self._core_bpe.decode_single_token_bytes(token)

    def decode_tokens_bytes(self, tokens: Sequence[int]) -> list[bytes]:
        """Decodes a list of tokens into a list of bytes.

        Useful for visualising tokenisation.
        >>> enc.decode_tokens_bytes([31373, 995])
        [b'hello', b' world']
        """
        return [self.decode_single_token_bytes(token) for token in tokens]

    def decode_with_offsets(self, tokens: Sequence[int]) -> tuple[str, list[int]]:
        """Decodes a list of tokens into a string and a list of offsets.

        Each offset is the index into text corresponding to the start of each token.
        If UTF-8 character boundaries do not line up with token boundaries, the offset is the index
        of the first character that contains bytes from the token.

        This will currently raise if given tokens that decode to invalid UTF-8; this behaviour may
        change in the future to be more permissive.

        >>> enc.decode_with_offsets([31373, 995])
        ('hello world', [0, 5])
        """
        token_bytes = self.decode_tokens_bytes(tokens)

        text_len = 0
        offsets = []
        for token in token_bytes:
            offsets.append(max(0, text_len - (0x80 <= token[0] < 0xC0)))
            text_len += sum(1 for c in token if not 0x80 <= c < 0xC0)

        # TODO: assess correctness for errors="ignore" and errors="replace"
        text = b"".join(token_bytes).decode("utf-8", errors="strict")
        return text, offsets

    def decode_batch(
        self, batch: Sequence[Sequence[int]], *, errors: str = "replace", num_threads: int = 8
    ) -> list[str]:
        """Decodes a batch (list of lists of tokens) into a list of strings."""
        decoder = functools.partial(self.decode, errors=errors)
        with ThreadPoolExecutor(num_threads) as e:
            return list(e.map(decoder, batch))

    def decode_bytes_batch(
        self, batch: Sequence[Sequence[int]], *, num_threads: int = 8
    ) -> list[bytes]:
        """Decodes a batch (list of lists of tokens) into a list of bytes."""
        with ThreadPoolExecutor(num_threads) as e:
            return list(e.map(self.decode_bytes, batch))

    # ====================
    # Miscellaneous
    # ====================

    def token_byte_values(self) -> list[bytes]:
        """Returns the list of all token byte values."""
        return self._core_bpe.token_byte_values()

    @property
    def eot_token(self) -> int:
        return self._special_tokens["<|endoftext|>"]

    @functools.cached_property
    def special_tokens_set(self) -> set[str]:
        return set(self._special_tokens.keys())

    def is_special_token(self, token: int) -> bool:
        assert isinstance(token, int)
        return token in self._special_token_values

    @property
    def n_vocab(self) -> int:
        """For backwards compatibility. Prefer to use `enc.max_token_value + 1`."""
        return self.max_token_value + 1

    # ====================
    # Private
    # ====================

    def _encode_single_piece(self, text_or_bytes: str | bytes) -> list[int]:
        """Encodes text corresponding to bytes without a regex split.

        NOTE: this will not encode any special tokens.

        ```
        >>> enc.encode_single_piece("helloqqqq")
        [31373, 38227, 38227]
        ```
        """
        if isinstance(text_or_bytes, str):
            text_or_bytes = text_or_bytes.encode("utf-8")
        return self._core_bpe.encode_single_piece(text_or_bytes)

    def _encode_only_native_bpe(self, text: str) -> list[int]:
        """Encodes a string into tokens, but do regex splitting in Python."""
        _unused_pat = regex.compile(self._pat_str)
        ret = []
        for piece in regex.findall(_unused_pat, text):
            ret.extend(self._core_bpe.encode_single_piece(piece))
        return ret

    def _encode_bytes(self, text: bytes) -> list[int]:
        return self._core_bpe._encode_bytes(text)

    def __getstate__(self) -> object:
        import tiktoken.registry

        # As an optimisation, pickle registered encodings by reference
        if self is tiktoken.registry.ENCODINGS.get(self.name):
            return self.name
        return {
            "name": self.name,
            "pat_str": self._pat_str,
            "mergeable_ranks": self._mergeable_ranks,
            "special_tokens": self._special_tokens,
        }

    def __setstate__(self, value: object) -> None:
        import tiktoken.registry

        if isinstance(value, str):
            self.__dict__ = tiktoken.registry.get_encoding(value).__dict__
            return
        self.__init__(**value)


@functools.lru_cache(maxsize=128)
def _special_token_regex(tokens: frozenset[str]) -> "regex.Pattern[str]":
    inner = "|".join(regex.escape(token) for token in tokens)
    return regex.compile(f"({inner})")


def raise_disallowed_special_token(token: str) -> NoReturn:
    raise ValueError(
        f"Encountered text corresponding to disallowed special token {token!r}.\n"
        "If you want this text to be encoded as a special token, "
        f"pass it to `allowed_special`, e.g. `allowed_special={{{token!r}, ...}}`.\n"
        f"If you want this text to be encoded as normal text, disable the check for this token "
        f"by passing `disallowed_special=(enc.special_tokens_set - {{{token!r}}})`.\n"
        "To disable this check for all special tokens, pass `disallowed_special=()`.\n"
    )



---
File: /tiktoken/load.py
---

from __future__ import annotations

import base64
import hashlib
import os


def read_file(blobpath: str) -> bytes:
    if not blobpath.startswith("http://") and not blobpath.startswith("https://"):
        try:
            import blobfile
        except ImportError as e:
            raise ImportError(
                "blobfile is not installed. Please install it by running `pip install blobfile`."
            ) from e
        with blobfile.BlobFile(blobpath, "rb") as f:
            return f.read()

    # avoiding blobfile for public files helps avoid auth issues, like MFA prompts
    import requests

    resp = requests.get(blobpath)
    resp.raise_for_status()
    return resp.content


def check_hash(data: bytes, expected_hash: str) -> bool:
    actual_hash = hashlib.sha256(data).hexdigest()
    return actual_hash == expected_hash


def read_file_cached(blobpath: str, expected_hash: str | None = None) -> bytes:
    user_specified_cache = True
    if "TIKTOKEN_CACHE_DIR" in os.environ:
        cache_dir = os.environ["TIKTOKEN_CACHE_DIR"]
    elif "DATA_GYM_CACHE_DIR" in os.environ:
        cache_dir = os.environ["DATA_GYM_CACHE_DIR"]
    else:
        import tempfile

        cache_dir = os.path.join(tempfile.gettempdir(), "data-gym-cache")
        user_specified_cache = False

    if cache_dir == "":
        # disable caching
        return read_file(blobpath)

    cache_key = hashlib.sha1(blobpath.encode()).hexdigest()

    cache_path = os.path.join(cache_dir, cache_key)
    if os.path.exists(cache_path):
        with open(cache_path, "rb") as f:
            data = f.read()
        if expected_hash is None or check_hash(data, expected_hash):
            return data

        # the cached file does not match the hash, remove it and re-fetch
        try:
            os.remove(cache_path)
        except OSError:
            pass

    contents = read_file(blobpath)
    if expected_hash and not check_hash(contents, expected_hash):
        raise ValueError(
            f"Hash mismatch for data downloaded from {blobpath} (expected {expected_hash}). "
            f"This may indicate a corrupted download. Please try again."
        )

    import uuid

    try:
        os.makedirs(cache_dir, exist_ok=True)
        tmp_filename = cache_path + "." + str(uuid.uuid4()) + ".tmp"
        with open(tmp_filename, "wb") as f:
            f.write(contents)
        os.rename(tmp_filename, cache_path)
    except OSError:
        # don't raise if we can't write to the default cache, e.g. issue #75
        if user_specified_cache:
            raise

    return contents


def data_gym_to_mergeable_bpe_ranks(
    vocab_bpe_file: str,
    encoder_json_file: str,
    vocab_bpe_hash: str | None = None,
    encoder_json_hash: str | None = None,
) -> dict[bytes, int]:
    # NB: do not add caching to this function
    rank_to_intbyte = [b for b in range(2**8) if chr(b).isprintable() and chr(b) != " "]

    data_gym_byte_to_byte = {chr(b): b for b in rank_to_intbyte}
    n = 0
    for b in range(2**8):
        if b not in rank_to_intbyte:
            rank_to_intbyte.append(b)
            data_gym_byte_to_byte[chr(2**8 + n)] = b
            n += 1
    assert len(rank_to_intbyte) == 2**8

    # vocab_bpe contains the merges along with associated ranks
    vocab_bpe_contents = read_file_cached(vocab_bpe_file, vocab_bpe_hash).decode()
    bpe_merges = [tuple(merge_str.split()) for merge_str in vocab_bpe_contents.split("\n")[1:-1]]

    def decode_data_gym(value: str) -> bytes:
        return bytes(data_gym_byte_to_byte[b] for b in value)

    # add the single byte tokens
    bpe_ranks = {bytes([b]): i for i, b in enumerate(rank_to_intbyte)}
    # add the merged tokens
    n = len(bpe_ranks)
    for first, second in bpe_merges:
        bpe_ranks[decode_data_gym(first) + decode_data_gym(second)] = n
        n += 1

    import json

    # check that the encoder file matches the merges file
    # this sanity check is important since tiktoken assumes that ranks are ordered the same
    # as merge priority
    encoder_json = json.loads(read_file_cached(encoder_json_file, encoder_json_hash))
    encoder_json_loaded = {decode_data_gym(k): v for k, v in encoder_json.items()}
    # drop these two special tokens if present, since they're not mergeable bpe tokens
    encoder_json_loaded.pop(b"<|endoftext|>", None)
    encoder_json_loaded.pop(b"<|startoftext|>", None)
    assert bpe_ranks == encoder_json_loaded

    return bpe_ranks


def dump_tiktoken_bpe(bpe_ranks: dict[bytes, int], tiktoken_bpe_file: str) -> None:
    try:
        import blobfile
    except ImportError as e:
        raise ImportError(
            "blobfile is not installed. Please install it by running `pip install blobfile`."
        ) from e
    with blobfile.BlobFile(tiktoken_bpe_file, "wb") as f:
        for token, rank in sorted(bpe_ranks.items(), key=lambda x: x[1]):
            f.write(base64.b64encode(token) + b" " + str(rank).encode() + b"\n")


def load_tiktoken_bpe(tiktoken_bpe_file: str, expected_hash: str | None = None) -> dict[bytes, int]:
    # NB: do not add caching to this function
    contents = read_file_cached(tiktoken_bpe_file, expected_hash)
    ret = {}
    for line in contents.splitlines():
        if not line:
            continue
        try:
            token, rank = line.split()
            ret[base64.b64decode(token)] = int(rank)
        except Exception as e:
            raise ValueError(f"Error parsing line {line!r} in {tiktoken_bpe_file}") from e
    return ret



---
File: /tiktoken/model.py
---

from __future__ import annotations

from .core import Encoding
from .registry import get_encoding

# TODO: these will likely be replaced by an API endpoint
MODEL_PREFIX_TO_ENCODING: dict[str, str] = {
    "o1-": "o200k_base",
    "o3-": "o200k_base",
    # chat
    "chatgpt-4o-": "o200k_base",
    "gpt-4o-": "o200k_base",  # e.g., gpt-4o-2024-05-13
    "gpt-4-": "cl100k_base",  # e.g., gpt-4-0314, etc., plus gpt-4-32k
    "gpt-3.5-turbo-": "cl100k_base",  # e.g, gpt-3.5-turbo-0301, -0401, etc.
    "gpt-35-turbo-": "cl100k_base",  # Azure deployment name
    # fine-tuned
    "ft:gpt-4o": "o200k_base",
    "ft:gpt-4": "cl100k_base",
    "ft:gpt-3.5-turbo": "cl100k_base",
    "ft:davinci-002": "cl100k_base",
    "ft:babbage-002": "cl100k_base",
}

MODEL_TO_ENCODING: dict[str, str] = {
    # reasoning
    "o1": "o200k_base",
    "o3": "o200k_base",
    # chat
    "gpt-4o": "o200k_base",
    "gpt-4": "cl100k_base",
    "gpt-3.5-turbo": "cl100k_base",
    "gpt-3.5": "cl100k_base",  # Common shorthand
    "gpt-35-turbo": "cl100k_base",  # Azure deployment name
    # base
    "davinci-002": "cl100k_base",
    "babbage-002": "cl100k_base",
    # embeddings
    "text-embedding-ada-002": "cl100k_base",
    "text-embedding-3-small": "cl100k_base",
    "text-embedding-3-large": "cl100k_base",
    # DEPRECATED MODELS
    # text (DEPRECATED)
    "text-davinci-003": "p50k_base",
    "text-davinci-002": "p50k_base",
    "text-davinci-001": "r50k_base",
    "text-curie-001": "r50k_base",
    "text-babbage-001": "r50k_base",
    "text-ada-001": "r50k_base",
    "davinci": "r50k_base",
    "curie": "r50k_base",
    "babbage": "r50k_base",
    "ada": "r50k_base",
    # code (DEPRECATED)
    "code-davinci-002": "p50k_base",
    "code-davinci-001": "p50k_base",
    "code-cushman-002": "p50k_base",
    "code-cushman-001": "p50k_base",
    "davinci-codex": "p50k_base",
    "cushman-codex": "p50k_base",
    # edit (DEPRECATED)
    "text-davinci-edit-001": "p50k_edit",
    "code-davinci-edit-001": "p50k_edit",
    # old embeddings (DEPRECATED)
    "text-similarity-davinci-001": "r50k_base",
    "text-similarity-curie-001": "r50k_base",
    "text-similarity-babbage-001": "r50k_base",
    "text-similarity-ada-001": "r50k_base",
    "text-search-davinci-doc-001": "r50k_base",
    "text-search-curie-doc-001": "r50k_base",
    "text-search-babbage-doc-001": "r50k_base",
    "text-search-ada-doc-001": "r50k_base",
    "code-search-babbage-code-001": "r50k_base",
    "code-search-ada-code-001": "r50k_base",
    # open source
    "gpt2": "gpt2",
    "gpt-2": "gpt2",  # Maintains consistency with gpt-4
}


def encoding_name_for_model(model_name: str) -> str:
    """Returns the name of the encoding used by a model.

    Raises a KeyError if the model name is not recognised.
    """
    encoding_name = None
    if model_name in MODEL_TO_ENCODING:
        encoding_name = MODEL_TO_ENCODING[model_name]
    else:
        # Check if the model matches a known prefix
        # Prefix matching avoids needing library updates for every model version release
        # Note that this can match on non-existent models (e.g., gpt-3.5-turbo-FAKE)
        for model_prefix, model_encoding_name in MODEL_PREFIX_TO_ENCODING.items():
            if model_name.startswith(model_prefix):
                return model_encoding_name

    if encoding_name is None:
        raise KeyError(
            f"Could not automatically map {model_name} to a tokeniser. "
            "Please use `tiktoken.get_encoding` to explicitly get the tokeniser you expect."
        ) from None

    return encoding_name


def encoding_for_model(model_name: str) -> Encoding:
    """Returns the encoding used by a model.

    Raises a KeyError if the model name is not recognised.
    """
    return get_encoding(encoding_name_for_model(model_name))



---
File: /tiktoken/registry.py
---

from __future__ import annotations

import functools
import importlib
import pkgutil
import threading
from typing import Any, Callable, Sequence

import tiktoken_ext

import tiktoken
from tiktoken.core import Encoding

_lock = threading.RLock()
ENCODINGS: dict[str, Encoding] = {}
ENCODING_CONSTRUCTORS: dict[str, Callable[[], dict[str, Any]]] | None = None


@functools.lru_cache
def _available_plugin_modules() -> Sequence[str]:
    # tiktoken_ext is a namespace package
    # submodules inside tiktoken_ext will be inspected for ENCODING_CONSTRUCTORS attributes
    # - we use namespace package pattern so `pkgutil.iter_modules` is fast
    # - it's a separate top-level package because namespace subpackages of non-namespace
    #   packages don't quite do what you want with editable installs
    mods = []
    plugin_mods = pkgutil.iter_modules(tiktoken_ext.__path__, tiktoken_ext.__name__ + ".")
    for _, mod_name, _ in plugin_mods:
        mods.append(mod_name)
    return mods


def _find_constructors() -> None:
    global ENCODING_CONSTRUCTORS
    with _lock:
        if ENCODING_CONSTRUCTORS is not None:
            return
        ENCODING_CONSTRUCTORS = {}

        try:
            for mod_name in _available_plugin_modules():
                mod = importlib.import_module(mod_name)
                try:
                    constructors = mod.ENCODING_CONSTRUCTORS
                except AttributeError as e:
                    raise ValueError(
                        f"tiktoken plugin {mod_name} does not define ENCODING_CONSTRUCTORS"
                    ) from e
                for enc_name, constructor in constructors.items():
                    if enc_name in ENCODING_CONSTRUCTORS:
                        raise ValueError(
                            f"Duplicate encoding name {enc_name} in tiktoken plugin {mod_name}"
                        )
                    ENCODING_CONSTRUCTORS[enc_name] = constructor
        except Exception:
            # Ensure we idempotently raise errors
            ENCODING_CONSTRUCTORS = None
            raise




def get_encoding(encoding_name: str) -> Encoding:
    if not isinstance(encoding_name, str):
        raise ValueError(f"Expected a string in get_encoding, got {type(encoding_name)}")

    if encoding_name in ENCODINGS:
        return ENCODINGS[encoding_name]

    with _lock:
        if encoding_name in ENCODINGS:
            return ENCODINGS[encoding_name]

        if ENCODING_CONSTRUCTORS is None:
            _find_constructors()
            assert ENCODING_CONSTRUCTORS is not None

        if encoding_name not in ENCODING_CONSTRUCTORS:
            raise ValueError(
                f"Unknown encoding {encoding_name}.\n"
                f"Plugins found: {_available_plugin_modules()}\n"
                f"tiktoken version: {tiktoken.__version__} (are you on latest?)"
            )

        constructor = ENCODING_CONSTRUCTORS[encoding_name]
        enc = Encoding(**constructor())
        ENCODINGS[encoding_name] = enc
        return enc


def list_encoding_names() -> list[str]:
    with _lock:
        if ENCODING_CONSTRUCTORS is None:
            _find_constructors()
            assert ENCODING_CONSTRUCTORS is not None
        return list(ENCODING_CONSTRUCTORS)



---
File: /tiktoken_ext/openai_public.py
---

from tiktoken.load import data_gym_to_mergeable_bpe_ranks, load_tiktoken_bpe

ENDOFTEXT = "<|endoftext|>"
FIM_PREFIX = "<|fim_prefix|>"
FIM_MIDDLE = "<|fim_middle|>"
FIM_SUFFIX = "<|fim_suffix|>"
ENDOFPROMPT = "<|endofprompt|>"

# The pattern in the original GPT-2 release is:
# r"""'s|'t|'re|'ve|'m|'ll|'d| ?[\p{L}]+| ?[\p{N}]+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"""
# This is equivalent, but executes faster:
r50k_pat_str = (
    r"""'(?:[sdmt]|ll|ve|re)| ?\p{L}++| ?\p{N}++| ?[^\s\p{L}\p{N}]++|\s++$|\s+(?!\S)|\s"""
)


def gpt2():
    mergeable_ranks = data_gym_to_mergeable_bpe_ranks(
        vocab_bpe_file="https://openaipublic.blob.core.windows.net/gpt-2/encodings/main/vocab.bpe",
        encoder_json_file="https://openaipublic.blob.core.windows.net/gpt-2/encodings/main/encoder.json",
        vocab_bpe_hash="1ce1664773c50f3e0cc8842619a93edc4624525b728b188a9e0be33b7726adc5",
        encoder_json_hash="196139668be63f3b5d6574427317ae82f612a97c5d1cdaf36ed2256dbf636783",
    )
    return {
        "name": "gpt2",
        "explicit_n_vocab": 50257,
        "pat_str": r50k_pat_str,
        "mergeable_ranks": mergeable_ranks,
        "special_tokens": {ENDOFTEXT: 50256},
    }


def r50k_base():
    mergeable_ranks = load_tiktoken_bpe(
        "https://openaipublic.blob.core.windows.net/encodings/r50k_base.tiktoken",
        expected_hash="306cd27f03c1a714eca7108e03d66b7dc042abe8c258b44c199a7ed9838dd930",
    )
    return {
        "name": "r50k_base",
        "explicit_n_vocab": 50257,
        "pat_str": r50k_pat_str,
        "mergeable_ranks": mergeable_ranks,
        "special_tokens": {ENDOFTEXT: 50256},
    }


def p50k_base():
    mergeable_ranks = load_tiktoken_bpe(
        "https://openaipublic.blob.core.windows.net/encodings/p50k_base.tiktoken",
        expected_hash="94b5ca7dff4d00767bc256fdd1b27e5b17361d7b8a5f968547f9f23eb70d2069",
    )
    return {
        "name": "p50k_base",
        "explicit_n_vocab": 50281,
        "pat_str": r50k_pat_str,
        "mergeable_ranks": mergeable_ranks,
        "special_tokens": {ENDOFTEXT: 50256},
    }


def p50k_edit():
    mergeable_ranks = load_tiktoken_bpe(
        "https://openaipublic.blob.core.windows.net/encodings/p50k_base.tiktoken",
        expected_hash="94b5ca7dff4d00767bc256fdd1b27e5b17361d7b8a5f968547f9f23eb70d2069",
    )
    special_tokens = {ENDOFTEXT: 50256, FIM_PREFIX: 50281, FIM_MIDDLE: 50282, FIM_SUFFIX: 50283}
    return {
        "name": "p50k_edit",
        "pat_str": r50k_pat_str,
        "mergeable_ranks": mergeable_ranks,
        "special_tokens": special_tokens,
    }


def cl100k_base():
    mergeable_ranks = load_tiktoken_bpe(
        "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken",
        expected_hash="223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7",
    )
    special_tokens = {
        ENDOFTEXT: 100257,
        FIM_PREFIX: 100258,
        FIM_MIDDLE: 100259,
        FIM_SUFFIX: 100260,
        ENDOFPROMPT: 100276,
    }
    return {
        "name": "cl100k_base",
        "pat_str": r"""'(?i:[sdmt]|ll|ve|re)|[^\r\n\p{L}\p{N}]?+\p{L}++|\p{N}{1,3}+| ?[^\s\p{L}\p{N}]++[\r\n]*+|\s++$|\s*[\r\n]|\s+(?!\S)|\s""",
        "mergeable_ranks": mergeable_ranks,
        "special_tokens": special_tokens,
    }


def o200k_base():
    mergeable_ranks = load_tiktoken_bpe(
        "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken",
        expected_hash="446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d",
    )
    special_tokens = {ENDOFTEXT: 199999, ENDOFPROMPT: 200018}
    # This regex could be made more efficient. If I was the one working on this encoding, I would
    # have done a few other things differently too, e.g. I think you can allocate tokens more
    # efficiently across languages.
    pat_str = "|".join(
        [
            r"""[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]*[\p{Ll}\p{Lm}\p{Lo}\p{M}]+(?i:'s|'t|'re|'ve|'m|'ll|'d)?""",
            r"""[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]+[\p{Ll}\p{Lm}\p{Lo}\p{M}]*(?i:'s|'t|'re|'ve|'m|'ll|'d)?""",
            r"""\p{N}{1,3}""",
            r""" ?[^\s\p{L}\p{N}]+[\r\n/]*""",
            r"""\s*[\r\n]+""",
            r"""\s+(?!\S)""",
            r"""\s+""",
        ]
    )
    return {
        "name": "o200k_base",
        "pat_str": pat_str,
        "mergeable_ranks": mergeable_ranks,
        "special_tokens": special_tokens,
    }


ENCODING_CONSTRUCTORS = {
    "gpt2": gpt2,
    "r50k_base": r50k_base,
    "p50k_base": p50k_base,
    "p50k_edit": p50k_edit,
    "cl100k_base": cl100k_base,
    "o200k_base": o200k_base,
}



---
File: /setup.py
---

from setuptools import setup
from setuptools_rust import Binding, RustExtension

setup(
    name="tiktoken",
    rust_extensions=[
        RustExtension(
            "tiktoken._tiktoken",
            binding=Binding.PyO3,
            # Between our use of editable installs and wanting to use Rust for performance sensitive
            # code, it makes sense to just always use --release
            debug=False,
            features=["python"],
        )
    ],
    package_data={"tiktoken": ["py.typed"]},
    packages=["tiktoken", "tiktoken_ext"],
    zip_safe=False,
)

