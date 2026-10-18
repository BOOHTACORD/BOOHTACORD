from collections import defaultdict
from datetime import datetime, timezone

from .metrics import distribution, summarize_pr_green_cohorts, summarize_workflow_runs


POPULATION_LABELS = {
    "pr_required_gate": "PR required CI",
    "master_ci": "master CI",
    "master_build_server": "master Build server",
    "deploy_production": "production deploy",
    "native_release_android": "Android release",
    "native_release_windows": "Windows release",
    "native_release_macos": "macOS release",
}


def _job_breakdown(runs):
    groups = defaultdict(list)
    for run in runs:
        for job in run.get("jobs", []):
            if job.get("duration_seconds") is not None and job.get("conclusion") != "skipped":
                groups[job.get("name") or "unnamed"].append(job["duration_seconds"])
    return [
        {"name": name, **distribution(values)}
        for name, values in sorted(
            groups.items(),
            key=lambda item: distribution(item[1])["p95"] or 0,
            reverse=True,
        )
    ]


def _step_breakdown(runs):
    groups = defaultdict(list)
    for run in runs:
        for job in run.get("jobs", []):
            for step in job.get("steps", []):
                value = step.get("duration_seconds")
                if value is not None and step.get("conclusion") != "skipped":
                    groups[step.get("name") or "unnamed"].append(value)
    return [
        {"name": name, **distribution(values)}
        for name, values in sorted(
            groups.items(),
            key=lambda item: distribution(item[1])["p95"] or 0,
            reverse=True,
        )
    ]


def _elapsed(start, end):
    from .metrics import duration_seconds

    return duration_seconds(start, end)


def _pipeline_correlations(populations):
    builds = populations.get("master_build_server", [])
    deploys = populations.get("deploy_production", [])
    result = []
    successful_builds = [
        run for run in builds
        if run.get("conclusion") == "success" and run.get("head_sha")
    ]

    for deploy in deploys:
        if deploy.get("conclusion") != "success" or not deploy.get("head_sha"):
            continue
        matching = [
            run for run in successful_builds
            if run.get("head_sha") == deploy.get("head_sha")
            and run.get("completed_at")
            and run.get("completed_at") <= (deploy.get("created_at") or "")
        ]
        if not matching:
            continue
        build = max(matching, key=lambda run: run.get("completed_at") or "")
        health_steps = [
            step
            for job in deploy.get("jobs", [])
            for step in job.get("steps", [])
            if any(
                token in step.get("name", "").lower()
                for token in (
                    "health",
                    "readback",
                    "read-back",
                    "readiness",
                    "install the built bundle",
                )
            )
        ]
        health_step = max(
            health_steps,
            key=lambda step: step.get("completed_at") or "",
            default=None,
        )
        health_at = (health_step or {}).get("completed_at") or deploy.get("completed_at")
        ready_at = build.get("completed_at")
        result.append(
            {
                "source_sha": build.get("head_sha_short"),
                "build_run_id": build.get("run_id"),
                "build_run_url": build.get("url"),
                "deploy_run_id": deploy.get("run_id"),
                "deploy_run_url": deploy.get("url"),
                "artifact_ready_at": ready_at,
                "health_completed_at": health_at,
                "health_timestamp_source": (
                    "deploy health/readback step"
                    if health_step
                    else "deploy workflow completion proxy"
                ),
                "master_to_artifact_seconds": _elapsed(build.get("created_at"), ready_at),
                "artifact_to_health_seconds": _elapsed(ready_at, health_at),
                "master_to_health_seconds": _elapsed(build.get("created_at"), health_at),
            }
        )
    return result


def _recommendations(jobs, pr_green, correlations):
    pr_jobs = jobs.get("pr_required_gate", [])
    hotspots = [
        {"job": row["name"], "p95_seconds": row.get("p95"), "samples": row["count"]}
        for row in pr_jobs[:3]
        if row.get("p95") is not None
    ]
    return {
        "guardrails": [
            "Keep the required PR green-time p95 at or below the measured baseline while changing routing or parallelism.",
            "Do not skip a required job when the diff or selector result is unknown.",
            "Track runner minutes separately from workflow wall-clock; an optimization must report both.",
        ],
        "proven_hotspots": hotspots,
        "priority": (
            "Start with the slowest measured required PR job, then quantify repeated backend/web/contracts work on master."
            if hotspots
            else "Collect a larger sample before choosing a CI optimization."
        ),
        "numeric_reduction_target": (
            "Not set in this baseline; choose it after a before/after sample to avoid inventing a win."
        ),
        "deployment_pair_count": len(correlations),
        "pr_green_cohort_count": pr_green["green_cohort_count"],
        "pr_unresolved_cohort_count": pr_green["unresolved_cohort_count"],
    }


def build_report(collection, repository):
    generated_at = (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )
    populations = collection["populations"]
    summaries = {
        name: summarize_workflow_runs(runs)
        for name, runs in populations.items()
    }
    pr_green = summarize_pr_green_cohorts(populations.get("pr_required_gate", []))
    jobs = {
        name: _job_breakdown(runs)
        for name, runs in populations.items()
    }
    steps = {
        name: _step_breakdown(runs)
        for name, runs in populations.items()
    }
    correlations = _pipeline_correlations(populations)

    return {
        "schema_version": 1,
        "generated_at_utc": generated_at,
        "repository": repository,
        "collection": {
            "requested_completed_runs_per_population": collection["sample_size_requested"],
            "history": collection["history"],
            "selection": (
                "Newest completed workflow runs in each population; native release "
                "populations contain the available matching tag or manual runs."
            ),
            "timing_method": {
                "run_queue": "workflow created_at to first job start",
                "job_queue": "job created_at to started_at",
                "workflow_elapsed": "workflow created_at to latest job completion",
                "workflow_wall": "first job start to latest job completion",
                "runner_minutes": (
                    "sum of non-skipped job execution durations; parallel jobs are "
                    "summed separately from wall-clock"
                ),
                "percentile_method": "nearest rank",
            },
            "limitations": {
                "cache_hits_misses": (
                    "N/A: the Actions run/job API does not expose cache hit outputs; "
                    "raw job logs were not collected."
                ),
                "runner_cold_warm": (
                    "N/A: runner warmness is not represented by the run/job API."
                ),
                "step_queue_time": (
                    "N/A: the step API exposes start and completion timestamps, "
                    "not a queued timestamp."
                ),
                "billing_cost": (
                    "N/A: GitHub billing data is outside the read-only Actions run API; "
                    "runner minutes are not billed minutes."
                ),
                "artifact_download_count": (
                    "Artifact download_count is omitted by some API responses; when present "
                    "it is an artifact lifetime counter, not a per-run count. Download steps "
                    "are measured per run."
                ),
                "artifact_step_counts": (
                    "The run/job API omits an action's uses value. Upload/download step "
                    "counts are inferred from step names; artifact count and size use the "
                    "artifact API."
                ),
                "native_macos": (
                    "Record matching runs available; zero does not count as release PASS."
                ),
                "changed_components": (
                    "PR runs use associated pull request files when available; push/tag "
                    "runs use head commit files. Only component names are retained."
                ),
                "failure_flake": (
                    "Failure and cancellation rates come from conclusions. Retry count "
                    "is reported; a flake rate is not inferred from retries alone."
                ),
            },
        },
        "population_summaries": summaries,
        "pr_required_green_cohorts": pr_green,
        "job_breakdowns": jobs,
        "step_breakdowns": steps,
        "deployment_correlations": correlations,
        "recommendations": _recommendations(jobs, pr_green, correlations),
        "populations": populations,
    }


def _percent(value):
    return "N/A" if value is None else f"{value * 100:.1f}%"


def _minutes(seconds):
    if seconds is None:
        return "N/A"
    return f"{seconds / 60:.2f} min"


def render_markdown(report):
    summaries = report["population_summaries"]
    lines = [
        "# CI/CD baseline",
        "",
        f"Generated: {report['generated_at_utc']}",
        "",
        f"Repository: {report['repository']}",
        "",
        "## Reproduce",
        "",
        "From the repository root, provide GH_TOKEN or GITHUB_TOKEN with read access and run:",
        "",
        "    python3 -m tools.ci.baseline.run --repo Egkurilov/BOOHTACORD --sample-size 30 --date 2026-10-18",
        "",
        "The collector uses read-only GitHub API requests and does not download job logs or artifact contents.",
        "",
        "This run-level baseline uses GitHub Actions metadata. Workflow wall-clock and summed runner-minutes are separate measures. The sample includes completed runs; cancellations remain visible as conclusions.",
        "",
        "Changed-component labels for every sample are in the machine-readable report. PR runs use the associated pull request file list; push and tag runs use the head commit file list. Missing file data is labeled unknown.",
        "",
        "## Sample coverage",
        "",
        "| Population | Requested | Available | Success | Failed | Failure rate | Cancelled | Retries |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for key, label in POPULATION_LABELS.items():
        summary = summaries.get(key)
        if summary is None:
            continue
        lines.append(
            f"| {label} | {report['collection']['requested_completed_runs_per_population']} "
            f"| {summary['sample_count']} | {summary['success_count']} "
            f"| {summary['failure_count']} | {_percent(summary['failure_rate'])} "
            f"| {summary['cancelled_count']} | {summary['retry_attempts_after_first']} |"
        )

    lines += [
        "",
        "## Timing and runner use",
        "",
        "| Population | n | elapsed p50 | elapsed p95 | successful p95 | runner minutes total |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for key, label in POPULATION_LABELS.items():
        summary = summaries.get(key)
        if summary is None:
            continue
        elapsed = summary["elapsed_seconds"]
        successful = summary["successful_run_elapsed_seconds"]
        lines.append(
            f"| {label} | {summary['sample_count']} "
            f"| {_minutes(elapsed['p50'])} | {_minutes(elapsed['p95'])} "
            f"| {_minutes(successful['p95'])} | {summary['runner_minutes_total']:.2f} |"
        )

    push_history = report["collection"]["history"].get("all_push_for_tags", {})
    if push_history.get("reported_total_count") is not None and (
        push_history.get("records_returned", 0) < push_history["reported_total_count"]
    ):
        lines += [
            "",
            f"GitHub reports {push_history['reported_total_count']} completed push runs; "
            f"the API returned {push_history.get('records_returned', 0)} in "
            f"{push_history.get('pages_scanned', 0)} pages. Native-release counts are "
            "lower bounds for the history returned by this endpoint.",
        ]

    lines += [
        "",
        "## Run samples",
        "",
        "| Population | Latest | Slowest sampled run | First non-success |",
        "| --- | --- | --- | --- |",
    ]
    for key, label in POPULATION_LABELS.items():
        runs = report["populations"].get(key, [])
        if not runs:
            continue
        latest = runs[0]
        slowest = max(
            runs,
            key=lambda row: row.get("elapsed_seconds") or 0,
        )
        non_success = next(
            (row for row in runs if row.get("conclusion") != "success"),
            None,
        )

        def run_link(row):
            if not row:
                return "N/A"
            return f"[{row['run_id']}]({row['url']})"

        lines.append(
            f"| {label} | {run_link(latest)} | {run_link(slowest)} "
            f"| {run_link(non_success)} |"
        )

    pr = report["pr_required_green_cohorts"]
    green = pr["time_to_required_green_seconds"]
    hotspots = report["recommendations"]["proven_hotspots"]
    hotspot_text = ", ".join(
        f"{row['job']} (p95 {_minutes(row['p95_seconds'])})"
        for row in hotspots
    ) or "no measured required PR jobs"

    def job_families(population):
        return {
            (row["name"].rsplit("/", 1)[-1].strip().casefold()):
            row["name"].rsplit("/", 1)[-1].strip()
            for row in report["job_breakdowns"].get(population, [])
        }

    ci_families = job_families("master_ci")
    build_families = job_families("master_build_server")
    common_families = sorted(set(ci_families) & set(build_families))
    repeated_work = (
        f"Master CI and Build server both ran {', '.join(common_families)} jobs; "
        "quantify their repeated runner work before changing coverage."
        if common_families
        else "No common completed job families appeared in the sampled master workflows."
    )
    lines += [
        "",
        f"PR time to required green grouped by source commit: {pr['green_cohort_count']} "
        f"successful cohorts from {pr['commit_cohort_count']} sampled runs, "
        f"p50={_minutes(green['p50'])}, p95={_minutes(green['p95'])}; "
        f"{pr['recovered_after_non_success_count']} had a non-success before green and "
        f"{pr['unresolved_cohort_count']} had no successful run in the sample.",
        "",
        "## Measured job hotspots",
        "",
        "| Population | Job | n | p50 | p95 |",
        "| --- | --- | ---: | ---: | ---: |",
    ]
    for population in ("pr_required_gate", "master_ci", "master_build_server"):
        for row in report["job_breakdowns"].get(population, [])[:5]:
            lines.append(
                f"| {POPULATION_LABELS[population]} | {row['name']} | {row['count']} "
                f"| {_minutes(row['p50'])} | {_minutes(row['p95'])} |"
            )

    lines += [
        "",
        f"Measured required PR hotspots: {hotspot_text}. {repeated_work} Start optimization analysis with the measured hotspots, then compare runner-minute savings with required-green p95.",
        "",
        "## Delivery path evidence",
        "",
        "| Source SHA | Build run | Deploy run | Master to artifact | Artifact to health |",
        "| --- | --- | --- | ---: | ---: |",
    ]
    if report["deployment_correlations"]:
        for item in report["deployment_correlations"][:30]:
            lines.append(
                f"| {item['source_sha']} | [build]({item['build_run_url']}) "
                f"| [deploy]({item['deploy_run_url']}) "
                f"| {_minutes(item['master_to_artifact_seconds'])} "
                f"| {_minutes(item['artifact_to_health_seconds'])} |"
            )
    else:
        lines.append("| N/A | N/A | N/A | N/A | N/A |")

    fence = chr(96) * 3
    lines += [
        "",
        "## Artifact activity",
        "",
        "| Population | Runs with artifact metadata | Artifacts | Size total | Upload/retain steps | Download steps | API download count |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for key, label in POPULATION_LABELS.items():
        summary = summaries.get(key)
        if summary is None:
            continue
        download_count = summary["artifact_download_count_total"]
        download_count_text = "N/A" if download_count is None else str(download_count)
        size_mb = summary["artifact_size_bytes_total"] / (1024 * 1024)
        lines.append(
            f"| {label} | {summary['artifact_api_run_count']} "
            f"| {summary['artifact_count_total']} | {size_mb:.2f} MB "
            f"| {summary['artifact_upload_step_count']} "
            f"| {summary['artifact_download_step_count']} | {download_count_text} |"
        )

    lines += [
        "",
        "Step totals are inferred from GitHub step names; artifact counts and sizes come from the artifact API.",
        "",
        "## Dependency graph",
        "",
        f"{fence}mermaid",
        "flowchart LR",
        "  PR[Pull request] --> selector[Change selector]",
        "  selector --> checks[Required CI jobs]",
        "  checks --> green[Required PR status]",
        "  master[master SHA] --> ci[CI workflow]",
        "  master --> build[Build server gates]",
        "  build --> bundle[Verified immutable bundle]",
        "  bundle --> deploy[Serialized production install]",
        "  deploy --> health[Health and readback]",
        "  tag[Native release tag] --> quality[Platform quality gate]",
        "  quality --> package[Signed or verified native package]",
        "  manual[Approved operator dispatch] --> diagnostics[Isolated diagnostics or maintenance]",
        fence,
        "",
        "## Budget and limitations",
        "",
        f"Use the observed PR required-green p95 of {_minutes(green['p95'])} as a provisional regression ceiling. It comes from {pr['green_cohort_count']} successful cohorts; {pr['unresolved_cohort_count']} sampled cohorts had no successful run. Replace this budget after collecting at least 30 successful cohorts. The 30-run workflow elapsed p95 is {_minutes(summaries['pr_required_gate']['elapsed_seconds']['p95'])}. Keep coverage fixed while routing changes are evaluated, and report p95 wall-clock and runner-minute deltas before setting a reduction target.",
        "",
        "Failure and cancellation rates come from workflow conclusions. Retry counts are not called flakes without a classified retry cause. Cache hit/miss, runner cold/warm state, step queue time, and billing cost are N/A because the run/job/step API does not provide them; raw logs and billing data were not collected.",
        "",
        "Native release samples use matching tag or manual runs. A short or empty sample is unavailable and does not imply release acceptance.",
        "",
        f"Machine-readable run/job/step data: [baseline JSON](../../evidence/ci/baseline-{report['generated_at_utc'][:10]}.json).",
        "",
    ]
    return "\n".join(lines)
