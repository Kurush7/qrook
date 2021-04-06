import sys
sys.path.append("..")
sys.path.append("../common")

from TokenManager import *
from ScoutRepository import *

from FlaskServer import *
from IQRServer import *
from QRConfig import *
from dict_parsing import *
import requests

@require_token()
def register_event(ctx: QRContext, user_id):
    data = ctx.json_data
    time = data['time']
    event = data['event']
    data = data.get('data')
    if data is None:
        data = dict()

    data['user'] = user_id

    ok = ctx.repository.register_event(time, event, data)
    if not ok:
        return MethodResult('failed to insert into db', 500)

    return MethodResult('ok')

class ScoutServer(FlaskServer, ScoutRepository):
    """DI class🐕"""


if __name__ == "__main__":
    config = QRYamlConfig()
    config.read_config('config.yaml')

    host = config['app']['host']
    port = config['app']['port']

    token_man = JwtTokenManager()
    token_man.load_config(config['jwt'])

    server = ScoutServer()
    server.init_server(config['app'])
    if config['app']['logging']:
        server.configure_logger(config['app']['logging'])
    server.register_manager(token_man)
    server.connect_repository(config['database'])

    server.register_method('/scout/register_event', register_event, 'POST')
    server.run(host, port)
