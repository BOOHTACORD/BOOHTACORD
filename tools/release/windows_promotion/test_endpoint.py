"""A public catalog read requires the exact selector/revision/target and no caching."""
import io
import json
import unittest
from . import endpoint
from .test_intent import catalogs


class Response(io.BytesIO):
    status=200
    headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Type':'application/json'}
    def __enter__(self):return self
    def __exit__(self,*args):self.close()


class EndpointTests(unittest.TestCase):
    def test_exact_public_policy_and_safe_request_headers(self):
        _,catalog=catalogs();value=endpoint.expected(catalog)
        def request(req):
            self.assertNotIn('Authorization',req.headers);self.assertNotIn('Cookie',req.headers)
            return Response(json.dumps(value).encode())
        result=endpoint.observe(catalog,request)
        self.assertEqual(result['status'],'PASS')
        for change in ('revision','selector','url','cache','status'):
            policy=endpoint.expected(catalog);response=Response(b'')
            if change=='revision':policy['catalog_revision']-=1
            if change=='selector':policy['arch']='arm64'
            if change=='url':policy['target']['action']['url']='https://other.test'
            response=Response(json.dumps(policy).encode())
            if change=='cache':response.headers={**Response.headers,'Cache-Control':'public, max-age=60'}
            if change=='status':response.status=503
            with self.subTest(change=change),self.assertRaises(ValueError):endpoint.observe(catalog,lambda _:response)
