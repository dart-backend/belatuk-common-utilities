import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'body_parse_result.dart';
import 'file_upload_info.dart';
import 'map_from_uri.dart';

/// Forwards to [parseBodyFromStream].
@Deprecated("parseBodyFromStream")
Future<BodyParseResult> parseBody(
  HttpRequest request, {
  bool storeOriginalBuffer = false,
}) {
  return parseBodyFromStream(
    request,
    request.headers.contentType != null
        ? MediaType.parse(request.headers.contentType.toString())
        : null,
    request.uri,
    storeOriginalBuffer: storeOriginalBuffer,
  );
}

/// Grabs data from an incoming request.
///
/// Supports URL-encoded and JSON, as well as multipart/* forms.
/// In a multipart form, a part with a `filename` or a binary Content-Type is
/// added to the files with its bytes unchanged. Any other part is put in the
/// body under its `name`.
///
/// Use [storeOriginalBuffer] to add  the original request bytes to the result.
Future<BodyParseResult> parseBodyFromStream(
  Stream<Uint8List> data,
  MediaType? contentType,
  Uri requestUri, {
  bool storeOriginalBuffer = false,
}) async {
  var result = _BodyParseResultImpl();

  Future<Uint8List> getBytes() {
    return data
        .fold<BytesBuilder>(BytesBuilder(copy: false), (a, b) => a..add(b))
        .then((b) => b.takeBytes());
  }

  // The body is read before the charset is checked, so originalBuffer is
  // filled even when the charset is rejected.
  Future<String> getBody(String? charset) async {
    var bytes = await getBytes();
    if (storeOriginalBuffer) {
      result.originalBuffer = bytes;
    }
    _checkCharset(charset);
    return utf8.decode(bytes);
  }

  try {
    if (requestUri.hasQuery) {
      buildMapFromUri(result.query, requestUri.query);
    }
  } catch (e, st) {
    // A bad query string fails the request, so the body is not parsed. It is
    // still read, so the stream is drained and originalBuffer is filled.
    result.error = e;
    result.stack = st;
    try {
      var bytes = await getBytes();
      if (storeOriginalBuffer) {
        result.originalBuffer = bytes;
      }
    } catch (_) {
      // The query error is the one reported.
    }
    return result;
  }

  try {
    if (contentType != null) {
      if (contentType.type == 'multipart' &&
          contentType.parameters.containsKey('boundary')) {
        Stream<Uint8List> stream;

        if (storeOriginalBuffer) {
          var bytes = result.originalBuffer = await getBytes();
          var ctrl = StreamController<Uint8List>()..add(bytes);
          await ctrl.close();
          stream = ctrl.stream;
        } else {
          stream = data;
        }

        var parts = MimeMultipartTransformer(
          contentType.parameters['boundary']!,
        ).bind(stream);

        await for (var part in parts) {
          var disposition = part.headers['content-disposition'];
          if (disposition == null) {
            throw const HttpException(
              'Multipart part has no Content-Disposition header',
            );
          }
          var params = HeaderValue.parse(
            disposition,
            preserveBackslash: true,
          ).parameters;

          var transferEncoding = part.headers['content-transfer-encoding'];
          if (transferEncoding != null &&
              !_transparentEncodings.contains(
                HeaderValue.parse(transferEncoding).value.toLowerCase(),
              )) {
            throw HttpException(
              'Unsupported Content-Transfer-Encoding: $transferEncoding',
            );
          }

          var rawType = part.headers['content-type'];
          var partType = rawType == null ? null : ContentType.parse(rawType);
          var isText =
              partType == null ||
              partType.primaryType == 'text' ||
              partType.mimeType == 'application/json';

          var builder = await part.fold(
            BytesBuilder(copy: false),
            (BytesBuilder b, d) => b..add(d),
          );

          if (!isText || params.containsKey('filename')) {
            var upload = FileUploadInfo(
              // RFC 7578: a part without a Content-Type defaults to text/plain.
              mimeType: partType?.mimeType ?? 'text/plain',
              name: params['name'],
              filename: params['filename'] ?? 'file',
              data: builder.takeBytes(),
            );
            result.files.add(upload);
          } else {
            var name = params['name'];
            _checkCharset(partType?.charset);
            var text = utf8.decode(builder.takeBytes());
            // A field without a name has nowhere to go, so it is dropped.
            if (name != null) {
              setValueFromKey(result.body, name, text);
            }
          }
        }
      } else if (contentType.mimeType == 'application/json') {
        var body = await getBody(contentType.parameters['charset']);
        result.body.addAll(_foldToStringDynamic(json.decode(body) as Map?)!);
      } else if (contentType.mimeType == 'application/x-www-form-urlencoded') {
        var body = await getBody(contentType.parameters['charset']);
        buildMapFromUri(result.body, body);
      } else if (storeOriginalBuffer == true) {
        result.originalBuffer = await getBytes();
      }
    } else if (storeOriginalBuffer == true) {
      result.originalBuffer = await getBytes();
    }
  } catch (e, st) {
    result.error = e;
    result.stack = st;
  }

  return result;
}

class _BodyParseResultImpl implements BodyParseResult {
  @override
  Map<String?, dynamic> body = {};

  @override
  List<FileUploadInfo> files = [];

  @override
  List<int>? originalBuffer;

  @override
  Map<String?, dynamic> query = {};

  @override
  dynamic error;

  @override
  StackTrace? stack;
}

/// Throws a [FormatException] if [charset] is given and is not UTF-8 or
/// US-ASCII, which is a subset of UTF-8.
void _checkCharset(String? charset) {
  if (charset == null || charset.toLowerCase() == 'utf8') {
    return;
  }
  var encoding = Encoding.getByName(charset);
  if (encoding != utf8 && encoding != ascii) {
    throw FormatException(
      'Unsupported charset "$charset"; only UTF-8 and US-ASCII are accepted',
    );
  }
}

/// Content-Transfer-Encodings that leave a multipart part's bytes unchanged.
const _transparentEncodings = ['7bit', '8bit', 'binary'];

Map<String, dynamic>? _foldToStringDynamic(Map? map) {
  return map?.keys.fold<Map<String, dynamic>>(
    <String, dynamic>{},
    (out, k) => out..[k.toString()] = map[k],
  );
}
