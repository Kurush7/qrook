import sys

sys.path.append('../scout_service')

from Command import *
import scout_service as src
from Response import *
from common_commands import *


class ScoutRegisterEventCommand(QRCommand):
    def __init__(self):
        super().__init__('event', self.event, 'event')

    @staticmethod
    def event(storage, event, data=None):
        rep = storage.get('scout_repository')
        if rep is None:
            raise Exception('no scout repository found')
        managers = storage.get('managers')

        token = storage.get('token')
        if token is None:
            raise Exception('token required by the operation')

        if data is None: data = {}
        else: data = json.loads(data)

        ctx = create_context(headers={'Authorization': 'Bearer ' + token},
                             repository=rep, managers=managers,
                             json_data={'event': event, 'data': data,
                                        'time': int(datetime.datetime.now().timestamp())})

        data = src.register_event(ctx)

        storage.pop('token')

        response = JsonResponse(data.status_code, data.result)
        return response

    def bind_command(self, console):
        super().bind_command(console)
        self.register_argument(CommandArgument('event', str, help='event type'))
        self.register_argument(CommandArgument('data', str, help='data (json format)', optional=True))

        self._add_arguments()

def create_scout_methods(console):
    ScoutRegisterEventCommand().bind_command(console)