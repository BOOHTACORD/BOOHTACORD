"""Keep the local Dart/app/vendor/analyze entrypoint identical to its CI profile."""
from tools.ci.flutter_gates.profiles import execute


def main():
    execute('dart')


if __name__ == "__main__":
    main()
