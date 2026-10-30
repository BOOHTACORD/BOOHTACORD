import unittest
from .test_support import API,execute


class NativeOnlyReadbackTests(unittest.TestCase):
    def test_verified_native_only_route_is_not_a_failed_or_successful_deployment(self):
        value,receipts,endpoints=execute(API())
        self.assertEqual(value['status'],'NOT_RUN')
        self.assertEqual(value['reason'],'native_only_no_server_release')
        self.assertEqual(value['physical_acceptance'],'NOT_RUN')
        self.assertEqual((receipts,endpoints),(0,0))

    def test_required_install_without_delivery_receipt_still_fails_closed(self):
        api=API();api.job_rows[456][1]['conclusion']='success'
        value,receipts,endpoints=execute(api)
        self.assertEqual(value['status'],'FAIL')
        self.assertEqual(value['failure_stage'],'deployment')
        self.assertEqual((receipts,endpoints),(1,0))
