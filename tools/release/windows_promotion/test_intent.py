"""Only the Windows stable selector can change, with a strict monotonic revision."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from . import intent


def catalogs():
    target={'release_id':'windows-direct-stable-r53','release_order':53,'version':'1.0.39','native_build':'72',
      'priority':'normal','action':{'kind':'open_download_page','url':'https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v1.0.39'}}
    before={'schema_version':1,'catalog_revision':29,'application_family':'boohtacord','entries':[
      dict(zip(intent.SELECTOR,['windows','direct','stable','x64']),state='unconfigured',target=None),
      dict(zip(intent.SELECTOR,['android','direct','stable','arm64']),state='unconfigured',target=None)]}
    after=copy.deepcopy(before);after['catalog_revision']=30;after['entries'][0].update(state='published',target=target)
    return before,after


class IntentTests(unittest.TestCase):
    def test_exact_delta_is_source_and_asset_bound(self):
        before,after=catalogs();record=intent.create(intent.raw(before),intent.raw(after),'a'*40,
          {'tag':'windows-v1.0.39','source_revision':'b'*40,'manifest_sha256':'c'*64,'archive_sha256':'d'*64,'checksums_sha256':'e'*64,'asset_inventory_sha256':'f'*64})
        intent.validate(record,intent.raw(before),intent.raw(after))
        self.assertIn('windows-v1.0.39',intent.branch(record))
        self.assertEqual(intent.identifier(record),intent.identifier(copy.deepcopy(record)))
        for change in ('other-platform','revision','selector','downgrade','native-build','version'):
            b,a=copy.deepcopy((before,after))
            if change=='other-platform':a['entries'][1]['state']='disabled'
            if change=='revision':a['catalog_revision']=29
            if change=='selector':a['entries'][0]['arch']='arm64'
            if change in ('downgrade','native-build','version'):
                b['entries'][0].update(state='published',target=copy.deepcopy(a['entries'][0]['target']))
                b['entries'][0]['target'].update(release_id='windows-direct-stable-r52',release_order=52,version='1.0.38',native_build='71')
                field={'downgrade':'release_order','native-build':'native_build','version':'version'}[change]
                a['entries'][0]['target'][field]={'downgrade':51,'native-build':'70','version':'1.0.37'}[change]
            with self.subTest(change=change),self.assertRaises(ValueError):intent.validate(record,intent.raw(b),intent.raw(a))

    def test_checksum_or_tag_mismatch_cannot_pass_even_with_same_target(self):
        before,after=catalogs();record=intent.create(intent.raw(before),intent.raw(after),'a'*40,
          {'tag':'windows-v1.0.39','source_revision':'b'*40,'manifest_sha256':'c'*64,'archive_sha256':'d'*64,'checksums_sha256':'e'*64,'asset_inventory_sha256':'f'*64})
        for field in ('tag','source_revision','manifest_sha256'):
            broken=copy.deepcopy(record);broken['release'][field]='bad'
            with self.subTest(field=field),self.assertRaises(ValueError):intent.validate(broken,intent.raw(before),intent.raw(after))
