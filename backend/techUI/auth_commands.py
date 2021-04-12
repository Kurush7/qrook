import sys

sys.path.append('../auth_service')

from Command import *
import auth_service as src
from Response import *
from common_commands import *


class AuthLoginCommand(QRCommand):
    def __init__(self):
        super().__init__('login', self.login, 'login')

    @staticmethod
    def login(login, password, storage):
        rep = storage.get('auth_repository')
        if rep is None:
            raise Exception('no auth repository found')
        managers = storage.get('managers')
        ctx = create_context(json_data={'login': login, 'password': password},
                             repository=rep, managers=managers)

        data = src.login(ctx)
        if isinstance(data.result, dict):
            storage['token'] = data.result['access_token']

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('login', str, help='login'))
        self.register_argument(CommandArgument('password', str, help='password'))
        self._add_arguments()

class AuthRegisterCommand(QRCommand):
    def __init__(self):
        super().__init__('register', self.register, 'register')

    @staticmethod
    def register(name, last_name, email, login, password, storage):
        rep = storage.get('auth_repository')
        if rep is None:
            raise Exception('no auth repository found')

        managers = storage.get('managers')
        ctx = create_context(json_data={'name': name, 'last_name': last_name,
                                        'email': email, 'login': login, 'password': password},
                             repository=rep, managers=managers)

        data = src.register(ctx)
        if isinstance(data.result, dict):
            storage['token'] = data.result['access_token']

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('name', str, help='name'))
        self.register_argument(CommandArgument('last_name', str, help='last_name'))
        self.register_argument(CommandArgument('email', str, help='email'))
        self.register_argument(CommandArgument('login', str, help='login'))
        self.register_argument(CommandArgument('password', str, help='password'))
        self._add_arguments()

class AuthUserInfoCommand(QRCommand):
    def __init__(self):
        super().__init__('user_info', self.user_info, 'user_info')

    @staticmethod
    def user_info(storage):
        rep = storage.get('auth_repository')
        if rep is None:
            raise Exception('no auth repository found')
        managers = storage.get('managers')

        token = storage.get('token')
        if token is None:
            raise Exception('token required by the operation')

        ctx = create_context(headers={'Authorization': 'Bearer ' + token},
                             repository=rep, managers=managers)

        data = src.user_info(ctx)

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)

class AuthDeleteProfileCommand(QRCommand):
    def __init__(self):
        super().__init__('delete_profile', self.delete_profile, 'delete_profile')

    @staticmethod
    def delete_profile(storage):
        rep = storage.get('auth_repository')
        if rep is None:
            raise Exception('no auth repository found')
        managers = storage.get('managers')

        token = storage.get('token')
        if token is None:
            raise Exception('token required by the operation')

        ctx = create_context(headers={'Authorization': 'Bearer ' + token},
                             repository=rep, managers=managers)

        data = src.delete_profile(ctx)

        storage.pop('token')

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)

class AuthUpdateProfileCommand(QRCommand):
    def __init__(self):
        super().__init__('update_profile', self.update_profile, 'update_profile')

    @staticmethod
    def update_profile(storage, login, password, name=None, last_name=None, email=None,
                       new_password=None):
        rep = storage.get('auth_repository')
        if rep is None:
            raise Exception('no auth repository found')

        managers = storage.get('managers')
        token = storage.get('token')
        if token is None:
            raise Exception('token required by the operation')

        ctx = create_context(form=drop_none({'name': name, 'last_name': last_name,
                                        'email': email, 'login': login, 'password': password,
                                        'new_password': new_password}),
                             headers={'Authorization': 'Bearer ' + token},
                             repository=rep, managers=managers)

        data = src.update_user(ctx)

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('login', str, help='login'))
        self.register_argument(CommandArgument('password', str, help='password'))
        self.register_argument(CommandArgument('name', str, help='name', optional=True))
        self.register_argument(CommandArgument('last_name', str, help='last_name', optional=True))
        self.register_argument(CommandArgument('email', str, help='email', optional=True))
        self.register_argument(CommandArgument('new_password', str, help='new_password', optional=True))
        self._add_arguments()

class AuthLogoutCommand(QRCommand):
    def __init__(self):
        super().__init__('logout', self.logout, 'logout')

    @staticmethod
    def logout(storage):
        storage.pop('token')

        response = JsonResponse('internal request', 'ok')
        return response

    def bind_command(self, console):
        super().bind_command(console)


def create_auth_methods(console):
    AuthLoginCommand().bind_command(console)
    AuthRegisterCommand().bind_command(console)
    AuthUserInfoCommand().bind_command(console)
    AuthDeleteProfileCommand().bind_command(console)
    AuthLogoutCommand().bind_command(console)
    AuthUpdateProfileCommand().bind_command(console)
