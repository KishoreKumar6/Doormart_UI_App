import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  final String baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<dynamic> get(String path, {String? token}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_requestTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Please check the backend URL.',
        408,
      );
    }
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_requestTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Please check the backend URL.',
        408,
      );
    }
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_requestTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Please check the backend URL.',
        408,
      );
    }
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: jsonEncode(body ?? {}),
          )
          .timeout(_requestTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Please check the backend URL.',
        408,
      );
    }
  }

  Future<dynamic> delete(String path, {String? token}) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_requestTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Please check the backend URL.',
        408,
      );
    }
  }

  Future<dynamic> uploadImage(
    String path, {
    String? filePath,
    Uint8List? bytes,
    String? fileName,
    required String fieldName,
    String? token,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (fields != null) {
      request.fields.addAll(fields);
    }
    if (kIsWeb) {
      if (bytes == null) {
        throw StateError('Image bytes are required on web');
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: fileName ?? 'upload.jpg',
        ),
      );
    } else {
      if (filePath == null || filePath.isEmpty) {
        throw StateError('File path is required');
      }
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  dynamic _decode(http.Response response) {
    final rawBody = response.body;
    if (rawBody.isEmpty) {
      if (response.statusCode >= 400) {
        throw ApiException('Request failed', response.statusCode);
      }
      return null;
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final trimmedBody = rawBody.trimLeft();
    final looksJson =
        contentType.contains('application/json') ||
        trimmedBody.startsWith('{') ||
        trimmedBody.startsWith('[');

    if (!looksJson) {
      final preview = _bodyPreview(rawBody);
      throw ApiException(
        response.statusCode >= 400
            ? 'Server returned non-JSON response (${response.statusCode}). $preview'
            : 'Server returned an unexpected response. $preview',
        response.statusCode,
      );
    }

    dynamic body;
    try {
      body = jsonDecode(rawBody);
    } on FormatException {
      final preview = _bodyPreview(rawBody);
      throw ApiException(
        'Unable to parse server response as JSON. $preview',
        response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      final message = body is Map<String, dynamic>
          ? body['message'] as String? ?? 'Request failed'
          : 'Request failed';
      final code = body is Map<String, dynamic>
          ? body['code'] as String?
          : null;
      throw ApiException(message, response.statusCode, code: code, data: body);
    }
    return body;
  }

  String _bodyPreview(String body) {
    final sanitized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitized.isEmpty) return 'Empty response body.';
    return sanitized.length > 180
        ? '${sanitized.substring(0, 180)}...'
        : sanitized;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode, {this.code, this.data});

  final String message;
  final int statusCode;
  final String? code;
  final dynamic data;

  @override
  String toString() => message;
}
