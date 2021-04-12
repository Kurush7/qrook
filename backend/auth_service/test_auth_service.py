import sys
import os
import pytest
cur = os.path.dirname(os.path.abspath(__file__))
sys.path.append(cur)
sys.path.append(cur+"/..")
sys.path.append(cur+"/../common")

from AuthRepository import IAuthRepository
import unittest
from IQRServer import QRContext
from IQRRepository import IQRRepository
from auth_service import *
from TokenManager import MockTokenManager


class MockAuthRepository(IAuthRepository, IQRRepository):
    def connect_repository(self, config):
        pass

    def check_credentials(self, login, password):
        if (login, password) == ('a', 'a'): return 1
        if (login, password) == ('b', 'b'): return 2
        else: return None

    def find_existing_user(self, email, login, all=False):
        found = []
        if email == 'a@a.ru' or login == 'a': found.append({'email': email, 'login': login})
        if email == 'b@b.ru' or login == 'b': found.append({'email': email, 'login': login})
        if len(found) == 0: return None if not all else []
        return found[0] if not all else found

    def register_user(self, name, last_name, email, login, password):
        if login == 'c':
            return {'id': 3, 'name': name, 'surname': last_name}
        else: return None

    def update_user(self, id, login=None, password=None, name=None, last_name=None, email=None, avatar=None):
        if id == 1: return True
        return False

    def get_user_preview(self, user_id):
        if user_id == 1: return {'id': 1, 'name': 'a', 'surname': 'a', 'avatar': None}
        else: return None

    def get_user_full(self, user_id):
        if user_id == 1: return {'id': 1, 'name': 'a', 'surname': 'a', 'avatar': None, 'email': 'a@a.ru', 'login': 'a'}
        else: return None

    def delete_user(self, user_id):
        if user_id == 1: return True
        else: return False


def create_context(json_data=dict(), params=dict(), headers=dict(), form=dict(), files=dict()):
    ctx = QRContext(json_data, params, headers, form, files, repository=MockAuthRepository())
    ctx.add_manager(MockTokenManager.get_name(), MockTokenManager())
    return ctx

def token_validation(func):
    res1 = func(create_context())
    res2 = func(create_context(headers={'Authorization': ''}))
    return res1.status_code == res2.status_code == 401


class TestLogin(unittest.TestCase):
    def test_success(self):
        res = login(create_context(json_data={'login': 'a', 'password': 'a'}))
        self.assertEqual(200, res.status_code)
        self.assertEqual('Bearer 1', res.result['access_token'])

    def test_failure(self):
        res = login(create_context(json_data={'login': 'a', 'password': 'b'}))
        self.assertEqual(500, res.status_code)
        self.assertEqual('wrong credentials', res.result)


class TestRegister(unittest.TestCase):
    def test_success(self):
        res = register(create_context(json_data={'login': 'c', 'password': 'c', 'name': 'c', 'last_name': 'c', 'email': 'c'}))
        self.assertEqual(200, res.status_code)
        self.assertEqual('Bearer 3', res.result['access_token'])

    def test_login_exists(self):
        res = register(create_context(json_data={'login': 'a', 'password': 'c', 'name': 'c', 'last_name': 'c', 'email': 'c'}))
        self.assertEqual(500, res.status_code)
        self.assertTrue(res.result.find('exists') != -1)

    def test_email_exists(self):
        res = register(create_context(json_data={'login': 'c', 'password': 'c', 'name': 'c', 'last_name': 'c', 'email': 'b@b.ru'}))
        self.assertEqual(500, res.status_code)
        self.assertTrue(res.result.find('exists') != -1)

    def test_insert_failed(self):
        res = register(create_context(json_data={'login': 'd', 'password': 'd', 'name': 'd', 'last_name': 'd', 'email': 'd@d.ru'}))
        self.assertEqual(500, res.status_code)
        self.assertTrue(isinstance(res.result, str))


class TestUserInfo(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = user_info(create_context(headers={'Authorization': token}))
        self.assertEqual(200, res.status_code)
        self.assertEqual({'id': 1, 'name': 'a', 'last_name': 'a', 'avatar': None, 'email': 'a@a.ru', 'login': 'a'}, res.result)

    def test_token_validation(self):
        self.assertTrue(token_validation(user_info))

    def test_not_found(self):
        token = MockTokenManager().make_token(user_id=2)
        res = user_info(create_context(headers={'Authorization': token}))
        self.assertEqual(500, res.status_code)
        self.assertNotEqual(res.result.find('not found'), -1)


class TestDeleteProfile(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = delete_profile(create_context(headers={'Authorization': token}))
        self.assertEqual(200, res.status_code)

    def test_token_validation(self):
        self.assertTrue(token_validation(delete_profile))

    def test_failure(self):
        token = MockTokenManager().make_token(user_id=2)
        res = delete_profile(create_context(headers={'Authorization': token}))
        self.assertEqual(500, res.status_code)

class TestUpdateUser(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = update_user(create_context(form={'login':'a', 'password':'a', 'name': 'c'}, headers={'Authorization': token}))
        self.assertEqual(200, res.status_code)

    def test_token_validation(self):
        self.assertTrue(token_validation(update_user))

    def test_wrong_credentials(self):
        token = MockTokenManager().make_token(user_id=1)
        res = update_user(create_context(form={'login':'a', 'password':'c'}, headers={'Authorization': token}))
        self.assertEqual(500, res.status_code)

    def test_login_not_exists(self):
        token = MockTokenManager().make_token(user_id=1)
        res = update_user(create_context(form={'login':'x', 'password':'x'}, headers={'Authorization': token}))
        self.assertEqual(500, res.status_code)

    def test_new_email_exists(self):
        token = MockTokenManager().make_token(user_id=1)
        res = update_user(create_context(form={'login':'a', 'password':'a', 'email': 'b@b.ru'}, headers={'Authorization': token}))
        self.assertEqual(500, res.status_code)

    def test_failed_to_update(self):
        token = MockTokenManager().make_token(user_id=2)
        res = update_user(create_context(form={'login':'b', 'password':'b'}, headers={'Authorization': token}))
        self.assertEqual(500, res.status_code)