from abc import abstractmethod
from common.dict_parsing import *

class CommandArgument:
    def __init__(self, name: str, type: type, default=None, required=None, help=None, optional=False):
        if optional:
            self.option_strings = ['-' + name, '--' + name]
        else:
            self.option_strings = None
        self.name = name
        self.type = type
        self.default = default
        self.required = required
        self.help = help

    def get_params(self):
        a = self.option_strings
        if a is None: a = []
        d = {
            'name': self.name,
            'type': self.type,
        }
        if self.default is not None: d['default'] = self.default
        if self.required is not None: d['required'] = self.required
        if self.help is not None: d['help'] = self.help
        if self.option_strings is not None: d['option_strings'] = self.option_strings
        return a, d

class ICommand():
    @abstractmethod
    def __init__(self, name: str, handler, help=None):
        self.name = name
        self.handler = handler
        self.help = help

    @abstractmethod
    def register_argument(self, arg: CommandArgument):
        """register argument"""

    def register_arguments(self, args):
        for arg in args:
            self.register_argument(arg)


    @abstractmethod
    def bind_command(self, console):
        """add command to console"""


class QRCommand(ICommand):
    def __init__(self, name: str, handler, help=None):
        super().__init__(name, handler, help)
        self.parser = None
        self.args = []

    def register_argument(self, arg: CommandArgument):
        self.args.append(arg)

    def _add_arguments(self):
        for arg in self.args:
            args, kwargs = arg.get_params()
            parse_dict(kwargs, rename={'name': 'dest'})
            self.parser.add_argument(*args, **kwargs)

    def bind_command(self, console):
        self.parser = console.add_command(self)
        self.parser.set_defaults(func=self.handler)
        self._add_arguments()