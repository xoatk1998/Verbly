#!/usr/bin/env python3
"""
Replace placeholder example sentences ("This is an example for X.")
with real sentences from the Free Dictionary API or Tatoeba.
Run this AFTER fetch_words.py has finished.
"""

import csv, json, time, urllib.request, urllib.parse, urllib.error
from pathlib import Path

CSV_PATH  = Path(__file__).parent / "sample.csv"
DICT_API  = "https://api.dictionaryapi.dev/api/v2/entries/en"
TATOEBA   = "https://tatoeba.org/en/api_v0/search"


def is_placeholder(sentence: str, word: str) -> bool:
    s = sentence.strip().lower().rstrip(".")
    return s == f"this is an example for {word.lower()}"


def fetch_example_dict(word: str) -> str | None:
    """Try Free Dictionary API for an example sentence."""
    url = f"{DICT_API}/{urllib.parse.quote(word)}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            for entry in data:
                for meaning in entry.get("meanings", []):
                    for defn in meaning.get("definitions", []):
                        ex = defn.get("example", "").strip()
                        if ex:
                            # Capitalise first letter, ensure ends with period
                            ex = ex[0].upper() + ex[1:]
                            if not ex.endswith((".", "!", "?")):
                                ex += "."
                            return ex
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"  DICT HTTP {e.code} for '{word}'", flush=True)
    except Exception as e:
        print(f"  DICT error for '{word}': {e}", flush=True)
    return None


def fetch_example_tatoeba(word: str) -> str | None:
    """Fallback: Tatoeba sentence search."""
    params = urllib.parse.urlencode({
        "from": "eng",
        "query": word,
        "limit": 5,
    })
    url = f"{TATOEBA}?{params}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            for result in data.get("results", []):
                text = result.get("text", "").strip()
                # Pick a sentence that contains the word and is a reasonable length
                if (word.lower() in text.lower()
                        and 10 < len(text) < 120
                        and not text.startswith("(")):
                    if not text.endswith((".", "!", "?")):
                        text += "."
                    return text
    except Exception as e:
        print(f"  TATOEBA error for '{word}': {e}", flush=True)
    return None


def main():
    rows = []
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    targets = [r for r in rows if is_placeholder(r["exampleSentence"], r["english"])]
    total = len(targets)
    print(f"Found {total} placeholder example sentences to fix.\n", flush=True)

    cache: dict[str, str | None] = {}
    fixed = 0
    no_example = []

    for i, row in enumerate(targets, 1):
        word = row["english"].strip()

        if word not in cache:
            example = fetch_example_dict(word)
            if not example:
                example = fetch_example_tatoeba(word)
            cache[word] = example
            time.sleep(0.25)
        else:
            example = cache[word]

        if example:
            row["exampleSentence"] = example
            fixed += 1
            print(f"[{i}/{total}] {word}: {example[:90]}", flush=True)
        else:
            no_example.append(word)
            print(f"[{i}/{total}] {word}: no example found (keeping placeholder)", flush=True)

        if i % 100 == 0:
            _write_csv(CSV_PATH, fieldnames, rows)
            print(f"  -- Progress saved ({i}/{total}) --\n", flush=True)

    _write_csv(CSV_PATH, fieldnames, rows)
    print(f"\nDone. Fixed: {fixed}/{total}. No example found: {len(no_example)}")
    if no_example:
        print("Words without examples:", ", ".join(no_example[:50]))


def _write_csv(path, fieldnames, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
