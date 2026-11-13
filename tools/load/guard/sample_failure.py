"""Bounded stage names for local guard failures; never retain exception text."""
import subprocess


class SampleFailure(RuntimeError):
    def __init__(self, stage):
        if stage not in {'fixture_verification', 'resource_snapshot'}:
            raise ValueError('Unknown guard stage')
        super().__init__(stage)


def checked_inputs(stack, manifest, resources, verifier):
    try:
        verifier(stack, manifest['Nonce'], len(manifest['Accounts']))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        raise SampleFailure('fixture_verification') from None
    try:
        return resources.read()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        raise SampleFailure('resource_snapshot') from None
