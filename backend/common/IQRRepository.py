from abc import abstractmethod, abstractproperty
import QRConfig as conf
from qrookDB.DB import DB

class IQRRepository:
    """abstract class representing the Repository object - one providing data-managing functions"""
    @abstractmethod
    def connect_repository(self, configuration: conf.IQRConfig):
        """initialize repository with configuration given"""


class QRRepository(IQRRepository):
    def __init__(self):
        self.db = None

    def connect_repository(self, config: conf.IQRConfig):
        conn = [config['connector'],
                config['dbname'],
                config['username'],
                config['password'],
                config['host'],
                config['port']
                ]
        self.db = DB(*conn, format_type='dict')
        self.db.create_data()
        if config['logging']:
            lg = config['logging']
            fl = config['level']\
                if lg['file_level'] is None else lg['file_level']
            fl = fl.upper()
            self.db.create_logger(lg['logger_name'], lg['app_name'], lg['level'].upper(), lg['file'], fl)