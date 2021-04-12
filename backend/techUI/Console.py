from abc import abstractmethod
import my_argparse as argparse
import colorama
from colorama import Fore, Back, Style
colorama.init()

from Command import ICommand

class IConsole:
    @abstractmethod
    def add_command(self, c: ICommand):
        """add command"""

    @abstractmethod
    def run(self):
        """run console"""

    @abstractmethod
    def add_to_storage(self, key, value):
        """extend global storage"""


class QRConsole(IConsole):
    class ThrowingArgumentParser(argparse.ArgumentParser):
        class ArgumentParserError(Exception): pass
        def error(self, message):
            raise self.ArgumentParserError(message)

    def __init__(self, hello_msg=None):
        self.parser = self.ThrowingArgumentParser(prog='PROG')
        self.subparsers = self.parser.add_subparsers()
        self.hello = hello_msg
        self.storage = dict()
        pass

    def add_to_storage(self, key, value):
        self.storage[key] = value

    def add_command(self, c: ICommand):
        parser = self.subparsers.add_parser(name=c.name, prog=c.name, help=c.help)
        return parser

    def run(self):
        self.__print_hello()
        while True:
            self.__read_line()

    def __print_hello(self):
        if not self.hello:
            self.hello = "Type '-h' or '--help' to get more info\n" \
                         'Enter your commands:'
        print(self.hello)

    def make_adv(self):
        adv = Fore.RESET + '\n---====---\nauthorized: {}\n' + Fore.RESET + '?>'
        status = Fore.GREEN + 'YES' if self.storage.get('token') else Fore.RED + 'NO'
        return adv.format(status)

    def __read_line(self):
        try:
            args = self.parser.parse_args(input(self.make_adv()).split())
            if args.__contains__('func'):
                f = args.func
                del args.__dict__['func']

                response = f(**args.__dict__, storage=self.storage)

                print('response status: ', response.get_status())
                print('response data:\n', response.get_data(), sep='')
        except Exception as e:
            print(Fore.RED + str(e))
            print(Style.RESET_ALL, end='')