import copy
import unittest
from .evidence import validate


def receipt():
    current, previous = 'a' * 40, 'b' * 40
    return {
        'status': 'PASS', 'current': current, 'previous': previous,
        'preflight': {'read_only': True, 'signed_bundles': True,
                      'digest_only': True, 'compatible': True},
        'observations': [
            {'phase': phase, 'browser': browser, 'authenticated': True,
             'banner': maintenance, 'admission': 503 if maintenance else 201,
             'login_status': 503 if maintenance else None if phase == 'previous' else 204,
             'revision': previous if phase in ('previous', 'restore_maintenance') else current}
            for phase, maintenance in [('baseline', False), ('rollback_maintenance', True),
                                       ('previous', False), ('restore_maintenance', True),
                                       ('restored', False)]
            for browser in range(2)],
        'storage': [
            {'phase': phase,
             'volumes': {n: 'c' * 64 for n in ('postgres-data', 'attachments-data', 'caddy-data', 'caddy-config')},
             'networks': {n: 'd' * 64 for n in ('edge', 'private', 'sfu-egress')},
             'content': {n: 'e' * 64 for n in ('database', 'attachments', 'tls', 'proxy_config', 'schema')}}
            for phase in ('baseline', 'previous', 'restored')],
        'running': [
            {'phase': phase, 'revision': previous if phase == 'previous' else current,
             'images': {n: {'configured': 'voice-platform-' + n + '@sha256:' + 'f' * 64,
                           'running': 'sha256:' + 'f' * 64}
                        for n in ('api', 'web')}}
            for phase in ('baseline', 'previous', 'restored')],
        'observer_seconds': 30,
    }


class AcceptanceTests(unittest.TestCase):
    def test_requires_both_browsers_and_both_real_transitions(self):
        validate(receipt())
        for mode in ('missing', 'duplicate', 'no_banner', 'no_denial', 'login_allowed', 'no_positive', 'lost_auth', 'short_observation', 'unsigned', 'write_preflight', 'numeric_claim', 'malformed', 'same_revision', 'unknown_field'):
            value = receipt()
            if mode == 'missing': value['observations'].pop()
            if mode == 'duplicate': value['observations'][1] = value['observations'][0]
            if mode == 'no_banner': value['observations'][2]['banner'] = False
            if mode == 'no_denial': value['observations'][2]['admission'] = 201
            if mode == 'login_allowed': value['observations'][2]['login_status'] = 204
            if mode == 'no_positive': value['observations'][0]['admission'] = 403
            if mode == 'lost_auth': value['observations'][0]['authenticated'] = False
            if mode == 'short_observation': value['observer_seconds'] = 29
            if mode == 'unsigned': value['preflight']['signed_bundles'] = False
            if mode == 'write_preflight': value['preflight']['read_only'] = False
            if mode == 'numeric_claim': value['preflight']['signed_bundles'] = 1
            if mode == 'malformed': value['storage'] = None
            if mode == 'same_revision': value['previous'] = value['current']
            if mode == 'unknown_field': value['observations'][0]['cookie'] = 'forbidden'
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate(value)

    def test_rejects_storage_schema_or_network_drift(self):
        for section in ('volumes', 'networks', 'content'):
            value = receipt()
            key = next(iter(value['storage'][1][section]))
            value['storage'][1][section][key] = '0' * 64
            with self.subTest(section=section), self.assertRaises(ValueError): validate(value)
        for mode in ('missing', 'duplicate', 'malformed'):
            value = receipt()
            if mode == 'missing': value['storage'].pop()
            if mode == 'duplicate': value['storage'][1] = copy.deepcopy(value['storage'][0])
            if mode == 'malformed': value['storage'][0]['content']['database'] = 'not-a-digest'
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate(value)
        value = receipt()
        del value['storage'][1]['networks']['sfu-egress']
        with self.assertRaises(ValueError): validate(value)

    def test_rejects_tag_fallback_and_wrong_running_image(self):
        for mode in ('tag', 'wrong_image', 'wrong_revision', 'missing', 'duplicate'):
            value = receipt()
            if mode == 'tag': value['running'][1]['images']['api']['configured'] = 'voice-platform-api:mutable'
            if mode == 'wrong_image': value['running'][1]['images']['api']['running'] = 'sha256:' + '0' * 64
            if mode == 'wrong_revision': value['running'][1]['revision'] = value['current']
            if mode == 'missing': value['running'].pop()
            if mode == 'duplicate': value['running'][1] = copy.deepcopy(value['running'][0])
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate(value)
