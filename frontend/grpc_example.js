var PROTO_PATH = __dirname + '/protos/auth.proto';

var grpc = require('@grpc/grpc-js');
var protoLoader = require('@grpc/proto-loader');
var packageDefinition = protoLoader.loadSync(
    PROTO_PATH,
    {keepCase: true,
     longs: String,
     enums: String,
     defaults: true,
     oneofs: true
    });

var qrook_proto = grpc.loadPackageDefinition(packageDefinition).qrook;

function main() {
  var client = new qrook_proto.Authorize('localhost:5000',
                                       grpc.credentials.createInsecure());
  client.login({login: "kurush", password: "password"}, function(err, response) {
    console.log('Response:', response.token);
  });
}

main();
