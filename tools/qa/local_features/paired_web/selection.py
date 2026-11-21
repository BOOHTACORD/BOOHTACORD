"""Select the web build needed by paired Android acceptance."""

PAIRED_ANDROID_TARGETS = frozenset({
    'integration_test/issue785_background_listener_pair_test.dart',
    'integration_test/issue785_background_microphone_uplink_test.dart',
})


def requires_web_build(platforms, android_targets):
    return ('android' in platforms and 'web' not in platforms
            and bool(PAIRED_ANDROID_TARGETS.intersection(android_targets)))
