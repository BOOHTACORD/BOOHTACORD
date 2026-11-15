import json
from pathlib import Path
import pytest
from tools.audio.release_notices.collect import collect


def metadata(tmp_path, license='MIT'):
    crate = tmp_path / 'crate'
    crate.mkdir()
    (crate / 'Cargo.toml').write_text('[package]\nname="example"\nlicense="MIT"\n')
    return {'packages': [{'id': 'pkg1', 'name': 'example', 'version': '1.0.0',
             'license': license, 'authors': ['Original Author'],
             'manifest_path': str(crate / 'Cargo.toml')}],
            'resolve': {'nodes': [{'id': 'pkg1'}]}}


def test_preserves_original_notice_and_records_its_digest(tmp_path):
    data = metadata(tmp_path)
    notice = Path(data['packages'][0]['manifest_path']).with_name('LICENSE')
    notice.write_text('Original permission and copyright notice')
    output = tmp_path / 'notices'
    result = collect(data, output)
    assert result['packages'] == 1 and result['unresolved'] == []
    assert (output / 'example-1.0.0/LICENSE').read_bytes() == notice.read_bytes()
    index = json.loads((output / 'index.json').read_text())
    assert index['entries'][0]['authors'] == ['Original Author']
    assert len(index['entries'][0]['notices']['LICENSE']) == 64


def test_missing_notice_fails_before_creating_delivery(tmp_path):
    output = tmp_path / 'notices'
    with pytest.raises(ValueError, match='Missing original notice'):
        collect(metadata(tmp_path), output)
    assert not output.exists()


def test_unaudited_license_is_not_silently_treated_as_mit(tmp_path):
    output = tmp_path / 'notices'
    with pytest.raises(ValueError, match='Unaudited license'):
        collect(metadata(tmp_path, 'LicenseRef-Unknown'), output)
    assert not output.exists()


def test_existing_output_is_not_overwritten(tmp_path):
    output = tmp_path / 'notices'
    output.mkdir()
    (output / 'preserve').write_text('existing data')
    with pytest.raises(ValueError, match='already exists'):
        collect(metadata(tmp_path), output)
    assert (output / 'preserve').read_text() == 'existing data'
