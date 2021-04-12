import sys
import os
cur = os.path.dirname(os.path.abspath(__file__))
sys.path.append(cur)
sys.path.append(cur+"/..")
sys.path.append(cur+"/../common")

import unittest
from IQRServer import QRContext
from IQRRepository import IQRRepository
from scout_service import *
from TokenManager import MockTokenManager
from ScoutRepository import *


class MockScoutRepository(IScoutRepository, IQRRepository):
    def connect_repository(self, config):
        pass

    def register_event(self, user_id, time, event: str, data: dict):
        if user_id == 1:
            return True
        else:
            return False


def create_context(json_data=dict(), params=dict(), headers=dict(), form=dict(), files=dict()):
    ctx = QRContext(json_data, params, headers, form, files, repository=MockScoutRepository())
    ctx.add_manager(MockTokenManager.get_name(), MockTokenManager())
    return ctx


def token_validation(func):
    res1 = func(create_context())
    res2 = func(create_context(headers={'Authorization': ''}))
    return res1.status_code == res2.status_code == 401


class TestRegisterEvent(unittest.TestCase):
    def test_all_data(self):
        token = MockTokenManager().make_token(user_id=1)
        res = register_event(create_context(headers={'Authorization': token},
                                                json_data={'time': 12345, 'event': 'a', 'data': {'a': 'a', 'b': 'b'}}))
        self.assertEqual(200, res.status_code)

    def test_no_data(self):
        token = MockTokenManager().make_token(user_id=1)
        res = register_event(create_context(headers={'Authorization': token},
                                                json_data={'time': 12345, 'event': 'a'}))
        self.assertEqual(200, res.status_code)

    def test_failure(self):
        token = MockTokenManager().make_token(user_id=2)
        res = register_event(create_context(headers={'Authorization': token},
                                                json_data={'time': 12345, 'event': 'a'}))
        self.assertEqual(500, res.status_code)


    def test_token_validation(self):
        self.assertTrue(token_validation(register_event))