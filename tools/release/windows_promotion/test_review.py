"""Repeat dispatch reuses only its own branch; another pending promotion conflicts."""
import json
import unittest
from unittest.mock import patch
from .prepare import open_reviews


class ReviewTests(unittest.TestCase):
    def test_repeat_is_identifiable_without_accepting_another_pending_promotion(self):
        branch='codex/windows-catalog-windows-v1.0.39-abc'
        row={'headRefName':branch,'headRefOid':'a'*40,'url':'https://github.com/Egkurilov/BOOHTACORD/pull/1'}
        with patch('tools.release.windows_promotion.prepare.command',return_value=json.dumps([row])):
            self.assertEqual(open_reviews(branch),[row])
            with self.assertRaises(ValueError):open_reviews('codex/windows-catalog-windows-v1.0.40-other')
        with patch('tools.release.windows_promotion.prepare.command',return_value=json.dumps([row,row])):
            with self.assertRaises(ValueError):open_reviews(branch)
