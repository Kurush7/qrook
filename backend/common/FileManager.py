from flask import send_from_directory
from IQRServer import *
from abc import abstractmethod


class IFileManager(IQRManager):
    @staticmethod
    def get_name() -> str:
        return "file_manager"

    @abstractmethod
    def send_file(self, dirname, filename):
        """send file"""

class FlaskFileManager(IFileManager):
    def __init__(self):
        self.secret = None
        self.algorithm = None
        self.exp = None

    def send_file(self, dirname, filename):
        return send_from_directory(dirname, filename)


class MockFileManager(IFileManager):
    def send_file(self, dirname, filename):
        if filename in ['a', 'b', 'c']: return filename
        return 'file not found'
