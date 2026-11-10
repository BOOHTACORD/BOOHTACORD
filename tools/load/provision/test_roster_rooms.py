import unittest

from tools.load.provision.dataset import roster_room_count


class RosterRoomsTest(unittest.TestCase):
    def test_default_preserves_logical_voice_capacity(self):
        self.assertEqual([roster_room_count(n, None) for n in (1, 20, 21, 100)], [1, 1, 2, 5])

    def test_requested_matrix_rooms_are_independent_of_account_count(self):
        for count in (1, 10, 25, 50, 100):
            for rooms in (0, 1, 5, 20):
                self.assertEqual(roster_room_count(count, rooms), rooms)

    def test_invalid_bounds_and_boolean_are_rejected(self):
        for rooms in (-1, 21, True, 1.5, '1'):
            with self.subTest(rooms=rooms), self.assertRaises(ValueError):
                roster_room_count(1, rooms)
        for count in (0, 101, True):
            with self.subTest(count=count), self.assertRaises(ValueError):
                roster_room_count(count, 0)
