#!/usr/bin/env python3
"""Unit tests for fetch_quranenc.parse_sura_response and aggregate.

Pure-unit, no network. Mocks the QuranEnc per-sura HTTP response.
"""
import json
import os
import unittest
from unittest import mock

import fetch_quranenc as fq


def _make_response(sura, n_ayahs):
    return {
        "result": [
            {"sura": sura, "aya": a, "translation": f"sura {sura} aya {a}"}
            for a in range(1, n_ayahs + 1)
        ]
    }


class TestParseSuraResponse(unittest.TestCase):

    def test_simple_sura(self):
        data = _make_response(1, 7)
        out = fq.parse_sura_response(data, 1)
        self.assertEqual(len(out), 7)
        self.assertEqual(out["1:1"], "sura 1 aya 1")
        self.assertEqual(out["1:7"], "sura 1 aya 7")

    def test_strips_whitespace(self):
        data = {"result": [{"sura": 1, "aya": 1, "translation": "  hello  \n"}]}
        out = fq.parse_sura_response(data, 1)
        self.assertEqual(out["1:1"], "hello")

    def test_empty_result_raises(self):
        with self.assertRaises(ValueError):
            fq.parse_sura_response({"result": []}, 1)

    def test_missing_translation_field_raises(self):
        bad = {"result": [{"sura": 1, "aya": 1}]}
        with self.assertRaises(KeyError):
            fq.parse_sura_response(bad, 1)

    def test_empty_translation_raises(self):
        bad = {"result": [{"sura": 1, "aya": 1, "translation": "   "}]}
        with self.assertRaises(ValueError):
            fq.parse_sura_response(bad, 1)

    def test_missing_result_key_raises(self):
        with self.assertRaises(KeyError):
            fq.parse_sura_response({}, 1)


class TestAggregate(unittest.TestCase):

    def test_full_quran_yields_6236(self):
        # Patch _fetch_sura to return synthetic per-sura responses based on the
        # canonical surah verse counts.
        verse_counts = fq.STANDARD_VERSE_COUNTS
        self.assertEqual(len(verse_counts), 114)
        self.assertEqual(sum(verse_counts), 6236)

        def fake_fetch(key, sura):
            return _make_response(sura, verse_counts[sura - 1])

        with mock.patch.object(fq, "_fetch_sura", side_effect=fake_fetch):
            with mock.patch.object(fq.time, "sleep", lambda *_: None):
                overlay = fq.aggregate("greek_rwwad")

        self.assertEqual(len(overlay), 6236)
        self.assertIn("1:1", overlay)
        self.assertIn("114:6", overlay)
        # Every key must be unique surah:ayah; spot-check a middle sura.
        self.assertEqual(overlay["2:286"], "sura 2 aya 286")

    def test_aggregate_raises_on_short_sura(self):
        verse_counts = list(fq.STANDARD_VERSE_COUNTS)

        def fake_fetch(key, sura):
            n = verse_counts[sura - 1]
            if sura == 1:
                n -= 1  # drop one verse
            return _make_response(sura, n)

        with mock.patch.object(fq, "_fetch_sura", side_effect=fake_fetch):
            with mock.patch.object(fq.time, "sleep", lambda *_: None):
                with self.assertRaises(ValueError) as ctx:
                    fq.aggregate("greek_rwwad")
        msg = str(ctx.exception).lower()
        self.assertIn("sura 1", msg)
        self.assertIn("expected 7", msg)


class TestRetry(unittest.TestCase):

    def test_retries_on_5xx_then_succeeds(self):
        good = _make_response(1, 7)
        attempts = {"n": 0}

        def fake_urlopen(url, timeout):
            attempts["n"] += 1
            if attempts["n"] == 1:
                # Simulate a transient 5xx by raising urllib HTTPError 503
                from urllib.error import HTTPError
                raise HTTPError(url, 503, "Service Unavailable", {}, None)

            class FakeResp:
                def __enter__(self_inner): return self_inner
                def __exit__(self_inner, *a): return False
                def read(self_inner): return json.dumps(good).encode("utf-8")
            return FakeResp()

        with mock.patch.object(fq.urllib.request, "urlopen", side_effect=fake_urlopen):
            with mock.patch.object(fq.time, "sleep", lambda *_: None):
                out = fq._fetch_sura("greek_rwwad", 1, use_cache=False)
        self.assertEqual(attempts["n"], 2)
        self.assertEqual(out, good)

    def test_raises_after_repeated_failures(self):
        from urllib.error import HTTPError

        def always_fail(url, timeout):
            raise HTTPError(url, 503, "Service Unavailable", {}, None)

        with mock.patch.object(fq.urllib.request, "urlopen", side_effect=always_fail):
            with mock.patch.object(fq.time, "sleep", lambda *_: None):
                with self.assertRaises(HTTPError):
                    fq._fetch_sura("greek_rwwad", 1, use_cache=False)


if __name__ == "__main__":
    unittest.main()
