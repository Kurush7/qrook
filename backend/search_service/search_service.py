import itertools
import sys

sys.path.append("..")
sys.path.append("../common")

import json
import random

from TokenManager import *
from SearchRepository import *

from FlaskServer import *
from IQRServer import *
from QRConfig import *
from dict_parsing import *
from Filters import *

FILE_SERVICE_URL = None
FRONT_FILE_SERVICE_URL = 'http://localhost/files/'

def shuffle_sorted(arr, get):
    n = len(arr)
    i = 0
    while i < n-1:
        s = i
        j = i + 1
        while get(arr[j]) == get(arr[j-1]):
            j += 1
            if j == n: break
        e = j
        copy = arr[s:e]
        random.shuffle(copy)
        i = j
        arr[s:e] = copy

def parse_url(url: str, build_with: str):
    if not url: return url
    if url.startswith('http'): return url
    return build_with + url

def manage_urls(data: dict):
    for k in data.keys():
        if isinstance(data[k], dict):
            manage_urls(data[k])
        if data.get('type') == 'book':
            if data.get('skin_image'):
                data['skin_image'] = parse_url(data['skin_image'], FRONT_FILE_SERVICE_URL + 'book_image/')
        if data.get('type') == 'series':
            if data.get('skin_image'):
                data['skin_image'] = parse_url(data['skin_image'], FRONT_FILE_SERVICE_URL + 'series_image/')
        if data.get('type') == 'author':
            if data.get('photo'):
                data['photo'] = parse_url(data['photo'], FRONT_FILE_SERVICE_URL + 'author_photo/')

def main(ctx: QRContext):
    offset = ctx.params.get('offset')
    limit = ctx.params.get('limit')
    filters = dict(ctx.params)

    offset = int(offset) if offset else 0
    limit = int(limit) if limit else 'all'

    bf = book_filter(filters)
    bf_skip0, magic_flag = bf['skip'], False

    for k in 'language format genres'.split(' '):
        if k in bf:
            bf['skip'] = False
            magic_flag = True
            if bf.get('search') and bf_skip0:
                bf.pop('search')

    cnt = int(not bf_skip0)
    if filters.get('find_author'): cnt += 1
    if filters.get('find_series'): cnt += 1
    if cnt == 0:
        return MethodResult([])

    limit1 = 1000 if limit == 'all' else int(limit // cnt)
    limit_remains = 0 if limit == 'all' else limit % cnt
    offset1 = int(offset // cnt)
    if bf_skip0:
        b_offset, b_limit = 0, 1000  # no limit
    else:
        b_offset, b_limit = offset1, limit1

    books = ctx.repository.get_filtered_books(bf, b_offset, b_limit)
    book_ids = [b['id'] for b in books]

    af = author_filter(filters, book_ids if magic_flag else None)
    authors = ctx.repository.get_filtered_authors(af, offset1 + offset % cnt, limit1 + limit_remains)

    sf = series_filter(filters, book_ids if magic_flag else None)
    series = ctx.repository.get_filtered_series(sf, offset1, limit1)

    if bf_skip0 == True:
        books = []
    data = list(itertools.chain.from_iterable([authors, series, books]))

    def parse_return(data):
        for i in range(len(data)):
            parse_dict(data[i], rename={'book_number': 'book_order'},
                       remove=['created_at', 'updated_at'])
            manage_urls(data[i])
        return MethodResult(data)

    sort_filter = filters.get('sort')
    if not sort_filter:
        return parse_return(data)

    # todo more beautiful sort
    reverse = sort_filter in ['name_desc', 'date_desc']
    if sort_filter.find('date') != -1:
        func = lambda x: x.get('updated_at')
    elif sort_filter.find('name') != -1:
        func = lambda x: x.get('title') if x.get('title') else x.get('name')
    elif sort_filter == 'series_order':
        func = lambda x: x.get('book_number')
    else:
        func = None
    data.sort(key=func, reverse=reverse)

    # todo probably useless
    shuffle_sorted(data, func)

    for i in range(len(data)):
        parse_dict(data[i], rename={'book_number': 'book_order'},
                   remove=['created_at', 'updated_at'])
    return parse_return(data)


def author(ctx: QRContext):
    id = int(ctx.params['id'])
    data = ctx.repository.get_full_author(id)
    if data is None:
        return MethodResult('author not found', 500)
    data = parse_dict(data, remove=['created_at', 'updated_at'])
    manage_urls(data)
    return MethodResult(data)


def series(ctx: QRContext):
    id = int(ctx.params['id'])
    data = ctx.repository.get_full_series(id)
    if data is None:
        return MethodResult('series not found', 500)
    data = parse_dict(data, remove=['created_at', 'updated_at'])
    manage_urls(data)
    return MethodResult(data)


def book(ctx: QRContext):
    id = int(ctx.params['id'])
    data = ctx.repository.get_full_book(id)
    if data is None:
        return MethodResult('book not found', 500)
    data = parse_dict(data, rename={'book_number': 'book_order'},
                      remove=['created_at', 'updated_at'])
    manage_urls(data)
    return MethodResult(data)


class SearchServer(FlaskServer, SearchRepository):
    """DI class🐕"""


if __name__ == "__main__":
    config = QRYamlConfig()
    config.read_config('config.yaml', )

    host = config['app']['host']
    port = config['app']['port']

    FILE_SERVICE_URL = config['services']['file_service']

    token_man = JwtTokenManager()
    token_man.load_config(config['jwt'])

    server = SearchServer()
    server.init_server(config['app'])
    if config['app']['logging']:
        server.configure_logger(config['app']['logging'])
    server.register_manager(token_man)
    server.connect_repository(config['database'])

    server.register_method('/search/main', main, 'GET')
    server.register_method('/search/author', author, 'GET')
    server.register_method('/search/series', series, 'GET')
    server.register_method('/search/book', book, 'GET')
    server.run(host, port)
