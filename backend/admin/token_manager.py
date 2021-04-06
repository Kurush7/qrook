import datetime
import jwt
from flask import request


class JwtTokenManager:
    def __init__(self):
        self.secret = None
        self.algorithm = None
        self.exp = None

    def load_config(self, config):
        self.secret = config['jwt']['secret'].get()
        self.algorithm = config['jwt']['algorithm'].get()
        self.exp = config['jwt']['exp_seconds'].get()

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


DefaultJwtTokenManager = JwtTokenManager()


def require_token(ignore_expired=False):
    def wrapper(f):
        def decorator(*args, **kwargs):
            auth = request.headers.get('Authorization')
            if auth is None:
                return 'no auth data found', 401
            if not auth.startswith('Bearer '):
                return 'Bearer token expected', 401
            token = auth[len('Bearer '):]
            try:
                payload = DefaultJwtTokenManager.decode_token(token, verify=True)
                return f(*args, **kwargs, user_id=payload['user_id'])
            except jwt.exceptions.ExpiredSignatureError as e:
                if ignore_expired:
                    payload = DefaultJwtTokenManager.decode_token(token, verify=False)
                    return f(payload['user_id'])
                else:
                    return 'token expired', 401
            except Exception as e:
                return e, 401
        decorator.__name__ = f.__name__
        return decorator
    return wrapper

def get_token():
    auth = request.headers.get('Authorization')
    if auth is None:
        return 'no auth data found'
    if not auth.startswith('Bearer '):
        return 'Bearer token expected'
    token = auth[len('Bearer '):]
    try:
        payload = DefaultJwtTokenManager.decode_token(token, verify=True)
        return None
    except jwt.exceptions.ExpiredSignatureError as e:
            return 'token expired'
    except Exception as e:
        return str(e)