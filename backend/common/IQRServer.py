from abc import abstractmethod, abstractproperty
import IQRRepository as rep
import QRLogger as log
import QRConfig as conf

class IQRManager:
    """abstract manager class"""
    @staticmethod
    @abstractmethod
    def get_name() -> str:
        """how the manager is named"""


class QRContext:
    """object representing the request context, providing wrap around request's body and headers
    as well as repository instance and other possible managers"""

    def __init__(self, json_data, params, headers, form, files, repository: rep.IQRRepository):
        self.__json_data = json_data
        self.__params = params
        self.__headers = headers
        self.__rep = repository
        self.__form = form
        self.__files = files
        self.managers = dict()

    def get_json_data(self): return self.__json_data

    def get_params(self): return self.__params

    def get_headers(self): return self.__headers

    def get_form(self): return self.__form

    def get_files(self): return self.__files

    def get_repository(self): return self.__rep

    def get_manager(self, name):
        return self.managers.get(name)

    params = property(get_params)
    json_data = property(get_json_data)
    headers = property(get_headers)
    form = property(get_form)
    files = property(get_files)
    repository = property(get_repository)

    def add_manager(self, name, manager: IQRManager):
        self.managers[name] = manager

    def set_managers(self, managers):
        self.managers = managers


class IQRContextCreator:
    @abstractmethod
    def create_context(self, *args) -> QRContext:
        """create request's context using given data"""


class MethodResult:
    def __init__(self, result=None, status_code=None, raw_data=False):
        if status_code is None: status_code = 200
        self.result = result
        self.status_code = status_code
        self.raw_data = raw_data


class IQRServer(rep.IQRRepository, log.IQRLogger, IQRContextCreator):
    @abstractmethod
    def init_server(self, configuration: conf.IQRConfig):
        """initialize server"""

    @abstractmethod
    def run(self, host, port):
        """run the server"""

    @abstractmethod
    def register_method(self, route: str, f, method_type: str):
        """
        register method. Server provides positional QRContext argument and transfers all other *arg and **kwarg arguments
        :param method_type: one of 'GET', 'POST', 'PUT'
        """

    @abstractmethod
    def register_manager(self, manager: IQRManager):
        """
        register manager
        :param manager: the manager itself
        :return:
        """
