"""Keep CI proof roles intact; the live install begins at the older source."""
from copy import deepcopy
import re


def ordered(proof, is_ancestor):
    try:
        newer, older = (proof[role]['head'] for role in ('current', 'previous'))
        if (any(not isinstance(v, str) or not re.fullmatch('[a-f0-9]{40}', v) for v in (newer, older))
                or newer == older or is_ancestor(older, newer) is not True):
            raise ValueError
    except (KeyError, TypeError, ValueError):
        raise ValueError('Two exact independently verified ancestor sources are required') from None
    # setup.py calls its initially deployed role "current". This local adapter
    # does not relabel commits, images, producer runs or the original CI proof.
    return deepcopy({'current': proof['previous'], 'previous': proof['current']})
