import sys

sys.path.append('../search_service')

from Command import *
import search_service as src
from Response import *
from common_commands import *


class SearchMainCommand(QRCommand):
    def __init__(self):
        super().__init__('main', self.main, 'main')

    @staticmethod
    def main(storage, **kwargs):
        rep = storage.get('search_repository')
        if rep is None:
            raise Exception('no search repository found')
        managers = storage.get('managers')
        ctx = create_context(params=kwargs,
                             repository=rep, managers=managers)

        data = src.main(ctx)

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('search', str, help='limit', optional=True),)
        self.register_argument(CommandArgument('find_book', bool, help='find_book', optional=True),)
        self.register_argument(CommandArgument('find_series', bool, help='find_series', optional=True),)
        self.register_argument(CommandArgument('find_author', bool, help='find_author', optional=True),)
        self.register_argument(CommandArgument('author_id', int, help='author_id', optional=True),)
        self.register_argument(CommandArgument('series_id', int, help='series_id', optional=True),)
        self.register_argument(CommandArgument('language', str, help='language', optional=True),)
        self.register_argument(CommandArgument('format', str, help='format', optional=True),)
        self.register_argument(CommandArgument('genres', str, help='genres', optional=True),)
        self.register_argument(CommandArgument('limit', int, help='limit', optional=True),)
        self.register_argument(CommandArgument('offset', int, help='offset', optional=True),)
        self._add_arguments()

class SearchSeriesCommand(QRCommand):
    def __init__(self):
        super().__init__('series', self.series, 'series')


class SearchBookCommand(QRCommand):
    def __init__(self):
        super().__init__('book', self.book, 'book')

    @staticmethod
    def book(id, storage):
        rep = storage.get('search_repository')
        if rep is None:
            raise Exception('no search repository found')
        managers = storage.get('managers')
        ctx = create_context(params={'id': id},
                             repository=rep, managers=managers)

        data = src.book(ctx)

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('id', int, help='author id'))
        self._add_arguments()

class SearchSeriesCommand(QRCommand):
    def __init__(self):
        super().__init__('series', self.series, 'series')

    @staticmethod
    def series(id, storage):
        rep = storage.get('search_repository')
        if rep is None:
            raise Exception('no search repository found')
        managers = storage.get('managers')
        ctx = create_context(params={'id': id},
                             repository=rep, managers=managers)

        data = src.series(ctx)

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('id', int, help='author id'))
        self._add_arguments()


class SearchAuthorCommand(QRCommand):
    def __init__(self):
        super().__init__('author', self.author, 'author')

    @staticmethod
    def author(id, storage):
        rep = storage.get('search_repository')
        if rep is None:
            raise Exception('no search repository found')
        managers = storage.get('managers')
        ctx = create_context(params={'id': id},
                             repository=rep, managers=managers)

        data = src.author(ctx)

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('id', int, help='author id'))
        self._add_arguments()




def create_search_methods(console):
    SearchBookCommand().bind_command(console)
    SearchSeriesCommand().bind_command(console)
    SearchAuthorCommand().bind_command(console)
    SearchMainCommand().bind_command(console)
