import sys
from pathlib import Path
sys.path.append("..")
sys.path.append("../common")

from TokenManager import *
from FileManager import *

from FlaskServer import *
from IQRServer import *
from QRConfig import *

UPLOAD_FOLDER = 'static/'
BOOKS_FOLDER = 'books/'
AVATARS_FOLDER = UPLOAD_FOLDER + 'images/avatars'


def get_book_image(ctx: QRContext, filename):
    man = ctx.managers['file_manager']
    return MethodResult(
        man.send_file(UPLOAD_FOLDER + 'images/book_images', filename),
        raw_data=True)


def get_author_photo(ctx: QRContext, filename):
    man = ctx.managers['file_manager']
    return MethodResult(
        man.send_file(UPLOAD_FOLDER + 'images/author_photos', filename),
        raw_data=True)


def get_avatar(ctx: QRContext, filename):
    man = ctx.managers['file_manager']
    return MethodResult(
        man.send_file(AVATARS_FOLDER, filename),
        raw_data=True)


def get_series_image(ctx: QRContext, filename):
    man = ctx.managers['file_manager']
    return MethodResult(
        man.send_file(UPLOAD_FOLDER + 'images/series_images', filename),
        raw_data=True)


@require_token()
def get_book(ctx: QRContext, req_path, user_id):
    man = ctx.managers['file_manager']
    dir = req_path[:req_path.rfind('/')]
    file = req_path[req_path.rfind('/')+1:]
    return MethodResult(
        man.send_file(BOOKS_FOLDER + dir, file),
        raw_data=True)


@require_token()
def save_avatar(ctx: QRContext, user_id):
    avatar = ctx.files['avatar']
    filename = str(user_id) + '.jpg'
    Path(AVATARS_FOLDER).mkdir(parents=True, exist_ok=True)
    avatar.save(os.path.join(AVATARS_FOLDER, filename))

    return MethodResult({'filename': filename})


class FileServer(FlaskServer):
    """DI class🐕"""


if __name__ == "__main__":
    config = QRYamlConfig()
    config.read_config('config.yaml', )

    host = config['app']['host']
    port = config['app']['port']

    server = FileServer()
    server.init_server(config['app'])
    if config['app']['logging']:
        server.configure_logger(config['app']['logging'])

    token_man = JwtTokenManager()
    token_man.load_config(config['jwt'])
    server.register_manager(token_man)

    file_man = FlaskFileManager()
    server.register_manager(file_man)

    server.register_method('/files/book_image/<filename>', get_book_image, 'GET')
    server.register_method('/files/author_photo/<filename>', get_author_photo, 'GET')
    server.register_method('/files/avatar/<filename>', get_avatar, 'GET')
    server.register_method('/files/series_image/<filename>', get_series_image, 'GET')
    server.register_method('/files/book/<path:req_path>', get_book, 'GET')
    server.register_method('/files/save_avatar', save_avatar, 'POST')
    server.run(host, port)
