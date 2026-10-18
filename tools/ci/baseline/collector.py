import json
import os
import re
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .metrics import duration_seconds


API_ROOT = "https://api.github.com/repos"
PER_PAGE = 100
RELEASES = {
    ".github/workflows/android-release.yaml": ("android", re.compile(r"^android-v\d")),
    ".github/workflows/windows-release.yaml": ("windows", re.compile(r"^windows-v\d")),
    ".github/workflows/macos-release.yaml": ("macos", re.compile(r"^macos-v\d")),
}


class GitHubAPI:
    def __init__(self, repository, token=None):
        self.repository = repository
        self.base = f"{API_ROOT}/{repository}"
        self.token = token or os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")

    def get(self, path, params=None):
        query = urlencode(params or {})
        url = f"{self.base}{path}" + (f"?{query}" if query else "")
        headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "boohtacord-ci-baseline",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        request = Request(url, headers=headers, method="GET")
        try:
            with urlopen(request, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            raise RuntimeError(
                f"GitHub API GET {path} failed with HTTP {error.code}"
            ) from None
        except (URLError, TimeoutError, json.JSONDecodeError) as error:
            raise RuntimeError(
                f"GitHub API GET {path} failed: {type(error).__name__}"
            ) from None

    def pages(self, path, collection_key, params=None, max_pages=100):
        rows = []
        base_params = dict(params or {})
        base_params.setdefault("per_page", PER_PAGE)
        for page in range(1, max_pages + 1):
            payload = self.get(path, dict(base_params, page=page))
            values = payload.get(collection_key, [])
            if not isinstance(values, list):
                raise RuntimeError(f"GitHub API response omitted {collection_key}")
            rows.extend(values)
            total = payload.get("total_count")
            if not values or len(values) < base_params["per_page"]:
                break
            if isinstance(total, int) and len(rows) >= total:
                break
        return rows


def trigger_class(run):
    event = run.get("event") or "unknown"
    branch = run.get("head_branch") or ""
    if event == "pull_request":
        return "pull_request"
    if event == "push" and branch == "master":
        return "push_master"
    if event == "push" and any(pattern.match(branch) for _, pattern in RELEASES.values()):
        return "push_tag"
    if event == "workflow_dispatch":
        return "manual"
    if event == "workflow_run":
        return "workflow_run"
    return event


def changed_components(paths):
    result = set()
    for path in paths:
        if path.startswith("backend/"):
            result.add("backend")
        elif path.startswith("clients/web/"):
            result.add("web")
        elif path.startswith("clients/flutter/android/"):
            result.update(("flutter", "android"))
        elif path.startswith("clients/flutter/windows/"):
            result.update(("flutter", "windows"))
        elif path.startswith("clients/flutter/macos/"):
            result.update(("flutter", "macos"))
        elif path.startswith("clients/flutter/ios/"):
            result.update(("flutter", "ios"))
        elif path.startswith("clients/flutter/"):
            result.add("flutter")
        elif path.startswith(".github/workflows/") or path.startswith("tools/ci/"):
            result.add("ci")
        elif path.startswith(("tools/release/", "tools/build/", "tools/deploy/", "deploy/")):
            result.add("delivery")
        elif path.startswith("contracts/"):
            result.add("contracts")
        elif path.startswith(("docs/", "evidence/")):
            result.add("docs_evidence")
        else:
            result.add("shared")
    return sorted(result)


def _safe_runner_labels(labels):
    safe = set()
    for value in labels:
        label = str(value).lower()
        if label == "self-hosted" or label in {"linux", "windows", "macos"}:
            safe.add(label)
        elif label.startswith(("ubuntu-", "windows-", "macos-")):
            safe.add(label)
    return sorted(safe)


def _platforms(jobs, workflow_path):
    result = set()
    for job in jobs:
        labels = [str(label).lower() for label in job.get("labels", [])]
        for label in labels:
            if "windows" in label:
                result.add("windows")
            elif label.startswith("macos-"):
                result.add("macos")
            elif label.startswith(("ubuntu", "linux")):
                result.add("linux")
        if "self-hosted" in labels:
            result.add("self_hosted")
    release = RELEASES.get(workflow_path)
    if release:
        result.add(release[0])
    return sorted(result)


def _file_paths(api, run, file_cache):
    sha = run.get("head_sha")
    if not sha:
        return [], "unavailable"
    is_pull_request = run.get("event") == "pull_request"
    cache_key = (sha, is_pull_request)
    if cache_key in file_cache:
        return file_cache[cache_key]

    paths = []
    source = "commit"
    try:
        if is_pull_request:
            linked = api.get(f"/commits/{sha}/pulls", {"per_page": PER_PAGE})
            if isinstance(linked, list) and linked:
                match = next(
                    (
                        item for item in linked
                        if (item.get("head") or {}).get("sha") == sha
                    ),
                    linked[0],
                )
                number = match.get("number")
                if number:
                    files = api.pages(
                        f"/pulls/{number}/files",
                        "files",
                        {"per_page": PER_PAGE},
                    )
                    paths = [
                        item.get("filename", "")
                        for item in files
                        if item.get("filename")
                    ]
                    source = "pull_request"
        if not paths:
            commit = api.get(f"/commits/{sha}")
            paths = [
                item.get("filename", "")
                for item in commit.get("files", [])
                if item.get("filename")
            ]
            source = "commit"
    except RuntimeError:
        paths, source = [], "unavailable"

    value = (paths, source)
    file_cache[cache_key] = value
    return value


def _completed_at(run, jobs):
    values = [job.get("completed_at") for job in jobs if job.get("completed_at")]
    if values:
        return max(values)
    if run.get("status") == "completed":
        return run.get("updated_at")
    return None


def collect_run(api, raw_run, file_cache):
    run_id = raw_run["id"]
    jobs_raw = api.pages(f"/actions/runs/{run_id}/jobs", "jobs", {"per_page": PER_PAGE})
    artifacts_raw = api.pages(
        f"/actions/runs/{run_id}/artifacts",
        "artifacts",
        {"per_page": PER_PAGE},
    )

    jobs = []
    for job in jobs_raw:
        steps = []
        for step in job.get("steps", []):
            name = step.get("name") or "unnamed"
            steps.append(
                {
                    "name": name,
                    "status": step.get("status"),
                    "conclusion": step.get("conclusion"),
                    "duration_seconds": duration_seconds(
                        step.get("started_at"), step.get("completed_at")
                    ),
                }
            )
        raw_labels = sorted({str(label) for label in job.get("labels", [])})
        labels = _safe_runner_labels(raw_labels)
        jobs.append(
            {
                "name": job.get("name") or "unnamed",
                "status": job.get("status"),
                "conclusion": job.get("conclusion"),
                "created_at": job.get("created_at"),
                "started_at": job.get("started_at"),
                "completed_at": job.get("completed_at"),
                "queue_seconds": duration_seconds(
                    job.get("created_at"), job.get("started_at")
                ),
                "duration_seconds": duration_seconds(
                    job.get("started_at"), job.get("completed_at")
                ),
                "runner_class": "self_hosted" if "self-hosted" in raw_labels else "hosted",
                "runner_labels": labels,
                "runner_temperature": None,
                "steps": steps,
            }
        )

    paths, path_source = _file_paths(api, raw_run, file_cache)
    download_counts = [
        item.get("download_count")
        for item in artifacts_raw
        if isinstance(item.get("download_count"), int)
    ]
    artifacts = {
        "available": True,
        "count": len(artifacts_raw),
        "size_bytes": sum(item.get("size_in_bytes", 0) for item in artifacts_raw),
        "download_count": (
            sum(download_counts) if len(download_counts) == len(artifacts_raw) else None
        ),
    }
    run_started_at = raw_run.get("run_started_at") or min(
        (job.get("started_at") for job in jobs if job.get("started_at")),
        default=None,
    )
    completed_at = _completed_at(raw_run, jobs)
    workflow_path = raw_run.get("path", "")
    return {
        "run_id": run_id,
        "workflow": raw_run.get("name") or workflow_path,
        "workflow_path": workflow_path,
        "event": raw_run.get("event"),
        "trigger_class": trigger_class(raw_run),
        "status": raw_run.get("status"),
        "conclusion": raw_run.get("conclusion"),
        "run_attempt": raw_run.get("run_attempt", 1),
        "head_sha": raw_run.get("head_sha"),
        "head_sha_short": (raw_run.get("head_sha") or "")[:12],
        "created_at": raw_run.get("created_at"),
        "run_started_at": run_started_at,
        "completed_at": completed_at,
        "run_queue_seconds": duration_seconds(raw_run.get("created_at"), run_started_at),
        "elapsed_seconds": duration_seconds(raw_run.get("created_at"), completed_at),
        "wall_seconds": duration_seconds(run_started_at, completed_at),
        "url": raw_run.get("html_url"),
        "changed_components": changed_components(paths) if paths else ["unknown"],
        "change_source": path_source,
        "platforms": _platforms(jobs_raw, workflow_path),
        "jobs": jobs,
        "artifacts": artifacts,
    }


def _list_until(api, event, branch=None, stop_when=None):
    params = {"status": "completed", "event": event}
    if branch:
        params["branch"] = branch
    rows = []
    total_count = None
    pages_scanned = 0
    for page in range(1, 101):
        payload = api.get("/actions/runs", dict(params, per_page=PER_PAGE, page=page))
        pages_scanned = page
        page_runs = payload.get("workflow_runs", [])
        rows.extend(page_runs)
        if isinstance(payload.get("total_count"), int):
            total_count = payload["total_count"]
        if stop_when and stop_when(rows):
            break
        if not page_runs or len(page_runs) < PER_PAGE:
            break
        if isinstance(total_count, int) and len(rows) >= total_count:
            break
    return {
        "runs": rows,
        "reported_total_count": total_count,
        "pages_scanned": pages_scanned,
        "records_returned": len(rows),
    }


def _matching_count(rows, workflow_path):
    return sum(
        1
        for run in rows
        if run.get("path") == workflow_path and run.get("status") == "completed"
    )


def collect_samples(api, sample_size=30):
    ci_path = ".github/workflows/ci.yaml"
    build_path = ".github/workflows/build-server.yaml"
    deploy_path = ".github/workflows/deploy-production.yaml"

    pr_scan = _list_until(
        api,
        "pull_request",
        stop_when=lambda rows: _matching_count(rows, ci_path) >= sample_size,
    )
    master_scan = _list_until(
        api,
        "push",
        branch="master",
        stop_when=lambda rows: (
            _matching_count(rows, ci_path) >= sample_size
            and _matching_count(rows, build_path) >= sample_size
        ),
    )
    deploy_scan = _list_until(
        api,
        "workflow_run",
        stop_when=lambda rows: _matching_count(rows, deploy_path) >= sample_size,
    )

    # Release workflows are sparse; scan the available push and manual histories once.
    all_push_scan = _list_until(api, "push")
    all_dispatch_scan = _list_until(api, "workflow_dispatch")
    pr_raw = pr_scan["runs"]
    master_raw = master_scan["runs"]
    deploy_raw = deploy_scan["runs"]
    all_push_raw = all_push_scan["runs"]
    all_dispatch_raw = all_dispatch_scan["runs"]

    populations = {
        "pr_required_gate": [
            run for run in pr_raw
            if run.get("path") == ci_path and run.get("status") == "completed"
        ][:sample_size],
        "master_ci": [
            run for run in master_raw
            if run.get("path") == ci_path and run.get("status") == "completed"
        ][:sample_size],
        "master_build_server": [
            run for run in master_raw
            if run.get("path") == build_path and run.get("status") == "completed"
        ][:sample_size],
        "deploy_production": [
            run for run in deploy_raw
            if run.get("path") == deploy_path and run.get("status") == "completed"
        ][:sample_size],
    }
    for workflow_path, (platform, tag_pattern) in RELEASES.items():
        native = [
            run
            for run in all_push_raw + all_dispatch_raw
            if run.get("path") == workflow_path
            and run.get("status") == "completed"
            and (
                run.get("event") == "workflow_dispatch"
                or tag_pattern.match(run.get("head_branch") or "")
            )
        ]
        native.sort(key=lambda run: run.get("created_at") or "", reverse=True)
        populations[f"native_release_{platform}"] = native[:sample_size]

    file_cache = {}
    selected = {
        name: [collect_run(api, run, file_cache) for run in runs]
        for name, runs in populations.items()
    }
    return {
        "sample_size_requested": sample_size,
        "populations": selected,
        "history": {
            "pull_request": {
                "records_returned": len(pr_raw),
                "reported_total_count": pr_scan["reported_total_count"],
                "pages_scanned": pr_scan["pages_scanned"],
            },
            "master_push": {
                "records_returned": len(master_raw),
                "reported_total_count": master_scan["reported_total_count"],
                "pages_scanned": master_scan["pages_scanned"],
            },
            "deploy_workflow_run": {
                "records_returned": len(deploy_raw),
                "reported_total_count": deploy_scan["reported_total_count"],
                "pages_scanned": deploy_scan["pages_scanned"],
            },
            "all_push_for_tags": {
                "records_returned": len(all_push_raw),
                "reported_total_count": all_push_scan["reported_total_count"],
                "pages_scanned": all_push_scan["pages_scanned"],
            },
            "workflow_dispatch": {
                "records_returned": len(all_dispatch_raw),
                "reported_total_count": all_dispatch_scan["reported_total_count"],
                "pages_scanned": all_dispatch_scan["pages_scanned"],
            },
        },
    }
