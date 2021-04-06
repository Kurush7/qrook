from flask import Flask, jsonify
from flask_cors import CORS
from flask import request
import time
import gevent.pywsgi

from IQRServer import *


class FlaskContextCreator(IQRContextCreator):
    def create_context(self, request, rep: rep.IQRRepository) -> QRContext:
        json = request.get_json()
        if json is None:
            json = dict()
        return QRContext(json, request.args, request.headers, request.form, request.files, rep)


class FlaskServer(IQRServer, FlaskContextCreator, log.QRLogger):
    def __init__(self):
        FlaskContextCreator.__init__(self)
        log.QRLogger.__init__(self)
        self.app = None
        self.debug = None
        self.methods = {}
        self.managers = dict()

    def init_server(self, config: conf.IQRConfig):
        app_name = config['app_name']
        if app_name is None: app_name = 'app'

        debug = config['debug']
        if debug is None: debug = False

        self.app = Flask(app_name)
        CORS(self.app)
        self.debug = debug

    def run(self, host, port):
        self.logger.info('running server on %s:%s' % (host, port))
        self.app_server = gevent.pywsgi.WSGIServer((host, port), self.app)
        self.app_server.serve_forever()
        # self.app.run(debug=self.debug, host=host, port=port)

    def register_method(self, route: str, f, method_type: str):
        """register method"""
        func = lambda *args, **kwargs: self.__method(f, *args, **kwargs)
        func.__name__ = f.__name__
        self.methods[f.__name__] = \
            self.app.route(route, methods=[method_type])(func)

    def __method(self, f, *args, **kwargs):
        ctx = super().create_context(request, self)
        ctx.set_managers(self.managers)
        in_msg = '[' + request.method + '] ' + request.url + '/' + request.query_string.decode()
        try:
            start = time.time()
            result = f(ctx, *args, **kwargs)
            end = time.time()
            msecs = int((end - start) * 1000)
            super().info('[' + str(msecs) + ' msecs]' +  in_msg)
            if result.raw_data:
                return result.result
            if result.status_code == 200:
                return jsonify(result.result)
            else:
                return result.result, result.status_code
        except Exception as e:
            super().info(in_msg)
            super().exception(e)
            return 'Internal server error', 500

    def register_manager(self, manager: IQRManager):
        self.managers[manager.get_name()] = manager
