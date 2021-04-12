import sys
import os
cur = os.path.dirname(os.path.abspath(__file__))
sys.path.append(cur)
sys.path.append(cur+"/..")
sys.path.append(cur+"/../common")

from SearchRepository import ISearchRepository
import unittest
from IQRServer import QRContext
from IQRRepository import IQRRepository
from search_service import *
from TokenManager import MockTokenManager


class MockSearchRepository(ISearchRepository, IQRRepository):
    def connect_repository(self, config):
        pass

    def get_full_author(self, id):
        if id == 1: return {'id': id}
        return None

    def get_full_series(self, id):
        if id == 1: return {'id': id}
        return None

    def get_full_book(self, id):
        if id == 1: return {'id': id}
        return None

    def get_filtered_books(self, filters: dict, offset=0, limit=100):
        return [{'id': 1}]

    def get_filtered_authors(self, filters: dict, offset=0, limit=100):
        return [{'id': 1}]

    def get_filtered_series(self, filters: dict, offset=0, limit=100):
        return [{'id': 1}]


def create_context(json_data=dict(), params=dict(), headers=dict(), form=dict(), files=dict()):
    ctx = QRContext(json_data, params, headers, form, files, repository=MockSearchRepository())
    ctx.add_manager(MockTokenManager.get_name(), MockTokenManager())
    return ctx


class TestGetBook(unittest.TestCase):
    def test_success(self):
        res = book(create_context(params={'id': 1}))
        self.assertEqual(200, res.status_code)
        self.assertEqual({'id': 1}, res.result)

    def test_not_found(self):
        res = book(create_context(params={'id': 2}))
        self.assertEqual(500, res.status_code)


class TestGetSeries(unittest.TestCase):
    def test_success(self):
        res = series(create_context(params={'id': 1}))
        self.assertEqual(200, res.status_code)
        self.assertEqual({'id': 1}, res.result)

    def test_not_found(self):
        res = series(create_context(params={'id': 2}))
        self.assertEqual(500, res.status_code)


class TestGetAuthor(unittest.TestCase):
    def test_success(self):
        res = author(create_context(params={'id': 1}))
        self.assertEqual(200, res.status_code)
        self.assertEqual({'id': 1}, res.result)

    def test_not_found(self):
        res = author(create_context(params={'id': 2}))
        self.assertEqual(500, res.status_code)


class TestMain(unittest.TestCase):
    # todo add filters test
    def test_find_all(self):
        res = main(create_context(params={'find_book': True, 'find_series': True, 'find_author': True}))
        self.assertEqual(200, res.status_code)
        self.assertEqual(3, len(res.result))

    def test_find_none(self):
        res = main(create_context(params={}))
        self.assertEqual(200, res.status_code)
        self.assertEqual(0, len(res.result))