"""Prepare an operator key and balanced blind response forms."""
import argparse
from pathlib import Path

from .output import write_plan
from .trials import paired_trials


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--scenario', action='append', required=True)
    parser.add_argument('--listeners', type=int, default=10)
    args = parser.parse_args()
    assignments = paired_trials(args.scenario, ['v02', 'dfn3'], args.listeners)
    write_plan(args.output, assignments, args.listeners)
    print(f'prepared {len(assignments)} blinded pairs for {args.listeners} listeners; no quality decision')


if __name__ == '__main__':
    main()
