from abc import abstractmethod
import json
from bson import json_util
from collections.abc import Iterable
import datetime


class IResponse:
    @abstractmethod
    def get_status(self):
        """response status"""

    def get_data(self, limit=500):
        """returns an str-representation of data"""


class JsonResponse(IResponse):
    def __init__(self, status, json):
        self.status = status
        self.json = json
        self.parse_data(self.json)

    def parse_data(self, data):
        if isinstance(data, dict):
            for k in data.keys():
                if isinstance(data[k], str): continue
                elif isinstance(data[k], Iterable):
                    self.parse_data(data[k])
                elif isinstance(data[k], datetime.date):
                    data[k] = str(data[k])
        elif isinstance(data, list):
            for i in range(len(data)):
                if isinstance(data[i], Iterable):
                    self.parse_data(data[i])
                elif isinstance(data[i], datetime.date):
                    data[i] = str(data[i])

    def get_status(self):
        return self.status

    def get_data(self, limit=500):
        s = json.dumps(self.json, indent=2, ensure_ascii=False, default=json_util.default)
        if len(s) > limit:
            s = s[:limit] + '\n...<%d symbols more>...' % (len(s) - limit)
        return s


class FileResponse(IResponse):
    def __init__(self, status, file):
        self.status = status
        self.file = file

    def get_status(self):
        return self.status

    def get_data(self, limit=500):
        return self.file
