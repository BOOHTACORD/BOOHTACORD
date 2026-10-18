import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from .collector import GitHubAPI, collect_samples
from .report import build_report, render_markdown


def main():
    parser = argparse.ArgumentParser(
        description="Collect a read-only and sanitized GitHub Actions baseline."
    )
    parser.add_argument("--repo", default="Egkurilov/BOOHTACORD")
    parser.add_argument("--sample-size", type=int, default=30)
    parser.add_argument(
        "--date",
        default=datetime.now(timezone.utc).date().isoformat(),
        help="UTC date used in the evidence filenames.",
    )
    parser.add_argument("--json", dest="json_path")
    parser.add_argument("--markdown", dest="markdown_path")
    args = parser.parse_args()
    if args.sample_size < 1:
        parser.error("--sample-size must be positive")

    json_path = Path(args.json_path or f"evidence/ci/baseline-{args.date}.json")
    markdown_path = Path(
        args.markdown_path or f"docs/ci/baseline-{args.date}.md"
    )

    api = GitHubAPI(args.repo)
    collection = collect_samples(api, args.sample_size)
    report = build_report(collection, args.repo)

    json_path.parent.mkdir(parents=True, exist_ok=True)
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    markdown_path.write_text(render_markdown(report), encoding="utf-8")
    print(
        f"Wrote sanitized baseline: {json_path} and {markdown_path}; "
        f"requested runs per population={args.sample_size}."
    )


if __name__ == "__main__":
    main()
