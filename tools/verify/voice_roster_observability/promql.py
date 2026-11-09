"""Generate syntax-checkable records from the actual Grafana roster expressions."""
import json
from pathlib import Path
import sys
import shutil
import yaml


def main():
    root = Path(__file__).resolve().parents[3]
    dashboard = json.loads((root / 'docker/observability/dashboards/voice-roster.json').read_text(encoding='utf-8'))
    rules = []
    for panel in dashboard['panels']:
        for target in panel['targets']:
            expression = target['expr'].replace('$__rate_interval', '5m')
            rules.append({'record': f'roster_dashboard_panel_{panel["id"]}_{target["refId"]}', 'expr': expression})
    fleet = json.loads((root / 'docker/observability/fleet/dashboards/voice-roster.json').read_text(encoding='utf-8'))
    for panel in fleet['panels']:
        for target in panel['targets']:
            expression = target['expr'].replace('$installation', 'synthetic').replace('$__rate_interval', '5m')
            rules.append({'record': f'fleet_roster_panel_{panel["id"]}_{target["refId"]}', 'expr': expression})
    destination = root / '.out/voice-roster/dashboard-rules.yaml'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / 'docker/observability/voice-roster-alerts.yaml', destination.parent / 'voice-roster-alerts.yaml')
    for fixture in Path(__file__).parent.glob('*.yaml'):
        shutil.copyfile(fixture, destination.parent / fixture.name)
    destination.write_text(yaml.safe_dump({'groups': [{'name': 'roster-dashboard', 'rules': rules}]}), encoding='utf-8')
    print('Generated actual roster dashboard expressions for pinned promtool validation')


if __name__ == '__main__':
    main()
