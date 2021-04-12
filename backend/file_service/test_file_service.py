import sys
import os
cur = os.path.dirname(os.path.abspath(__file__))
sys.path.append(cur)
sys.path.append(cur+"/..")
sys.path.append(cur+"/../common")

import unittest
from IQRServer import QRContext
from file_service import *
from TokenManager import MockTokenManager
from IQRRepository import *
from FileManager import MockFileManager

# todo add save_avatar test

def create_context(json_data=dict(), params=dict(), headers=dict(), form=dict(), files=dict()):
    ctx = QRContext(json_data, params, headers, form, files, repository=IQRRepository())
    ctx.add_manager(MockTokenManager.get_name(), MockTokenManager())
    ctx.add_manager(MockFileManager.get_name(), MockFileManager())
    return ctx

def token_validation(func):
    res1 = func(create_context())
    res2 = func(create_context(headers={'Authorization': ''}))
    return res1.status_code == res2.status_code == 401


class TestGetBookImage(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_book_image(create_context(headers={'Authorization': token}), 'a')
        self.assertEqual(200, res.status_code)
        self.assertEqual('a', res.result)

    def test_failure(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_book_image(create_context(headers={'Authorization': token}), 'xxx')
        self.assertEqual('file not found', res.result)

class TestGetSeriesImage(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_series_image(create_context(headers={'Authorization': token}), 'a')
        self.assertEqual(200, res.status_code)
        self.assertEqual('a', res.result)

    def test_failure(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_series_image(create_context(headers={'Authorization': token}), 'xxx')
        self.assertEqual('file not found', res.result)

class TestGetAuthorPhoto(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_author_photo(create_context(headers={'Authorization': token}), 'a')
        self.assertEqual(200, res.status_code)
        self.assertEqual('a', res.result)

    def test_failure(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_author_photo(create_context(headers={'Authorization': token}), 'xxx')
        self.assertEqual('file not found', res.result)

class TestGetAvatar(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_avatar(create_context(headers={'Authorization': token}), 'a')
        self.assertEqual(200, res.status_code)
        self.assertEqual('a', res.result)

    def test_failure(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_avatar(create_context(headers={'Authorization': token}), 'xxx')
        self.assertEqual('file not found', res.result)

class TestGetBook(unittest.TestCase):
    def test_success(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_book(create_context(headers={'Authorization': token}), 'a')
        self.assertEqual(200, res.status_code)
        self.assertEqual('a', res.result)

    def test_failure(self):
        token = MockTokenManager().make_token(user_id=1)
        res = get_book(create_context(headers={'Authorization': token}), 'xxx')
        self.assertEqual('file not found', res.result)
