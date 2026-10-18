"""Read Actions `needs` through environment JSON, never shell-interpolated source."""
import json
import os
from .validation import validate
from tools.ci.select_changes.selection import dependency_map


def main():
    try:
        validate(json.loads(os.environ['CI_NEEDS']), json.loads(os.environ['CI_JOBS']), dependency_map()[1])
    except (ValueError, KeyError, TypeError, OSError):
        print('FAIL: required CI gate lacks complete successful evidence')
        return 1
    print('PASS: common selector, contracts and every applicable CI gate succeeded')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
