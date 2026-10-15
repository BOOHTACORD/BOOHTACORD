"""The public runtime-catalog schema must resolve the optional signed envelope."""
import json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator, ValidationError

ROOT = Path(__file__).resolve().parents[3]


def catalog(**extra):
    target = dict(release_id='macos-qa337-r58', release_order=58, version='1.0.44',
                  native_build='79', priority='normal', published_at='2026-10-15T00:00:00Z',
                  summary='QA schema fixture', release_notes_url=None,
                  requirements={'supported_arches': ['arm64']},
                  action={'kind': 'open_download_page', 'url': 'https://github.com/Egkurilov/BOOHTACORD/releases'},
                  **extra)
    return dict(schema_version=1, catalog_revision=2, application_family='boohtacord',
                entries=[dict(platform='macos', distribution='direct', channel='beta',
                              arch='arm64', state='published', target=target)])


def envelope():
    # Structural fixture only; crypto authenticity is covered by test_signing.
    return dict(schema_version=1, key_id='publisher', payload='e30=', signature='A' * 86 + '==')


def validator():
    return Draft202012Validator(json.loads((ROOT / 'contracts/client-release-catalog.schema.json').read_text()))


class CatalogSchemaTests(unittest.TestCase):
    def test_optional_install_envelope_resolves_in_public_catalog_schema(self):
        validator().validate(catalog(install_artifact=envelope()))
        validator().validate(catalog())

    def test_camel_case_internal_definition_cannot_be_used_as_a_target_field(self):
        with self.assertRaises(ValidationError):
            validator().validate(catalog(installArtifact=envelope()))
