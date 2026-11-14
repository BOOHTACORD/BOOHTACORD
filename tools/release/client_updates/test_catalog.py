import json
from tools.release.client_updates.catalog import mutate


def source(tmp_path, current_target=None):
    path = tmp_path / "catalog.json"
    entry = {"platform":"windows","distribution":"direct","channel":"stable","arch":"x64",
             "state":"published" if current_target else "unconfigured","target":current_target}
    path.write_text(json.dumps({"schema_version":1,"catalog_revision":4,"application_family":"boohtacord","entries":[entry]}), encoding="utf-8")
    return path


def target():
    return {"release_id":"windows-5","release_order":5,"version":"1.0.0","native_build":"5","priority":"normal","published_at":"2026-10-02T18:00:00Z","summary":"Windows","release_notes_url":"/releases/windows-5","requirements":{"supported_arches":["x64"]},"action":{"kind":"open_download_page","url":"/downloads/windows-5"}}


def test_promote_and_withdraw_are_revision_guarded(tmp_path):
    path = source(tmp_path); selector = ("windows","direct","stable","x64")
    mutate(path, 4, selector, "published", target())
    promoted = json.loads(path.read_text(encoding="utf-8"))
    assert promoted["catalog_revision"] == 5 and promoted["entries"][0]["state"] == "published"
    mutate(path, 5, selector, "unconfigured", None)
    assert json.loads(path.read_text(encoding="utf-8"))["catalog_revision"] == 6


def test_rejects_stale_revision(tmp_path):
    path = source(tmp_path)
    try: mutate(path, 3, ("windows","direct","stable","x64"), "published", target())
    except ValueError as error: assert "revision" in str(error)
    else: raise AssertionError("stale writer accepted")


def test_publisher_lock_rejects_a_concurrent_writer(tmp_path):
    path = source(tmp_path)
    path.with_suffix('.json.lock').write_text('busy', encoding='utf-8')
    try: mutate(path, 4, ("windows","direct","stable","x64"), "published", target())
    except ValueError as error: assert "publisher" in str(error)
    else: raise AssertionError("concurrent writer accepted")


def test_rejects_late_release_promotion_that_would_downgrade_catalog(tmp_path):
    current = target() | {"release_id":"windows-direct-stable-r52", "release_order":52,
                          "version":"1.0.38", "native_build":"71"}
    stale = target() | {"release_id":"windows-direct-stable-r46", "release_order":46,
                        "version":"1.0.32", "native_build":"46"}
    path = source(tmp_path, current)

    try:
        mutate(path, 4, ("windows","direct","stable","x64"), "published", stale)
    except ValueError as error:
        assert "regress" in str(error)
    else:
        raise AssertionError("older release replaced the newer catalog target")

    document = json.loads(path.read_text(encoding="utf-8"))
    assert document["catalog_revision"] == 4
    assert document["entries"][0]["target"]["release_id"] == "windows-direct-stable-r52"


def test_rejects_conflicting_identity_with_same_release_order(tmp_path):
    current = target() | {"release_id":"windows-direct-stable-r52", "release_order":52,
                          "version":"1.0.38", "native_build":"71"}
    conflict = current | {"release_id":"windows-direct-stable-r53"}
    path = source(tmp_path, current)

    try:
        mutate(path, 4, ("windows","direct","stable","x64"), "published", conflict)
    except ValueError as error:
        assert "order" in str(error)
    else:
        raise AssertionError("different release identities shared one release order")


def test_rejects_same_release_id_with_conflicting_package_identity(tmp_path):
    current = target() | {"release_id":"windows-direct-stable-r52", "release_order":52,
                          "version":"1.0.38", "native_build":"71"}
    conflict = current | {"version":"1.0.39", "native_build":"72"}
    path = source(tmp_path, current)

    try:
        mutate(path, 4, ("windows","direct","stable","x64"), "published", conflict)
    except ValueError as error:
        assert "identity" in str(error)
    else:
        raise AssertionError("one release ID was allowed to identify conflicting packages")


def test_current_windows_catalog_keeps_download_and_identity_consistent():
    from pathlib import Path
    import re
    from tools.release.client_updates.catalog import load

    repository = Path(__file__).resolve().parents[3]
    catalog = load(repository / "deploy/client-updates/catalog.json")
    windows = next(entry for entry in catalog["entries"] if entry["platform"] == "windows")
    assert windows["state"] == "published" and windows["arch"] == "x64"
    current = windows["target"]
    assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", current["version"])
    assert current["release_id"] == f'windows-direct-stable-r{current["release_order"]}'
    assert current["native_build"].isdigit()
    release = "https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v" + current["version"]
    assert current["release_notes_url"] == release
    assert current["action"] == {"kind": "open_download_page", "url": release}
    assert current["requirements"]["supported_arches"] == ["x64"]


def test_repeating_identical_promotion_does_not_advance_catalog_revision(tmp_path):
    current = target() | {"release_id": "windows-direct-stable-r5", "release_order": 5}
    path = source(tmp_path, current)
    document = mutate(path, 4, ("windows", "direct", "stable", "x64"), "published", current)
    assert document["catalog_revision"] == 4
    assert json.loads(path.read_text(encoding="utf-8"))["catalog_revision"] == 4
