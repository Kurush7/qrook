import datetime
import jwt
from IQRServer import *
from abc import abstractmethod


class ITokenManager(IQRManager):
    @staticmethod
    def get_name() -> str:
        return "token_manager"

    @abstractmethod
    def load_config(self, config: conf.IQRConfig):
        """define tokenizing parameters"""

    @abstractmethod
    def make_token(self, user_id: int, payload: dict = None):
        """generate token with given payload (user_id is its part, required).
        adds 'exp' key - expired time defined by config"""

    @abstractmethod
    def decode_token(self, token, verify=True):
        """get token payload"""

    @abstractmethod
    def expired_exception(self):
        """exception to catch on token-expired occasion"""


class JwtTokenManager(ITokenManager):
    def __init__(self):
        self.secret = None
        self.algorithm = None
        self.exp = None

    @abstractmethod
    def expired_exception(self):
        return jwt.exceptions.ExpiredSignatureError

    def load_config(self, config: conf.IQRConfig):
        self.secret = config['secret']
        self.algorithm = config['algorithm']
        self.exp = config['exp_seconds']

    def make_token(self, user_id: int, payload: dict = None):
        if payload is None: payload = dict()
        payload = payload.copy()
        payload['user_id'] = user_id
        payload['exp'] = datetime.datetime.utcnow() + datetime.timedelta(seconds=self.exp)

        jwt_token = jwt.encode(payload, self.secret, self.algorithm)
        return jwt_token

    def decode_token(self, token, verify=True):
        payload = jwt.decode(token, self.secret, verify=verify, algorithms=[self.algorithm])
        return payload


def require_token(ignore_expired=False, send_token=False):
    def wrapper(f):
        def decorator(ctx: QRContext, *args, **kwargs):
            auth = ctx.headers.get('Authorization')
            if auth is None:
                return MethodResult('no auth data found', 401)
            if not auth.startswith('Bearer '):
                return MethodResult('Bearer token expected', 401)
            token = auth[len('Bearer '):]
            if send_token:
                kwargs['token'] = token
            try:
                payload = ctx.managers[ITokenManager.get_name()].decode_token(token, verify=True)
                return f(ctx, *args, **kwargs, user_id=payload['user_id'])
            except ctx.managers[ITokenManager.get_name()].expired_exception() as e:
                if ignore_expired:
                    payload = ctx.managers[ITokenManager.get_name()].decode_token(token, verify=False)
                    try:
                        return f(ctx, *args, **kwargs, user_id=payload['user_id'])
                    except Exception as e:
                        return MethodResult(str(e), 500)
                else:
                    return MethodResult('token expired', 401)
            except Exception as e:
                return MethodResult(str(e), 500)
        decorator.__name__ = f.__name__
        return decorator
    return wrapper


class MockTokenManager(ITokenManager):
    def load_config(self, config: conf.IQRConfig):
        pass

    def make_token(self, user_id: int, payload: dict = None):
        return 'Bearer ' + str(user_id)

    @abstractmethod
    def decode_token(self, token, verify=True):
        if token is None or token == '':
            raise Exception('token expired')
        return {'user_id': int(token)}