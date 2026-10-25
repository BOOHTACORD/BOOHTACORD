import unittest
from .selection import ALL, select

class NotificationRoutingTests(unittest.TestCase):
    def test_shared_identity_chat_realtime_and_notification_edges_run_all_consumers(self):
        for path in ('backend/internal/notifications/dispatch_delivery/begin.go',
                     'backend/internal/pushrelay/fcm_provider/sender.go',
                     'backend/internal/chat/send_message/postgres/repository.go',
                     'backend/internal/identity/authenticate_session/postgres/read.go',
                     'backend/internal/realtime/event_hub/delivery.go',
                     'backend/internal/guild/update_settings/service.go',
                     'clients/web/src/notification/remote_push/devices.ts',
                     'clients/flutter/lib/src/features/notifications/mobile_driver/firebase_driver.dart',
                     'contracts/notification-payload-v1.schema.json'):
            with self.subTest(path=path):
                self.assertEqual(set(ALL), select([path]))
