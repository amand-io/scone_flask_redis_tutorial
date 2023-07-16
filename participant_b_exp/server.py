import grpc
from concurrent import futures
import redis
import registration_pb2
import registration_pb2_grpc

class RegistrationService(registration_pb2_grpc.RegistrationServiceServicer):
    def __init__(self):
        self.redis_client = redis.Redis(host='redis-service', port=6379)

    def RegisterUser(self, request, context):
        username = request.username

        if self.redis_client.exists(username):
            return registration_pb2.RegistrationResponse(message="Username already exists.")

        self.redis_client.set(username, request.password)
        return registration_pb2.RegistrationResponse(message="User registered successfully.")

    def LoginUser(self, request, context):
        username = request.username
        password = request.password

        if self.redis_client.exists(username):
            stored_password = self.redis_client.get(username).decode('utf-8')
            if stored_password == password:
                return registration_pb2.LoginResponse(message="Login successful.")
            else:
                return registration_pb2.LoginResponse(message="Invalid password.")
        else:
            return registration_pb2.LoginResponse(message="User not found.")

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    registration_pb2_grpc.add_RegistrationServiceServicer_to_server(RegistrationService(), server)
    server.add_insecure_port('[::]:50051')
    server.start()
    server.wait_for_termination()

if __name__ == '__main__':
    serve()