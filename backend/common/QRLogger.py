import logging
from abc import abstractmethod, abstractproperty
import QRConfig as conf

# todo manage logging to different places

class IQRLogger:
    @abstractmethod
    def configure_logger(self, config: conf.IQRConfig):
        """configure logger"""

    @abstractmethod
    def info(self, msg, *args):
        """log info"""

    @abstractmethod
    def warning(self, msg, *args):
        """log warning"""

    @abstractmethod
    def error(self, msg, *args):
        """log error"""

    @abstractmethod
    def exception(self, msg, *args):
        """log exception"""


class QRLogger(IQRLogger):
    def __init__(self):
        self.logger = logging.getLogger()

    # todo log error here
    def configure_logger(self, config: conf.IQRConfig):
        logger = logging.getLogger(config['logger_name'])
        logger.addHandler(get_stream_handler(config['level'].upper()))
        if config['file']:
            if config['file_level'] is None: file_level = config['level']
            else: file_level = config['file_level']
            logger.addHandler(get_file_handler(config['file'], file_level.upper()))

        logger = logging.LoggerAdapter(logger, {'app': config['app_name']})
        logger.setLevel('INFO')
        self.logger = logger

    def info(self, msg, *args):
        self.logger.info(msg, *args)

    @abstractmethod
    def warning(self, msg, *args):
        self.logger.warning(msg, *args)

    @abstractmethod
    def error(self, msg, *args):
        self.logger.error(msg, *args, exc_info=False)

    @abstractmethod
    def exception(self, msg, *args):
        self.logger.exception(msg, *args)


#(%(filename)s).%(funcName)s(%(lineno)d)
_log_format = "%(asctime)s [%(levelname)s]: [%(app)s, %(name)s] - %(message)s"

class CustomFormatter(logging.Formatter):
    """Logging Formatter to add colors and count warning / errors"""
    grey = "\033[30m"
    yellow = "\033[33m"
    red = "\033[31m"
    bold_red = "\x1b[31;1m"
    reset = "\x1b[0m"

    FORMATS = {
        logging.DEBUG: grey + _log_format + reset,
        logging.INFO: grey + _log_format + reset,
        logging.WARNING: yellow + _log_format + reset,
        logging.ERROR: red + _log_format + reset,
        logging.CRITICAL: bold_red + _log_format + reset
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno)
        formatter = logging.Formatter(log_fmt)
        return formatter.format(record)


def get_file_handler(filename, level):
    file_handler = logging.FileHandler(filename)
    file_handler.setLevel(level)
    file_handler.setFormatter(logging.Formatter(_log_format))
    return file_handler


def get_stream_handler(level):
    sh = logging.StreamHandler()
    sh.setLevel(level)
    sh.setFormatter(logging.Formatter(_log_format))
    sh.setFormatter(CustomFormatter())
    return sh
