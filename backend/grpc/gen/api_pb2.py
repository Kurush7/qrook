# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: api.proto
"""Generated protocol buffer code."""
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from google.protobuf import reflection as _reflection
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor.FileDescriptor(
  name='api.proto',
  package='qrook',
  syntax='proto3',
  serialized_options=None,
  create_key=_descriptor._internal_create_key,
  serialized_pb=b'\n\tapi.proto\x12\x05qrook\"2\n\x0f\x41uthCredentials\x12\r\n\x05login\x18\x01 \x01(\t\x12\x10\n\x08password\x18\x02 \x01(\t\"\x1d\n\x0c\x41uthResponse\x12\r\n\x05token\x18\x01 \x01(\t2C\n\tAuthorize\x12\x36\n\x05login\x12\x16.qrook.AuthCredentials\x1a\x13.qrook.AuthResponse\"\x00\x62\x06proto3'
)




_AUTHCREDENTIALS = _descriptor.Descriptor(
  name='AuthCredentials',
  full_name='qrook.AuthCredentials',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='login', full_name='qrook.AuthCredentials.login', index=0,
      number=1, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=b"".decode('utf-8'),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='password', full_name='qrook.AuthCredentials.password', index=1,
      number=2, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=b"".decode('utf-8'),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=20,
  serialized_end=70,
)


_AUTHRESPONSE = _descriptor.Descriptor(
  name='AuthResponse',
  full_name='qrook.AuthResponse',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='token', full_name='qrook.AuthResponse.token', index=0,
      number=1, type=9, cpp_type=9, label=1,
      has_default_value=False, default_value=b"".decode('utf-8'),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=72,
  serialized_end=101,
)

DESCRIPTOR.message_types_by_name['AuthCredentials'] = _AUTHCREDENTIALS
DESCRIPTOR.message_types_by_name['AuthResponse'] = _AUTHRESPONSE
_sym_db.RegisterFileDescriptor(DESCRIPTOR)

AuthCredentials = _reflection.GeneratedProtocolMessageType('AuthCredentials', (_message.Message,), {
  'DESCRIPTOR' : _AUTHCREDENTIALS,
  '__module__' : 'api_pb2'
  # @@protoc_insertion_point(class_scope:qrook.AuthCredentials)
  })
_sym_db.RegisterMessage(AuthCredentials)

AuthResponse = _reflection.GeneratedProtocolMessageType('AuthResponse', (_message.Message,), {
  'DESCRIPTOR' : _AUTHRESPONSE,
  '__module__' : 'api_pb2'
  # @@protoc_insertion_point(class_scope:qrook.AuthResponse)
  })
_sym_db.RegisterMessage(AuthResponse)



_AUTHORIZE = _descriptor.ServiceDescriptor(
  name='Authorize',
  full_name='qrook.Authorize',
  file=DESCRIPTOR,
  index=0,
  serialized_options=None,
  create_key=_descriptor._internal_create_key,
  serialized_start=103,
  serialized_end=170,
  methods=[
  _descriptor.MethodDescriptor(
    name='login',
    full_name='qrook.Authorize.login',
    index=0,
    containing_service=None,
    input_type=_AUTHCREDENTIALS,
    output_type=_AUTHRESPONSE,
    serialized_options=None,
    create_key=_descriptor._internal_create_key,
  ),
])
_sym_db.RegisterServiceDescriptor(_AUTHORIZE)

DESCRIPTOR.services_by_name['Authorize'] = _AUTHORIZE

# @@protoc_insertion_point(module_scope)
