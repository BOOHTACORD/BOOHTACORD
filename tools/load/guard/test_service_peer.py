import sqlite3
import unittest
from unittest.mock import patch
from types import SimpleNamespace
from .ownership import verify_marker

class ServicePeerDatasetTests(unittest.TestCase):
    def test_only_the_registered_service_peer_is_excluded_from_human_inventory(self):
        db=sqlite3.connect(':memory:');db.create_function('current_database',0,lambda:'qa')
        db.executescript("""CREATE TABLE users(id text,login text);CREATE TABLE support_product_identity(account_id text);
        CREATE TABLE qa_load_fixture(owner text,nonce text,account_count integer);
        INSERT INTO users VALUES('admin','qa_admin'),('actor','qa_load_000'),('service','support.synthetic');
        INSERT INTO support_product_identity VALUES('service');INSERT INTO qa_load_fixture VALUES('owned','proof',1);""")
        def query(_stack,sql):return '|'.join(str(x) for x in db.execute(sql).fetchone())
        with patch('tools.load.guard.ownership.query',side_effect=query):
            verify_marker(SimpleNamespace(owner='owned'),'proof',1)
            db.execute("INSERT INTO users VALUES('foreign','unexpected_person')")
            with self.assertRaises(ValueError):verify_marker(SimpleNamespace(owner='owned'),'proof',1)
        db.close()

if __name__=='__main__':unittest.main()
