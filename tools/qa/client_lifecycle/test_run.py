import unittest

from .run import catalog_capture_plan, viewport_profile


class ViewportProfileTests(unittest.TestCase):
    def test_mobile_profile_matches_reference_css_viewport_and_touch_surface(self):
        self.assertEqual(viewport_profile(393), {
            'name': 'mobile-393x852',
            'width': 393,
            'height': 852,
            'is_mobile': True,
            'device_scale_factor': 3,
            'has_touch': True,
        })

    def test_mobile_profile_matches_issue_290_reference_viewport(self):
        self.assertEqual(viewport_profile(390), {
            'name': 'mobile-390x844',
            'width': 390,
            'height': 844,
            'is_mobile': True,
            'device_scale_factor': 3,
            'has_touch': True,
        })

    def test_tablet_and_desktop_profiles_keep_explicit_target_heights(self):
        self.assertEqual(viewport_profile(1024), {
            'name': 'tablet-1024x768',
            'width': 1024,
            'height': 768,
            'is_mobile': False,
            'device_scale_factor': 1,
            'has_touch': False,
        })
        self.assertEqual(viewport_profile(1440), {
            'name': 'desktop-1440x900',
            'width': 1440,
            'height': 900,
            'is_mobile': False,
            'device_scale_factor': 2,
            'has_touch': False,
        })

    def test_unsupported_width_is_rejected(self):
        with self.assertRaises(ValueError):
            viewport_profile(391)


class CatalogCapturePlanTests(unittest.TestCase):
    def test_mobile_plan_covers_navigation_channel_and_touch_message_actions(self):
        self.assertEqual(catalog_capture_plan(393), [
            ('M01', 'navigation-overlay.png'),
            ('M02', 'channel-text.png'),
            ('M03', 'channel-text-actions.png'),
            ('M22', 'voice-prejoin.png'),
            ('M23', 'channel-log.png'),
        ])

    def test_desktop_plan_covers_channel_message_actions_and_dm_list(self):
        self.assertEqual(catalog_capture_plan(1440), [
            ('D01', 'channel-text.png'),
            ('D02', 'channel-text-actions.png'),
            ('D03', 'dm-list.png'),
            ('D15', 'voice-prejoin.png'),
            ('D18', 'channel-log.png'),
        ])

    def test_non_catalog_viewports_do_not_claim_source_sized_captures(self):
        self.assertEqual(catalog_capture_plan(390), [])
        self.assertEqual(catalog_capture_plan(1024), [])


if __name__ == '__main__':
    unittest.main()
