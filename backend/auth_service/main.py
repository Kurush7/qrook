import sys
sys.path.append("..")
sys.path.append("../common")

from TokenManager import *
from AuthRepository import *

from FlaskServer import *
from IQRServer import *
from QRConfig import *
from dict_parsing import *
import requests

FILE_SERVICE_URL = None
FRONT_FILE_SERVICE_URL = 'http://localhost/files/'

def register(ctx: QRContext):
    data = ctx.json_data
    name = data['name']
    email = data['email']
    last_name = data['last_name']
    login = data['login']
    password = data['password']

    exists = ctx.repository.find_existing_user(email, login)
    if exists:
        if exists['email'] == email:
            return MethodResult('email exists', 500)
        else:
            return MethodResult('login exists', 500)

    user = ctx.repository.register_user(name, last_name, email, login, password)
    if user is None:
        return MethodResult('failed to insert into db', 500)

    jwt_token = ctx.managers['token_manager'].make_jwt_token(user['id'])
    user['access_token'] = jwt_token

    return MethodResult({'access_token': jwt_token})

def login(ctx: QRContext):
    login = ctx.json_data['login']
    password = ctx.json_data['password']
    user_id = ctx.repository.check_credentials(login, password)
    if user_id is None:
        return MethodResult('wrong credentials', 500)

    user = ctx.repository.get_user_preview(user_id)
    if user is None:
        return MethodResult('account not found', 500)

    jwt_token = ctx.managers['token_manager'].make_jwt_token(user_id)
    return MethodResult({'access_token': jwt_token})


@require_token()
def user_info(ctx: QRContext, user_id):
    user = ctx.repository.get_user_full(user_id)
    if user is None:
        return MethodResult('account not found', 500)

    user['avatar'] = FRONT_FILE_SERVICE_URL + 'avatar/' + user['avatar']
    parse_dict(user, rename={'surname': 'last_name'})
    return MethodResult(user)

@require_token()
def delete_profile(ctx: QRContext, user_id):
    ok = ctx.repository.delete_user(user_id)
    if not ok:
        return MethodResult('failed to delete profile', 500)
    return MethodResult('ok')


@require_token(send_token=True)
def update_user(ctx: QRContext, user_id, token):
    data = ctx.form
    login = data['login']
    password = data['password']
    name = data.get('name')
    email = data.get('email')
    last_name = data.get('last_name')
    new_password = data.get('new_password')

    given_user_id = ctx.repository.check_credentials(login, password)
    if user_id != given_user_id:
        return MethodResult('login and token are different', 500)

    avatar_file = ctx.files.get('avatar')
    if avatar_file:
        auth = {'Authorization': 'Bearer ' + token}
        data = requests.post(FILE_SERVICE_URL + 'files/save_avatar', headers=auth,
                             files={'avatar': avatar_file})
        data = data.json()
        avatar = data['filename']
    else: avatar = None

    user_id = ctx.repository.check_credentials(login, password)
    if user_id is None:
        return MethodResult('wrong credentials', 500)

    exists = ctx.repository.find_existing_user(email, login, all=True)
    if len(exists) > 1:
        return MethodResult('email exists', 500)

    ok = ctx.repository.update_user(user_id, None, new_password, name, last_name, email, avatar)
    if not ok:
        return MethodResult('failed to update user', 500)

    return MethodResult('ok')


class AuthServer(FlaskServer, AuthRepository):
    """DI class🐕"""


if __name__ == "__main__":
    config = QRYamlConfig()
    config.read_config('config.yaml')

    host = config['app']['host']
    port = config['app']['port']

    FILE_SERVICE_URL = config['services']['file_service']

    token_man = JwtTokenManager()
    token_man.load_config(config['jwt'])

    server = AuthServer()
    server.init_server(config['app'])
    if config['app']['logging']:
        server.configure_logger(config['app']['logging'])
    server.register_manager(token_man)
    server.connect_repository(config['database'])

    server.register_method('/auth/register', register, 'POST')
    server.register_method('/auth/login', login, 'POST')
    server.register_method('/auth/user_info', user_info, 'GET')
    server.register_method('/auth/edit_profile', update_user, 'POST')
    server.register_method('/auth/delete_profile', delete_profile, 'DELETE')
    server.run(host, port)
