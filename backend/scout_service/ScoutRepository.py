import IQRRepository as rep
from qrookDB.data import QRTable
from datetime import datetime
import json
from abc import abstractmethod
users = QRTable()

class IScoutRepository():
    @abstractmethod
    def register_event(self, user_id, time, event: str, data: dict):
        """register event"""

class ScoutRepository(IScoutRepository, rep.QRRepository):
    def __init__(self):
        super().__init__()

    def register_event(self, user_id, time, event: str, data: dict):
        if self.db is None:
            raise Exception('DBAdapter not connected to database')

        data = data.copy()
        data['user_id'] = user_id
        str_data = json.dumps(data)
        time = datetime.fromtimestamp(time)

        i = self.db.intelligence
        ok = self.db.insert(i, i.time, i.event, i.data, auto_commit=True) \
            .values([time, event, str_data]).exec()
        return ok