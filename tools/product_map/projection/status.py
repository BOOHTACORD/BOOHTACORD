"""Derive source status only; release and runtime are independent axes."""


def source_status(applicability, implementation, target, actual, *, exception_approved=False):
    if applicability == 'NOT_APPLICABLE':
        return 'NOT_APPLICABLE' if exception_approved else 'UNKNOWN'
    if applicability == 'PLATFORM_EXCEPTION':
        return 'INTENTIONAL_DIFFERENCE' if exception_approved else 'UNKNOWN'
    if applicability != 'SUPPORTED':
        return 'UNKNOWN'
    if implementation == 'NOT_STARTED':
        return 'MISSING'
    if implementation != 'IMPLEMENTED':
        return 'UNKNOWN'
    if (type(target) is not int or type(actual) is not int or
            target < 1 or actual < 1):
        return 'UNKNOWN'
    if actual < target:
        return 'BEHIND'
    if actual > target:
        return 'AHEAD_UNREVIEWED'
    return 'IN_SYNC'
