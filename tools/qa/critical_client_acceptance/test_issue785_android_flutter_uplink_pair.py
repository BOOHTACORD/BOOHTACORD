import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from tools.qa.critical_client_acceptance.issue785_android_flutter_uplink_pair import (
    MIN_BACKGROUND_SECONDS,
    display_is_asleep,
    receiver_has_foreground_uplink,
    receiver_blackhole_recovery,
    receiver_progressed_during_background,
    receiver_uplink_advanced_after,
    validate_blackhole_seconds,
    validate_background_seconds,
    parse_blackhole_drop_counters,
    validate_service_stop_after,
    microphone_service_expected_active,
    microphone_permission_status,
    receiver_media_stop_after_permission_revoke,
    service_stop_command_succeeded,
    validate_microphone_permission_revoke_after,
    permission_revoke_cold_start_result,
    permission_revoke_cold_start_not_run,
    latest_permission_revoke_kill,
    flutter_drive_cleanup_flags,
    validate_permission_revoke_cold_start,
    permission_revoke_permission_persisted,
    normal_product_apk_install_command,
    build_web_client,
)
from tools.qa.local_features.android_microphone import android_microphone_permission


class Issue785AndroidFlutterUplinkPairTest(unittest.TestCase):
    def test_receiver_confirms_rtp_progress_after_microphone_retry(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 10, 'inbound_audio_bytes': 100},
            {'observed_at_unix_ms': 3000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 10, 'inbound_audio_bytes': 100},
            {'observed_at_unix_ms': 5000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 12, 'inbound_audio_bytes': 160},
        ]
        result = receiver_uplink_advanced_after(samples, 2000)
        self.assertEqual(result['first_progress_sample'], samples[2])
        self.assertEqual(result['progress_seconds_after_action'], 3)

    def test_receiver_requires_post_action_progress_inside_bounded_window(self):
        stale_only = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 10, 'inbound_audio_bytes': 100},
            {'observed_at_unix_ms': 3000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 15, 'inbound_audio_bytes': 150},
        ]
        plateau = [
            {'observed_at_unix_ms': 2000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 10, 'inbound_audio_bytes': 100},
            {'observed_at_unix_ms': 4000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 10, 'inbound_audio_bytes': 100},
        ]
        too_late = [
            {'observed_at_unix_ms': 2000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 10, 'inbound_audio_bytes': 100},
            {'observed_at_unix_ms': 25000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 12, 'inbound_audio_bytes': 160},
        ]
        self.assertIsNone(receiver_uplink_advanced_after(stale_only, 2000))
        self.assertIsNone(receiver_uplink_advanced_after(plateau, 2000))
        self.assertIsNone(receiver_uplink_advanced_after(too_late, 2000))

    def test_cold_start_probe_requires_permission_revoke_injection(self):
        self.assertTrue(validate_permission_revoke_cold_start(True, 5))
        self.assertFalse(validate_permission_revoke_cold_start(False, 0))
        with self.assertRaises(ValueError):
            validate_permission_revoke_cold_start(True, 0)

    def test_permission_revoke_cold_start_requires_denied_mic_live_activity_and_stopped_fgs(self):
        activity = 'topResumedActivity=ActivityRecord{... ru.boohtacord.app/.MainActivity}'
        result = permission_revoke_cold_start_result('denied', '2053', activity, '')
        self.assertIsNotNone(result)
        self.assertTrue(result['app_process_running'])
        self.assertTrue(result['main_activity_resumed'])
        self.assertFalse(result['microphone_foreground_service_active'])
        self.assertIsNone(permission_revoke_cold_start_result('granted', '2053', activity, ''))
        self.assertIsNone(permission_revoke_cold_start_result('denied', '', activity, ''))
        self.assertIsNone(permission_revoke_cold_start_result('denied', '2053', '', ''))
        self.assertIsNone(permission_revoke_cold_start_result(
            'denied', '2053', activity,
            'ServiceRecord{abc ru.boohtacord.app/ru.boohtacord.voice.start.MicrophoneService}',
        ))

    def test_reads_microphone_permission_from_package_manager_dump(self):
        self.assertEqual(
            microphone_permission_status(
                'android.permission.RECORD_AUDIO: granted=false, flags=[USER_SET]'
            ),
            'denied',
        )
        self.assertEqual(
            microphone_permission_status(
                'android.permission.RECORD_AUDIO: granted=true, flags=[USER_SET]'
            ),
            'granted',
        )
        self.assertIsNone(microphone_permission_status('Unable to find package'))

    def test_cold_start_keeps_record_audio_denied_after_relaunch(self):
        self.assertTrue(permission_revoke_permission_persisted(
            'denied', 'android.permission.RECORD_AUDIO: granted=false, flags=[USER_SET]'
        ))
        self.assertFalse(permission_revoke_permission_persisted(
            'denied', 'android.permission.RECORD_AUDIO: granted=true, flags=[USER_SET]'
        ))
        self.assertFalse(permission_revoke_permission_persisted('denied', 'Unable to find package'))
        self.assertFalse(permission_revoke_permission_persisted('granted', 'granted=false'))

    def test_unavailable_cold_start_is_recorded_without_claiming_recovery(self):
        result = permission_revoke_cold_start_not_run(
            'denied', 'Application package was absent from the AVD'
        )
        self.assertEqual(result['status'], 'NOT_RUN')
        self.assertFalse(result['app_installed'])
        self.assertEqual(result['permission_status'], 'denied')
        self.assertEqual(result['automatic_voice_rejoin'], 'NOT_RUN')

    def test_permission_revoke_kill_log_keeps_only_the_latest_matching_process_kill(self):
        logcat = '\n'.join([
            'ActivityManager: Killing 100:ru.boohtacord.app/u0a1 (adj 50): permissions revoked',
            'AppOps: Operation not started: pkg=ru.boohtacord.app op=RECORD_AUDIO',
            'ActivityManager: Killing 200:ru.boohtacord.app/u0a2 (adj 50): permissions revoked',
        ])
        self.assertEqual(
            latest_permission_revoke_kill(logcat),
            'ActivityManager: Killing 200:ru.boohtacord.app/u0a2 (adj 50): permissions revoked',
        )

    def test_cold_start_probe_keeps_flutter_app_installed_after_driver_exit(self):
        self.assertEqual(flutter_drive_cleanup_flags(True), ['--keep-app-running'])
        self.assertEqual(flutter_drive_cleanup_flags(False), [])

    def test_permission_revoke_cold_start_installs_the_ordinary_product_apk(self):
        self.assertEqual(
            normal_product_apk_install_command(
                'emulator-5554', '/tmp/ordinary-app-debug.apk'
            ),
            [
                'adb', '-s', 'emulator-5554', 'install', '-r', '-d',
                '/tmp/ordinary-app-debug.apk',
            ],
        )

    def test_pair_runner_builds_production_web_for_the_owned_loopback_origin(self):
        with patch('subprocess.run', return_value=SimpleNamespace(returncode=0)) as run:
            build_web_client('/repo', 'https://localhost:4810')
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], ['npm', 'run', 'build'])
        self.assertEqual(str(run.call_args.kwargs['cwd']), '/repo/clients/web')
        self.assertEqual(
            run.call_args.kwargs['env']['VITE_PUBLIC_ORIGIN'],
            'https://localhost:4810',
        )

    def test_service_stop_probe_requires_a_valid_in_background_offset(self):
        self.assertEqual(validate_service_stop_after(5, 120), 5)
        self.assertEqual(validate_service_stop_after(0, 120), 0)
        with self.assertRaises(ValueError):
            validate_service_stop_after(-1, 120)
        with self.assertRaises(ValueError):
            validate_service_stop_after(120, 120)

    def test_service_stop_probe_expects_service_to_stop_only_after_injected_offset(self):
        self.assertTrue(microphone_service_expected_active(0, 5))
        self.assertTrue(microphone_service_expected_active(4.9, 5))
        self.assertFalse(microphone_service_expected_active(5, 5))
        self.assertFalse(microphone_service_expected_active(30, 5))

    def test_accepts_run_as_service_stop_confirmation_despite_nonzero_exit(self):
        self.assertTrue(service_stop_command_succeeded(255, '', 'Service stopped'))
        self.assertFalse(service_stop_command_succeeded(255, '', 'Error stopping service'))
        self.assertTrue(service_stop_command_succeeded(0, '', ''))

    def test_permission_revoke_probe_requires_a_valid_in_background_offset(self):
        self.assertEqual(validate_microphone_permission_revoke_after(5, 120), 5)
        self.assertEqual(validate_microphone_permission_revoke_after(0, 120), 0)
        with self.assertRaises(ValueError):
            validate_microphone_permission_revoke_after(-1, 120)
        with self.assertRaises(ValueError):
            validate_microphone_permission_revoke_after(120, 120)

    def test_permission_revoke_probe_grants_once_without_regrant_loop(self):
        with patch('subprocess.run', return_value=SimpleNamespace(returncode=0)) as run:
            with android_microphone_permission(
                'android', 'emulator-5554',
                'integration_test/issue785_background_microphone_uplink_test.dart',
                regrant=False,
            ):
                for _ in range(50):
                    if run.called:
                        break
                    time.sleep(.01)
                time.sleep(.02)
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], [
            'adb', '-s', 'emulator-5554', 'shell', 'pm', 'grant',
            'ru.boohtacord.app', 'android.permission.RECORD_AUDIO',
        ])
        self.assertFalse(run.call_args.kwargs['check'])

    def test_permission_revoke_receiver_counters_stop_after_settle_window(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 100, 'inbound_audio_bytes': 1000},
            {'observed_at_unix_ms': 2000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 200, 'inbound_audio_bytes': 2000},
            {'observed_at_unix_ms': 5000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 13001, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 25000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
        ]
        result = receiver_media_stop_after_permission_revoke(samples, 3000, 26000)
        self.assertIsNotNone(result)
        self.assertEqual(result['receiver_before_revoke']['inbound_audio_packets'], 200)
        self.assertEqual(result['receiver_at_background_end']['inbound_audio_packets'], 240)

    def test_permission_revoke_accepts_track_removal_and_stats_reset_after_uplink_stops(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 33, 'inbound_audio_bytes': 4900},
            {'observed_at_unix_ms': 5000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 40, 'inbound_audio_bytes': 5378},
            {'observed_at_unix_ms': 13001, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
            {'observed_at_unix_ms': 25000, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
        ]
        result = receiver_media_stop_after_permission_revoke(samples, 3000, 26000)
        self.assertIsNotNone(result)
        self.assertEqual(result['last_rtp_counter_increase_after_revoke']['observed_at_unix_ms'], 5000)
        self.assertEqual(result['receiver_at_background_end']['inbound_audio_tracks'], 0)

    def test_permission_revoke_receiver_plateau_must_reach_window_end(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 100, 'inbound_audio_bytes': 1000},
            {'observed_at_unix_ms': 2000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 200, 'inbound_audio_bytes': 2000},
            {'observed_at_unix_ms': 5000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 13001, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 20000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
        ]
        self.assertIsNone(receiver_media_stop_after_permission_revoke(samples, 3000, 26000))

    def test_permission_revoke_receiver_plateau_must_span_the_settle_duration(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 100, 'inbound_audio_bytes': 1000},
            {'observed_at_unix_ms': 2000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 200, 'inbound_audio_bytes': 2000},
            {'observed_at_unix_ms': 5000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 13001, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 19000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 240, 'inbound_audio_bytes': 2400},
        ]
        self.assertIsNone(receiver_media_stop_after_permission_revoke(samples, 3000, 19000))

    def test_permission_revoke_receiver_counters_must_plateau_for_settle_window(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 100, 'inbound_audio_bytes': 1000},
            {'observed_at_unix_ms': 13001, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 200, 'inbound_audio_bytes': 2000},
            {'observed_at_unix_ms': 15000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 201, 'inbound_audio_bytes': 2010},
        ]
        self.assertIsNone(receiver_media_stop_after_permission_revoke(samples, 3000, 16000))

    def test_reproduction_window_is_two_minutes(self):
        self.assertEqual(MIN_BACKGROUND_SECONDS, 120)
        self.assertEqual(validate_background_seconds(120), 120)

    def test_rejects_shorter_than_reproduction_window(self):
        with self.assertRaises(ValueError):
            validate_background_seconds(119)

    def test_network_blackhole_fits_inside_two_minute_background_window(self):
        self.assertEqual(validate_blackhole_seconds(120, 30), 30)
        self.assertEqual(validate_blackhole_seconds(120, 0), 0)

    def test_rejects_blackhole_that_does_not_leave_time_to_resume(self):
        with self.assertRaises(ValueError):
            validate_blackhole_seconds(120, 115)

    def test_reads_blackhole_drop_counters_for_loopback_api_and_media(self):
        output = '''Chain OUTPUT (policy ACCEPT 12 packets, 800 bytes)
    pkts      bytes target     prot opt in     out     source               destination
      739   101896 DROP       17   --  *      *       0.0.0.0/0            127.0.0.1            udp dpt:4882
      613   702769 DROP       6    --  *      *       0.0.0.0/0            127.0.0.1            multiport dports 4810,4881
'''
        self.assertEqual(parse_blackhole_drop_counters(output), {
            'udp_4882': {'packets': 739, 'bytes': 101896},
            'tcp_4810_4881': {'packets': 613, 'bytes': 702769},
        })

    def test_detects_screen_off_power_state(self):
        self.assertTrue(display_is_asleep('mWakefulness=Asleep\n'))
        self.assertFalse(display_is_asleep('mWakefulness=Awake\n'))
        self.assertFalse(display_is_asleep(''))

    def test_requires_independent_receiver_packets_to_advance_in_background(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 31000, 'inbound_audio_packets': 320, 'inbound_audio_bytes': 12800},
            {'observed_at_unix_ms': 61000, 'inbound_audio_packets': 620, 'inbound_audio_bytes': 24800},
            {'observed_at_unix_ms': 91000, 'inbound_audio_packets': 920, 'inbound_audio_bytes': 36800},
            {'observed_at_unix_ms': 121000, 'inbound_audio_packets': 1220, 'inbound_audio_bytes': 48800},
        ]

        self.assertTrue(receiver_progressed_during_background(samples, 2000, 120000))

    def test_does_not_accept_packets_that_only_advanced_before_or_after_background(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 1500, 'inbound_audio_packets': 90, 'inbound_audio_bytes': 3600},
            {'observed_at_unix_ms': 121000, 'inbound_audio_packets': 90, 'inbound_audio_bytes': 3600},
            {'observed_at_unix_ms': 122000, 'inbound_audio_packets': 250, 'inbound_audio_bytes': 10000},
        ]

        self.assertFalse(receiver_progressed_during_background(samples, 2000, 120000))

    def test_requires_blackhole_pause_and_rtp_recovery_within_fifteen_seconds(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 5000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 60, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 7000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 60, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 9000, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
            {'observed_at_unix_ms': 12000, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
            {'observed_at_unix_ms': 14000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 12, 'inbound_audio_bytes': 600},
            {'observed_at_unix_ms': 16000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 22, 'inbound_audio_bytes': 1300},
        ]

        result = receiver_blackhole_recovery(samples, 5000, 13000)
        self.assertIsNotNone(result)
        self.assertEqual(result['recovery_seconds'], 1.0)
        self.assertEqual(result['receiver_last_during_blackhole']['inbound_audio_packets'], 0)

    def test_blackhole_recovery_fails_if_packets_never_pause_or_resume(self):
        continuous = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 6000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 70, 'inbound_audio_bytes': 2800},
            {'observed_at_unix_ms': 12000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 130, 'inbound_audio_bytes': 5200},
        ]
        no_recovery = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 6000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 12000, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
        ]
        self.assertIsNone(receiver_blackhole_recovery(continuous, 5000, 10000))
        self.assertIsNone(receiver_blackhole_recovery(no_recovery, 5000, 10000))

    def test_foreground_pair_requires_independent_inbound_audio_rtp(self):
        self.assertTrue(receiver_has_foreground_uplink({
            'inbound_audio_tracks': 1,
            'inbound_audio_packets': 2,
            'inbound_audio_bytes': 48,
        }))
        self.assertFalse(receiver_has_foreground_uplink({
            'inbound_audio_tracks': 0,
            'inbound_audio_packets': 0,
            'inbound_audio_bytes': 0,
        }))
        self.assertFalse(receiver_has_foreground_uplink({
            'inbound_audio_tracks': 1,
            'inbound_audio_packets': 2,
            'inbound_audio_bytes': 0,
        }))


if __name__ == '__main__':
    unittest.main()
