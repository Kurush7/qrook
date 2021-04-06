import datetime
import jwt
from IQRServer import *


class JwtTokenManager(IQRManager):
    @staticmethod
    def get_name() -> str:
        return "token_manager"

    def __init__(self):
        self.secret = None
        self.algorithm = None
        self.exp = None

    def load_config(self, config):
        self.secret = config['secret']
        self.algorithm = config['algorithm']
        self.exp = config['exp_seconds']

    def make_jwt_token(self, user_id):
        payload = {
            'user_id': user_id,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(seconds=self.exp)
        }
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
                payload = ctx.managers[JwtTokenManager.get_name()].decode_token(token, verify=True)
                return f(ctx, *args, **kwargs, user_id=payload['user_id'])
            except jwt.exceptions.ExpiredSignatureError as e:
                if ignore_expired:
                    payload = ctx.managers[JwtTokenManager.get_name()].decode_token(token, verify=False)
                    return f(ctx, *args, **kwargs, user_id=payload['user_id'])
                else:
                    return MethodResult('token expired', 401)
            except Exception as e:
                return MethodResult(str(e), 401)
        decorator.__name__ = f.__name__
        return decorator
    return wrapper