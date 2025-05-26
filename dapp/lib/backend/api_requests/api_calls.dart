import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

const _kPrivateApiFunctionName = 'ffPrivateApiCall';

class CreateOGetWalletCall {
  static Future<ApiCallResponse> call({
    String? firebaseUserUuid = '',
  }) async {
    final ffApiRequestBody = '''
{
  "firebase_user_uuid": "${escapeStringForJson(firebaseUserUuid)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'Create o Get Wallet',
      apiUrl:
          'https://grykapecbngfekafknuh.supabase.co/functions/v1/create-or-fetch-wallet',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? address(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.address''',
      ));
  static String? publicKey(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.public_key''',
      ));
  static String? encryptedPrivateKey(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.private_key''',
      ));
}

class IPFSUploaderCall {
  static Future<ApiCallResponse> call({
    String? tokenStamping,
    String? base64File = '',
  }) async {
    tokenStamping ??= FFDevEnvironmentValues().TokenStamping;

    final ffApiRequestBody = '''
{
  "process": "7343fadd-7499-47f3-986d-b962f4a9d68b",
  "token": "${escapeStringForJson(tokenStamping)}",
  "scope": "dev",
  "params": [
    {
      "name": "file_base64",
      "value": "${escapeStringForJson(base64File)}"
    },
    {
      "name": "heris_qty",
      "value": "0"
    },
    {
      "name": "consensus_min",
      "value": "0"
    }
  ]
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'IPFS uploader',
      apiUrl: 'https://api.stamping.io/exec/',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? ipfsCID(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.response.ipfs_res.cid''',
      ));
  static String? fileSecret(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.response.secret''',
      ));
  static String? hashCommit(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.response.hash_commit''',
      ));
}

class AESDecryptCall {
  static Future<ApiCallResponse> call({
    String? tokenStamping,
    String? cData = '',
    String? secret = '',
  }) async {
    tokenStamping ??= FFDevEnvironmentValues().TokenStamping;

    final ffApiRequestBody = '''
{
  "process": "42d8293e-be5d-4f63-8538-37562c9e72d8",
  "token": "${escapeStringForJson(tokenStamping)}",
  "scope": "dev",
  "params": [
    {
      "name": "cData",
      "value": "${escapeStringForJson(cData)}"
    },
    {
      "name": "secret",
      "value": "${escapeStringForJson(secret)}"
    }
  ]
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'AES  Decrypt',
      apiUrl: 'https://api.stamping.io/exec/',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  static String? decryptedData(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.response.decrypted_data''',
      ));
  
  static String? base64Data(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.response.base64_data''',
      ));
}

class GetIPFSCall {
  static Future<ApiCallResponse> call({
    String? cid = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'Get IPFS',
      apiUrl: 'https://ipfs.io/ipfs/${cid}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String _toEncodable(dynamic item) {
  if (item is DocumentReference) {
    return item.path;
  }
  return item;
}

String _serializeList(List? list) {
  list ??= <String>[];
  try {
    return json.encode(list, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("List serialization failed. Returning empty list.");
    }
    return '[]';
  }
}

String _serializeJson(dynamic jsonVar, [bool isList = false]) {
  jsonVar ??= (isList ? [] : {});
  try {
    return json.encode(jsonVar, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("Json serialization failed. Returning empty json.");
    }
    return isList ? '[]' : '{}';
  }
}

String? escapeStringForJson(String? input) {
  if (input == null) {
    return null;
  }
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}
