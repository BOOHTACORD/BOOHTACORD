"""Real file reload, idempotence and competing promotions preserve other platforms."""
import copy
import json
from pathlib import Path
import tempfile
import threading
import unittest
from tools.release.client_updates.catalog import load, mutate
from .policy import SELECTOR
from .test_policy import policy


class CatalogPreservationTests(unittest.TestCase):
    def test_competing_publishers_reload_without_downgrading_or_changing_other_entries(self):
        with tempfile.TemporaryDirectory() as name:
            file=Path(name)/'catalog.json';next_target=policy()['target']
            old_target=next_target|{'version':'1.0.32','native_build':'46','release_order':46,
                                    'release_id':'windows-direct-stable-r46'}
            windows=dict(SELECTOR,state='published',target=old_target)
            other=[dict(SELECTOR,platform='android',arch='arm64',state='unconfigured',target=None),
                   dict(SELECTOR,platform='web',arch='any',state='unconfigured',target=None)]
            file.write_text(json.dumps({'schema_version':1,'application_family':'boohtacord',
                'catalog_revision':47,'entries':[windows,*other]}),encoding='utf-8')
            before=copy.deepcopy(other);barrier=threading.Barrier(2);outcomes=[]
            def publish():
                barrier.wait()
                try: mutate(file,47,tuple(SELECTOR.values()),'published',next_target);outcomes.append('published')
                except ValueError: outcomes.append('rejected')
            threads=[threading.Thread(target=publish) for _ in range(2)]
            for worker in threads: worker.start()
            for worker in threads: worker.join(timeout=5);self.assertFalse(worker.is_alive())
            self.assertCountEqual(outcomes,['published','rejected'])
            reloaded=load(file)
            self.assertEqual(reloaded['catalog_revision'],48)
            self.assertEqual(reloaded['entries'][1:],before)
            self.assertEqual(reloaded['entries'][0]['target'],next_target)
            raw=file.read_bytes()
            mutate(file,48,tuple(SELECTOR.values()),'published',next_target)
            self.assertEqual(file.read_bytes(),raw)
            with self.assertRaisesRegex(ValueError,'regress'):
                mutate(file,48,tuple(SELECTOR.values()),'published',old_target)
            self.assertEqual(file.read_bytes(),raw)
