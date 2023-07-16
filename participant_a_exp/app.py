from flask import Flask, jsonify, request
import grpc
import registration_pb2
import registration_pb2_grpc

app = Flask(__name__)

channel = grpc.insecure_channel('server-service:50051')
stub = registration_pb2_grpc.RegistrationServiceStub(channel)

@app.route('/register', methods=['POST'])
def register_user():
    data = request.get_json()
    username = data["username"]
    password = data["password"]

    request = registration_pb2.RegistrationRequest(username=username, password=password)
    response = stub.RegisterUser(request)

    return jsonify({"message": response.message})

@app.route('/login', methods=['POST'])
def login_user():
    data = request.get_json()
    username = data["username"]
    password = data["password"]

    request = registration_pb2.LoginRequest(username=username, password=password)
    response = stub.LoginUser(request)

    return jsonify({"message": response.message})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)