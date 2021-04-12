import sys
sys.path.append('..')

from Console import *
from auth_commands import *
from search_commands import *
from scout_commands import *
from file_commands import *
from common.QRConfig import *
from common.TokenManager import *
from common.FileManager import *
from AuthRepository import *
from SearchRepository import *
from ScoutRepository import *

if __name__ == '__main__':
    config = QRYamlConfig()
    config.read_config('config.yaml')

    console = QRConsole()

    token_man = JwtTokenManager()
    token_man.load_config(config['jwt'])
    file_man = FlaskFileManager()
    console.add_to_storage('managers', [token_man, file_man])

    auth_rep = AuthRepository()
    auth_rep.connect_repository(config['database'])
    console.add_to_storage('auth_repository', auth_rep)
    create_auth_methods(console)

    search_rep = SearchRepository()
    search_rep.connect_repository(config['database'])
    console.add_to_storage('search_repository', search_rep)
    create_search_methods(console)

    scout_rep = ScoutRepository()
    scout_rep.connect_repository(config['database'])
    console.add_to_storage('scout_repository', scout_rep)
    create_scout_methods(console)

    create_file_methods(console)

    console.run()