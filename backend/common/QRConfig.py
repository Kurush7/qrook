import confuse
import pathlib
from collections import OrderedDict
from abc import abstractmethod
import distutils.util as util
import os

class IQRConfig:
    """abstract class for config"""

    @abstractmethod
    def read_config(self, *args):
        """read config and make fields avalable either as 'get' methods or as object's properties"""

    @abstractmethod
    def get(self, key: str):
        """return value of key. if value is a hierarchy itself, IQRConfig object is returned"""

    @abstractmethod
    def __getitem__(self, key: str):
        """return value of key. if value is a hierarchy itself, IQRConfig object is returned"""

class QRYamlConfig(IQRConfig):
    def __init__(self):
        self.data = dict()

    def __getitem__(self, key):
        return self.data.get(key)

    def get(self, key):
        return self.data.get(key)

    def read_config(self, config_name='config.yaml', directory=None):
        if directory is None:
            #directory = str(pathlib.Path(__file__).parent.absolute())
            directory = os.getcwd()
        config = confuse.Configuration('app')
        config.set_file(directory + '/' + config_name)

        for x in config:
            d = config[x].get()
            self.data[x] = self.__parse_dict(d)
            self.__dict__[x] = self.data[x]

    def __parse_dict(self, d):
        if not isinstance(d, OrderedDict):
            # d is string here
            if isinstance(d, bool):
                return d
            elif isinstance(d, int):
                return d
            elif d.replace('.', '', 1).isdigit():
                return float(d)
            return d

        obj = QRYamlConfig()
        for k, v in d.items():
            obj.data[k] = self.__parse_dict(v)
            obj.__dict__[k] = obj.data[k]
        return obj
