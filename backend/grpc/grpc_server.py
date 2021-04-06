import time
from concurrent import futures

import grpc
import gen.api_pb2 as api_pb2
import gen.api_pb2_grpc as api_pb2_grpc


class ApiServicer(api_pb2_grpc.Authorize):
    def login(self, request, context):
        print(request.login, request.password, 'wants to auth')

        response = api_pb2.AuthResponse()
        response.token = 'super-secret-jwt-token from login=%s, password=%s' \
                         % (request.login, request.password)
        return response


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    api_pb2_grpc.add_AuthorizeServicer_to_server(ApiServicer(), server)

    print('Running on port 5000...')
    server.add_insecure_port('[::]:5000')
    server.start()

    while 31:
        time.sleep(1)


if __name__ == '__main__':
    serve()