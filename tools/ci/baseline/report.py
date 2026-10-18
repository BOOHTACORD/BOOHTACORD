"""Reproducible aggregates and source URLs; absent evidence is explicitly unknown."""
from collections import defaultdict
from .metrics import distribution, elapsed, run_metrics, summarize


def delivery_links(builds, deploys):
    result = []
    for deploy in deploys:
        matches = [b for b in builds if b['head_sha'] == deploy['head_sha']
                   and b.get('conclusion') == 'success']
        row = {'deploy_url': deploy['url'], 'head_sha': deploy['head_sha'], 'status': 'N/A'}
        if len(matches) == 1 and deploy.get('conclusion') == 'success':
            build = matches[0]
            artifacts = [a for a in build.get('artifacts') or [] if a.get('server_source_sha') == build['head_sha']]
            uploads = [s for j in build['jobs'] for s in j['steps']
                       if s['name'] == 'Retain the exact verified release' and s.get('conclusion') == 'success']
            end = max((j.get('completed_at') or '' for j in deploy['jobs']), default=None)
            ready = uploads[0].get('completed_at') if len(uploads) == 1 else None
            seconds = elapsed(ready, end)
            if len(artifacts) == 1 and seconds is not None:
                row.update(status='observed_upper_bound', build_url=build['url'], artifact_id=artifacts[0]['id'],
                           artifact_upload_completed_at=ready,
                           master_to_artifact_seconds=elapsed(build['created_at'], ready),
                           artifact_to_install_success_upper_seconds=seconds)
        result.append(row)
    return result


def hotspots(runs):
    jobs, steps = defaultdict(list), defaultdict(list)
    for run in runs:
        for attempt in run.get('attempts') or [{'jobs': run['jobs']}]:
            for job in attempt['jobs']:
                jobs[(job['name'], job.get('platform', 'unknown'))].append(
                    {'seconds': elapsed(job.get('started_at'), job.get('completed_at')), 'url': run['url']})
                for step in job['steps']:
                    steps[(job['name'], step['name'], step['kind'])].append(
                        {'seconds': elapsed(step.get('started_at'), step.get('completed_at')), 'url': run['url']})

    def aggregate(items, names):
        result = [{**dict(zip(names, key)), 'seconds': distribution([x['seconds'] for x in rows]),
                   'total_seconds': sum(x['seconds'] or 0 for x in rows),
                   'run_ids': sorted({int(x['url'].rsplit('/', 1)[-1]) for x in rows if x['url'].rsplit('/', 1)[-1].isdigit()})} for key, rows in items.items()]
        return sorted(result, key=lambda x: x['total_seconds'], reverse=True)
    return {'jobs': aggregate(jobs, ('job', 'platform')),
            'steps': aggregate(steps, ('job', 'step', 'kind'))}


def build_report(cohorts):
    links = delivery_links(cohorts.get('server_build', []), cohorts.get('deploy', []))
    return {'schema_version': 1, 'percentile_method': 'nearest-rank; null samples excluded with explicit n',
            'cohorts': {name: summarize(rows) for name, rows in cohorts.items()},
            'hotspots': {name: hotspots(rows) for name, rows in cohorts.items()},
            'delivery': links, 'repeated_master_gates': repeated_gates(cohorts),
            'master_to_artifact_seconds': distribution([x.get('master_to_artifact_seconds') for x in links]),
            'artifact_to_install_success_upper_seconds': distribution([
                x.get('artifact_to_install_success_upper_seconds') for x in links]),
            'required_green_seconds': None, 'billing_minutes': None, 'cache_hit_rate': None,
            'limitations': [
                'CI success is a proxy, not time-to-required-green: branch protection policy not collected.',
                'created_at to final job completion includes retries/wait; updated_at is never treated as completion.',
                'Job-minutes sum all attempts without billing rounding or platform price multipliers.',
                'First-job delay includes dispatch/setup; job created-to-start may include dependencies/approvals.',
                'Completion driver is the last finishing job, not a reconstructed causal DAG critical path.',
                'Cold/warm and cache hits, billing and confirmed flake classification are unavailable in metadata.',
                'Artifact upload completion to successful install completion is an upper bound, not exact health-readback time.',
                'Delivery matching requires unique same-SHA artifact producer in sample; not a provenance attestation.',
                'Missing Git/PR base stays unknown; push first-parent classification is not full event.before diff.',
            ]}


def compact_run(run):
    """Keep complete timing evidence in .out; publish bounded per-job costly steps."""
    result = {k: v for k, v in run.items() if k not in ('jobs', 'attempts')}
    result['metrics'] = run_metrics(run)
    result['attempts'] = []
    for attempt in run['attempts']:
        jobs = []
        for job in attempt['jobs']:
            item = {k: v for k, v in job.items() if k != 'steps'}
            timed = [{**s, 'seconds': elapsed(s.get('started_at'), s.get('completed_at'))} for s in job['steps']]
            item['step_count'] = len(timed)
            item['costliest_steps'] = [{k: s[k] for k in ('name', 'number', 'kind', 'conclusion', 'seconds')}
                                       for s in sorted(timed, key=lambda x: x['seconds'] or 0, reverse=True)[:5]]
            item['upload_seconds'] = sum(s['seconds'] or 0 for s in timed if s['kind'] == 'artifact_upload')
            item['execution_seconds'] = elapsed(job.get('started_at'), job.get('completed_at'))
            item['created_to_start_seconds'] = elapsed(job.get('created_at'), job.get('started_at'))
            jobs.append(item)
        result['attempts'].append({'number': attempt['number'], 'jobs': jobs})
    return result


def repeated_gates(cohorts):
    result = []
    for build in cohorts.get('server_build', []):
        candidates = [r for r in cohorts.get('ci_master', []) if r['head_sha'] == build['head_sha']]
        if len(candidates) != 1:
            continue
        ci = candidates[0]
        pairs = [('backend / backend', 'backend / backend'),
                 ('frontend / frontend', 'web / frontend'), ('contracts / contracts', 'contracts / contracts')]
        for ci_name, build_name in pairs:
            left = [j for j in ci['jobs'] if j['name'] == ci_name and j.get('conclusion') == 'success']
            right = [j for j in build['jobs'] if j['name'] == build_name and j.get('conclusion') == 'success']
            if len(left) == len(right) == 1:
                seconds = elapsed(right[0].get('started_at'), right[0].get('completed_at'))
                result.append({'head_sha': build['head_sha'], 'ci_url': ci['url'], 'build_url': build['url'],
                               'gate': ci_name, 'additional_build_job_minutes': seconds / 60 if seconds else None})
    return result
