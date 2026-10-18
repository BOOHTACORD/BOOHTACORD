from collections import Counter
from datetime import datetime, timezone
import math


def parse_timestamp(value):
    if not value or not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def duration_seconds(start, end):
    first = parse_timestamp(start)
    last = parse_timestamp(end)
    if first is None or last is None:
        return None
    seconds = (last - first).total_seconds()
    return None if seconds < 0 else int(round(seconds))


def percentile(values, quantile):
    if not isinstance(quantile, (int, float)) or not 0 <= quantile <= 1:
        raise ValueError("quantile must be between 0 and 1")
    usable = sorted(
        float(value)
        for value in values
        if isinstance(value, (int, float))
        and math.isfinite(float(value))
        and float(value) >= 0
    )
    if not usable:
        return None
    return usable[max(1, math.ceil(quantile * len(usable))) - 1]


def artifact_operation(step_name):
    """Infer artifact operations from GitHub step names when `uses` is absent."""
    name = (step_name or "").lower()
    if (
        "upload-artifact" in name
        or "upload artifact" in name
        or name.startswith(("upload ", "retain "))
    ):
        return "upload"
    if (
        "download-artifact" in name
        or "download artifact" in name
        or name.startswith("download ")
    ):
        return "download"
    return None


def distribution(values):
    usable = [
        float(value)
        for value in values
        if isinstance(value, (int, float))
        and math.isfinite(float(value))
        and float(value) >= 0
    ]
    return {
        "count": len(usable),
        "p50": percentile(usable, 0.50),
        "p90": percentile(usable, 0.90),
        "p95": percentile(usable, 0.95),
    }


def summarize_workflow_runs(runs):
    statuses = Counter()
    conclusions = Counter()
    elapsed_values = []
    successful_elapsed = []
    wall_values = []
    run_queue = []
    job_queue = []
    job_durations = []
    step_durations = []
    runner_minutes_per_run = []
    runner_seconds_total = 0
    missing_run_timing = 0
    missing_job_timing = 0
    missing_step_timing = 0
    artifact_runs = 0
    artifact_count = 0
    artifact_bytes = 0
    artifact_downloads = 0
    artifact_download_count_unknown = False
    upload_steps = 0
    download_steps = 0
    cache_steps = 0
    platforms = Counter()
    components = Counter()

    for run in runs:
        status = run.get("status") or "unknown"
        conclusion = run.get("conclusion") or "unknown"
        statuses[status] += 1
        conclusions[conclusion] += 1

        for platform in run.get("platforms", []):
            platforms[platform] += 1
        for component in run.get("changed_components", []):
            components[component] += 1
        if run.get("run_queue_seconds") is not None:
            run_queue.append(run["run_queue_seconds"])

        completed_at = run.get("completed_at")
        run_start = run.get("run_started_at") or run.get("created_at")
        if status == "completed" and completed_at:
            elapsed = duration_seconds(run.get("created_at") or run_start, completed_at)
            if elapsed is None:
                missing_run_timing += 1
            else:
                elapsed_values.append(elapsed)
                if conclusion == "success":
                    successful_elapsed.append(elapsed)
            wall = duration_seconds(run_start, completed_at)
            if wall is not None:
                wall_values.append(wall)
        elif status == "completed":
            missing_run_timing += 1

        runner_seconds_this_run = 0
        for job in run.get("jobs", []):
            if job.get("queue_seconds") is not None:
                job_queue.append(job["queue_seconds"])
            value = job.get("duration_seconds")
            if value is None:
                value = duration_seconds(job.get("started_at"), job.get("completed_at"))
            if value is not None:
                job_durations.append(value)
                if job.get("conclusion") != "skipped":
                    runner_seconds_this_run += value
            elif job.get("status") == "completed" and job.get("conclusion") != "skipped":
                missing_job_timing += 1

            for step in job.get("steps", []):
                step_value = step.get("duration_seconds")
                if step_value is None:
                    step_value = duration_seconds(step.get("started_at"), step.get("completed_at"))
                if step_value is not None:
                    step_durations.append(step_value)
                elif step.get("status") == "completed" and step.get("conclusion") != "skipped":
                    missing_step_timing += 1
                name = (step.get("name") or "").lower()
                operation = step.get("artifact_operation") or artifact_operation(name)
                if operation == "upload":
                    upload_steps += 1
                elif operation == "download":
                    download_steps += 1
                cache_operation = step.get("cache_operation")
                if cache_operation is None:
                    cache_operation = "cache" in name
                if cache_operation:
                    cache_steps += 1

        runner_seconds_total += runner_seconds_this_run
        runner_minutes_per_run.append(runner_seconds_this_run / 60)

        artifacts = run.get("artifacts") or {}
        if artifacts.get("available"):
            artifact_runs += 1
            artifact_count += artifacts.get("count", 0)
            artifact_bytes += artifacts.get("size_bytes", 0)
            if artifacts.get("download_count") is None:
                artifact_download_count_unknown = True
            else:
                artifact_downloads += artifacts["download_count"]

    completed = statuses.get("completed", 0)
    successes = conclusions.get("success", 0)
    failures = sum(
        conclusions.get(key, 0)
        for key in ("failure", "timed_out", "startup_failure", "action_required")
    )
    cancelled = conclusions.get("cancelled", 0)

    return {
        "sample_count": len(runs),
        "status_counts": dict(sorted(statuses.items())),
        "conclusion_counts": dict(sorted(conclusions.items())),
        "completed_count": completed,
        "success_count": successes,
        "failure_count": failures,
        "cancelled_count": cancelled,
        "non_success_count": max(0, completed - successes),
        "failure_rate": failures / completed if completed else None,
        "cancellation_rate": cancelled / completed if completed else None,
        "retry_run_count": sum(1 for run in runs if int(run.get("run_attempt") or 1) > 1),
        "retry_attempts_after_first": sum(
            max(0, int(run.get("run_attempt") or 1) - 1) for run in runs
        ),
        "elapsed_seconds": distribution(elapsed_values),
        "successful_run_elapsed_seconds": distribution(successful_elapsed),
        "run_wall_seconds": distribution(wall_values),
        "run_queue_seconds": distribution(run_queue),
        "job_queue_seconds": distribution(job_queue),
        "job_execution_seconds": distribution(job_durations),
        "step_execution_seconds": distribution(step_durations),
        "runner_minutes_total": round(runner_seconds_total / 60, 2),
        "runner_minutes_per_run": distribution(runner_minutes_per_run),
        "missing_run_timing_count": missing_run_timing,
        "missing_job_timing_count": missing_job_timing,
        "missing_step_timing_count": missing_step_timing,
        "artifact_api_run_count": artifact_runs,
        "artifact_count_total": artifact_count,
        "artifact_size_bytes_total": artifact_bytes,
        "artifact_download_count_total": (
            None if artifact_download_count_unknown else artifact_downloads
        ),
        "artifact_download_count_available": not artifact_download_count_unknown,
        "artifact_upload_step_count": upload_steps,
        "artifact_download_step_count": download_steps,
        "cache_step_count": cache_steps,
        "cache_hits": None,
        "cache_misses": None,
        "runner_temperature": None,
        "platform_run_counts": dict(sorted(platforms.items())),
        "changed_component_run_counts": dict(sorted(components.items())),
    }


def summarize_pr_green_cohorts(runs):
    cohorts = {}
    for run in runs:
        sha = run.get("head_sha")
        if sha:
            cohorts.setdefault(sha, []).append(run)

    elapsed = []
    recovered = 0
    unresolved = 0
    for attempts in cohorts.values():
        attempts.sort(key=lambda row: row.get("created_at") or "")
        successful = next(
            (
                row for row in attempts
                if row.get("status") == "completed" and row.get("conclusion") == "success"
            ),
            None,
        )
        if successful is None:
            unresolved += 1
            continue
        value = duration_seconds(attempts[0].get("created_at"), successful.get("completed_at"))
        if value is None:
            continue
        elapsed.append(value)
        earlier = attempts[: attempts.index(successful)]
        if any(
            row.get("conclusion") in {
                "failure", "timed_out", "startup_failure", "cancelled"
            }
            for row in earlier
        ):
            recovered += 1

    return {
        "commit_cohort_count": len(cohorts),
        "green_cohort_count": len(elapsed),
        "unresolved_cohort_count": unresolved,
        "recovered_after_non_success_count": recovered,
        "time_to_required_green_seconds": distribution(elapsed),
    }
