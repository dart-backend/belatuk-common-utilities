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

  // The whole body is always read, even when the charset or the bytes are
  // rejected, so it does not stall the connection and originalBuffer is
  // filled. Without originalBuffer, the body is decoded as it arrives so it is
  // not held in memory twice.
  Future<String> getBody(String? charset) async {
    if (storeOriginalBuffer) {
      var bytes = await readAll();
      return _textEncoding(charset).decode(bytes);
    }

    Object? error;
    StackTrace? stack;
    void guard(void Function() step) {
      if (error == null) {
        try {
          step();
        } catch (e, st) {
          error = e;
          stack = st;
        }
      }
    }

    var text = StringBuffer();
    late Sink<List<int>> decoder;
    guard(() {
      decoder = _textEncoding(charset).decoder
          .startChunkedConversion(StringConversionSink.fromStringSink(text));
    });
    await for (var chunk in data) {
      guard(() => decoder.add(chunk));
    }
    guard(() => decoder.close());

    var e = error;
    if (e != null) {
      Error.throwWithStackTrace(e, stack!);
    }
    return text.toString();
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
    result.query.clear();
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

      // After a bad part, the rest are still read, so the whole body is
      // consumed before the error is reported. A part is only buffered once
      // its headers are known to be good.
      Object? partError;
      StackTrace? partStack;
      // Once the parse has failed, a part still being read must not add to
      // the result that was cleared and returned.
      var stopped = false;
      try {
        await _forEachPart(stream, contentType.parameters['boundary']!, (
          part,
        ) async {
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
                  name: _decodeFieldName(params['name']),
                  filename: _decodeFieldName(params['filename']) ?? 'file',
                  data: bytes,
                );
                result.files.add(upload);
              } else {
                var name = _decodeFieldName(params['name']);
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

/// Splits [input] into multipart parts and calls [handle] on each in turn,
/// like `await for`, but without pausing the parts while a part is handled.
///
/// The first error completes the returned future, after which no later part
/// is handled and [input] is cancelled, so it is neither read further nor
/// left paused. Errors are caught that `await for` would miss:
///
/// * A body cut off part-way reports its error on the parts but never closes
///   the open part, so `await for` would wait on that part forever.
/// * Some errors, such as a bad header name, are thrown inside package:mime's
///   own input listener instead of on the parts, so they are caught by
///   running in a guarded zone.
Future<void> _forEachPart(
  Stream<Uint8List> input,
  String boundary,
  Future<void> Function(MimeMultipart part) handle,
) {
  var done = Completer<void>();
  var handled = Future<void>.value();
  StreamSubscription<Uint8List>? inputSubscription;
  StreamSubscription<MimeMultipart>? partSubscription;

  // package:mime does not cancel its input while a part is open, so the
  // input is passed through a controller this function can cancel itself.
  late StreamController<Uint8List> controller;
  controller = StreamController<Uint8List>(
    onListen: () {
      inputSubscription = input.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    },
    onPause: () => inputSubscription?.pause(),
    onResume: () => inputSubscription?.resume(),
    onCancel: () => inputSubscription?.cancel(),
  );

  void fail(Object e, StackTrace st) {
    if (!done.isCompleted) {
      done.completeError(e, st);
      partSubscription?.cancel();
      inputSubscription?.cancel();
    }
  }

  runZonedGuarded(() {
    partSubscription = MimeMultipartTransformer(boundary)
        .bind(controller.stream)
        .listen(
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
  }, fail);
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

final _fieldNameEscapeRgx = RegExp('%(22|0[DdAa])');

/// Decodes the escapes browsers use in multipart field names and filenames:
/// `%22` for `"`, `%0D` for CR and `%0A` for LF, as the HTML standard says.
/// Nothing else is decoded, so a literal `%` is kept.
String? _decodeFieldName(String? name) => name?.replaceAllMapped(
  _fieldNameEscapeRgx,
  (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
);

/// Content-Transfer-Encodings that leave a multipart part's bytes unchanged.
const _transparentEncodings = ['7bit', '8bit', 'binary'];
