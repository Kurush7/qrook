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

#
# class FileBookImageCommand(QRCommand):
#     def __init__(self):
#         super().__init__('book_image', self.book_image, 'book_image')
#
#     @staticmethod
#     def book_image(path, storage):
#         managers = storage.get('managers')
#         ctx = create_context(managers=managers)
#
#         data = src.get_book_image(ctx, path)
#
#         response = FileResponse(data.status_code, data.result)
#         return response
#
#     def bind_command(self, console):
#         super().bind_command(console)
#         self.register_argument(CommandArgument('path', str, help='path'))
#         self._add_arguments()
#
# class FileSeriesImageCommand(QRCommand):
#     def __init__(self):
#         super().__init__('series_image', self.series_image, 'series_image')
#
#     @staticmethod
#     def series_image(path, storage):
#         managers = storage.get('managers')
#         ctx = create_context(managers=managers)
#
#         data = src.get_series_image(ctx, path)
#
#         response = FileResponse(data.status_code, data.result)
#         return response
#
#     def bind_command(self, console):
#         super().bind_command(console)
#         self.register_argument(CommandArgument('path', str, help='path'))
#         self._add_arguments()


# class AuthUpdateProfileCommand(QRCommand):
#     def __init__(self):
#         super().__init__('update_profile', self.update_profile, 'update_profile')
#
#     @staticmethod
#     def update_profile(storage, login, password, name=None, last_name=None, email=None,
#                        new_password=None):
#         rep = storage.get('auth_repository')
#         if rep is None:
#             raise Exception('no auth repository found')
#
#         managers = storage.get('managers')
#         token = storage.get('token')
#         if token is None:
#             raise Exception('token required by the operation')
#
#         ctx = create_context(form=drop_none({'name': name, 'last_name': last_name,
#                                         'email': email, 'login': login, 'password': password,
#                                         'new_password': new_password}),
#                              headers={'Authorization': 'Bearer ' + token},
#                              repository=rep, managers=managers)
#
#         data = src.update_user(ctx)
#
#         response = JsonResponse(data.status_code, data.result)
#         return response
#
#     def bind_command(self, console):
#         super().bind_command(console)
#         self.register_argument(CommandArgument('login', str, help='login'))
#         self.register_argument(CommandArgument('password', str, help='password'))
#         self.register_argument(CommandArgument('name', str, help='name', optional=True))
#         self.register_argument(CommandArgument('last_name', str, help='last_name', optional=True))
#         self.register_argument(CommandArgument('email', str, help='email', optional=True))
#         self.register_argument(CommandArgument('new_password', str, help='new_password', optional=True))
#         self._add_arguments()
#
#
#     def bind_command(self, console):
#         super().bind_command(console)
#

def create_file_methods(console):
    FileSaveAvatarCommand().bind_command(console)
    # FileBookImageCommand().bind_command(console)
    # FileSeriesImageCommand().bind_command(console)