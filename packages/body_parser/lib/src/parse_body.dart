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

  // Reads the whole body, storing it in originalBuffer when asked to.
  Future<Uint8List> readAll() async {
    var builder = await data.fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (a, b) => a..add(b),
    );
    var bytes = builder.takeBytes();
    if (storeOriginalBuffer) {
      result.originalBuffer = bytes;
    }
    return bytes;
  }

  // The body is read before the charset is checked, so originalBuffer is
  // filled even when the charset is rejected.
  Future<String> getBody(String? charset) async {
    var bytes = await readAll();
    return _textEncoding(charset).decode(bytes);
  }

  var isMultipart =
      contentType?.type == 'multipart' &&
      contentType!.parameters.containsKey('boundary');
  var isJson = contentType?.mimeType == 'application/json';
  var isUrlEncoded =
      contentType?.mimeType == 'application/x-www-form-urlencoded';

  try {
    if (requestUri.hasQuery) {
      buildMapFromUri(result.query, requestUri.query);
    }
  } catch (e, st) {
    // A bad query string fails the request, so the body is not parsed. A body
    // that would have been parsed is still read, so it does not stall the
    // connection; any other body is left for the caller, as on success.
    result.error = e;
    result.stack = st;
    try {
      if (storeOriginalBuffer) {
        await readAll();
      } else if (isMultipart || isJson || isUrlEncoded) {
        await data.drain<void>();
      }
    } catch (_) {
      // The query error is the one reported.
    }
    return result;
  }

  try {
    if (isMultipart) {
      var stream = storeOriginalBuffer ? Stream.value(await readAll()) : data;

      var parts = MimeMultipartTransformer(contentType.parameters['boundary']!)
          .bind(stream);

      // After a bad part, the rest are still read, so the whole body is
      // consumed before the error is reported. A part is only buffered once
      // its headers are known to be good.
      Object? partError;
      StackTrace? partStack;
      // Once the parse has failed, a part still being read must not add to
      // the result that was cleared and returned.
      var stopped = false;
      try {
        await _forEachPart(parts, (part) async {
          var read = false;
          if (partError == null) {
            try {
              var (params, partType) = _readPartHeaders(part.headers);
              var isText =
                  partType == null ||
                  partType.primaryType == 'text' ||
                  partType.mimeType == 'application/json';

              read = true;
              var builder = await part.fold(
                BytesBuilder(copy: false),
                (BytesBuilder b, d) => b..add(d),
              );
              var bytes = builder.takeBytes();
              if (stopped) {
                return;
              }

              if (!isText || params.containsKey('filename')) {
                var upload = FileUploadInfo(
                  // RFC 7578: a part without a Content-Type defaults to
                  // text/plain.
                  mimeType: partType?.mimeType ?? 'text/plain',
                  name: params['name'],
                  filename: params['filename'] ?? 'file',
                  data: bytes,
                );
                result.files.add(upload);
              } else {
                var name = params['name'];
                var text = _textEncoding(partType?.charset).decode(bytes);
                // A field without a name has nowhere to go, so it is dropped.
                if (name != null) {
                  setValueFromKey(result.body, name, text);
                }
              }
            } catch (e, st) {
              partError = e;
              partStack = st;
            }
          }
          if (!read) {
            await part.drain<void>();
          }
        });
      } catch (_) {
        stopped = true;
        rethrow;
      }
      var error = partError;
      if (error != null) {
        Error.throwWithStackTrace(error, partStack!);
      }
    } else if (isJson) {
      var body = await getBody(contentType!.parameters['charset']);
      var decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('A JSON body must be an object');
      }
      result.body.addAll(decoded);
    } else if (isUrlEncoded) {
      var body = await getBody(contentType!.parameters['charset']);
      buildMapFromUri(result.body, body);
    } else if (storeOriginalBuffer) {
      await readAll();
    }
  } catch (e, st) {
    // A failed parse keeps no partial body or files.
    result.body.clear();
    result.files.clear();
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

/// The encoding to decode text with: US-ASCII when [charset] says so, and
/// UTF-8 otherwise. Both decoders reject bytes that are not valid for them.
///
/// Throws a [FormatException] if [charset] is neither UTF-8 nor US-ASCII.
Encoding _textEncoding(String? charset) {
  if (charset == null || charset.toLowerCase() == 'utf8') {
    return utf8;
  }
  var encoding = Encoding.getByName(charset);
  if (encoding != utf8 && encoding != ascii) {
    throw FormatException(
      'Unsupported charset "$charset"; only UTF-8 and US-ASCII are accepted',
    );
  }
  return encoding!;
}

/// Calls [handle] on each part in turn, like `await for`, but without pausing
/// [parts] while a part is handled.
///
/// A multipart body cut off part-way reports its error on [parts] but never
/// closes the open part, so `await for` would wait on that part forever. Here
/// the error completes the returned future instead.
///
/// The first error, from [parts] or from [handle], completes the returned
/// future, and no later part is handled or read.
Future<void> _forEachPart(
  Stream<MimeMultipart> parts,
  Future<void> Function(MimeMultipart part) handle,
) {
  var done = Completer<void>();
  var handled = Future<void>.value();
  late StreamSubscription<MimeMultipart> subscription;
  void fail(Object e, StackTrace st) {
    if (!done.isCompleted) {
      done.completeError(e, st);
      subscription.cancel();
    }
  }

  subscription = parts.listen(
    (part) {
      handled = handled
          .then((_) {
            if (!done.isCompleted) {
              return handle(part);
            }
          })
          .catchError(fail);
    },
    onError: fail,
    onDone: () => handled.then((_) {
      if (!done.isCompleted) {
        done.complete();
      }
    }),
    cancelOnError: true,
  );
  return done.future;
}

/// Reads a multipart part's Content-Disposition parameters and Content-Type.
///
/// Throws an [HttpException] if the part has no Content-Disposition, or a
/// Content-Transfer-Encoding that changes its bytes.
(Map<String, String?>, ContentType?) _readPartHeaders(
  Map<String, String> headers,
) {
  var disposition = headers['content-disposition'];
  if (disposition == null) {
    throw const HttpException(
      'Multipart part has no Content-Disposition header',
    );
  }
  var params = HeaderValue.parse(
    disposition,
    preserveBackslash: true,
  ).parameters;

  var transferEncoding = headers['content-transfer-encoding'];
  if (transferEncoding != null &&
      !_transparentEncodings.contains(
        HeaderValue.parse(transferEncoding).value.toLowerCase(),
      )) {
    throw HttpException(
      'Unsupported Content-Transfer-Encoding: $transferEncoding',
    );
  }

  var rawType = headers['content-type'];
  return (params, rawType == null ? null : ContentType.parse(rawType));
}

/// Content-Transfer-Encodings that leave a multipart part's bytes unchanged.
const _transparentEncodings = ['7bit', '8bit', 'binary'];
