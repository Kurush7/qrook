import sys

sys.path.append('../file_service')

from Command import *
import file_service as src
from Response import *
from common_commands import *


class FileSaveAvatarCommand(QRCommand):
    def __init__(self):
        super().__init__('save_avatar', self.save_avatar, 'save_avatar')

    @staticmethod
    def save_avatar(storage):
        response = JsonResponse('internal request', 'save_avatar\'s currently unavailable')
        return response

    def bind_command(self, console):
        super().bind_command(console)


class FileBookImageCommand(QRCommand):
    def __init__(self):
        super().__init__('book_image', self.book_image, 'book_image')

    @staticmethod
    def book_image(path, storage):
        managers = storage.get('managers')
        ctx = create_context(managers=managers)

        data = src.get_book_image(ctx, path)

        response = FileResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('path', str, help='path'))
        self._add_arguments()

class FileSeriesImageCommand(QRCommand):
    def __init__(self):
        super().__init__('series_image', self.series_image, 'series_image')

    @staticmethod
    def series_image(path, storage):
        managers = storage.get('managers')
        ctx = create_context(managers=managers)

        data = src.get_series_image(ctx, path)

        response = FileResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('path', str, help='path'))
        self._add_arguments()

class FileAuthorPhotoCommand(QRCommand):
    def __init__(self):
        super().__init__('author_photo', self.author_photo, 'author_photo')

    @staticmethod
    def author_photo(path, storage):
        managers = storage.get('managers')
        ctx = create_context(managers=managers)

        data = src.get_author_photo(ctx, path)

        response = FileResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('path', str, help='path'))
        self._add_arguments()

class FileAvatarCommand(QRCommand):
    def __init__(self):
        super().__init__('get_avatar', self.get_avatar, 'get_avatar')

    @staticmethod
    def get_avatar(path, storage):
        managers = storage.get('managers')
        ctx = create_context(managers=managers)

        data = src.get_avatar(ctx, path)

        response = FileResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('path', str, help='path'))
        self._add_arguments()



class FileBookCommand(QRCommand):
    def __init__(self):
        super().__init__('get_book', self.get_book, 'get_book')

    @staticmethod
    def get_book(storage, path):
        managers = storage.get('managers')
        token = storage.get('token')
        if token is None:
            raise Exception('token required by the operation')

        ctx = create_context(headers={'Authorization': 'Bearer ' + token},
                             managers=managers)

        data = src.get_book(ctx, filename=path)

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('path', str, help='file path'))
        self._add_arguments()

    def bind_command(self, console):
        super().bind_command(console)


def create_file_methods(console):
    FileSaveAvatarCommand().bind_command(console)
    FileBookImageCommand().bind_command(console)
    FileSeriesImageCommand().bind_command(console)
    FileAuthorPhotoCommand().bind_command(console)
    FileAvatarCommand().bind_command(console)
    FileBookCommand().bind_command(console)