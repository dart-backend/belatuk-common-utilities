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

  // Reads the rest of the body after an error, so it does not stall the
  // connection and originalBuffer is filled. An error while reading is
  // ignored, since the earlier error is the one reported.
  Future<void> drainRest() async {
    try {
      if (storeOriginalBuffer) {
        await readAll();
      } else {
        await data.drain<void>();
      }
    } catch (_) {
      // Ignored.
    }
  }

  // The whole body is always read, even when the charset or the bytes are
  // rejected, so it does not stall the connection and originalBuffer is
  // filled. Without originalBuffer, the body is decoded as it arrives so it is
  // not held in memory twice.
  Future<String> getBody(String? charset) async {
    Encoding encoding;
    try {
      encoding = _textEncoding(charset);
    } catch (_) {
      await drainRest();
      rethrow;
    }

    if (storeOriginalBuffer) {
      return encoding.decode(await readAll());
    }

    // Bytes that do not decode, mid-stream or cut off at the end, are
    // reported the same way, after the rest of the body has been read.
    var text = StringBuffer();
    var decoder = encoding.decoder.startChunkedConversion(
      StringConversionSink.fromStringSink(text),
    );
    (Object, StackTrace)? failure;
    await for (var chunk in data) {
      if (failure == null) {
        try {
          decoder.add(chunk);
        } catch (e, st) {
          failure = (e, st);
        }
      }
    }
    if (failure == null) {
      try {
        decoder.close();
      } catch (e, st) {
        failure = (e, st);
      }
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure.$1, failure.$2);
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
    if (storeOriginalBuffer || isMultipart || isJson || isUrlEncoded) {
      await drainRest();
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
              var (:name, :filename, :partType) = _readPartHeaders(
                part.headers,
              );
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

              if (filename == '' && bytes.isEmpty) {
                // A file input left blank: browsers send an empty filename
                // and no content, which is not an upload.
              } else if (!isText || filename != null) {
                var upload = FileUploadInfo(
                  // RFC 7578: a part without a Content-Type defaults to
                  // text/plain.
                  mimeType: partType?.mimeType ?? 'text/plain',
                  name: name,
                  filename: filename == null || filename.isEmpty
                      ? 'file'
                      : filename,
                  data: bytes,
                );
                result.files.add(upload);
              } else {
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
      // JSON keys are data, not field names, so they are not checked for
      // control characters.
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

/// Reads a multipart part's field name, filename and Content-Type.
///
/// Browsers send `"` as `%22` in names and filenames, as the HTML standard
/// says, so that is decoded. Nothing else is, so a literal `%` is kept, and so
/// are the `%0D` and `%0A` browsers send for CR and LF.
///
/// Throws an [HttpException] if the part has no Content-Disposition or a
/// Content-Transfer-Encoding that changes its bytes, and a [FormatException]
/// if its name or filename has a control character or line break. Both are
/// checked before the part is read, so a bad part is never buffered.
({String? name, String? filename, ContentType? partType}) _readPartHeaders(
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

  var name = params['name']?.replaceAll('%22', '"');
  var filename = params['filename']?.replaceAll('%22', '"');
  if (name != null) {
    checkNoControlChars(name);
  }
  if (filename != null && _unsafeFilenameRgx.hasMatch(filename)) {
    // The filename is left out, so logging the error cannot inject text.
    throw const FormatException(
      'A filename contains a line break, control character or bidi override',
    );
  }

  var rawType = headers['content-type'];
  return (
    name: name,
    filename: filename,
    partType: rawType == null ? null : ContentType.parse(rawType),
  );
}

/// Characters a filename must not contain: control characters other than tab,
/// the line breaks U+2028 and U+2029, and the bidi overrides and isolates
/// (U+202A to U+202E and U+2066 to U+2069) that can make a name such as
/// `invoice\u202Etxt.exe` display as `invoiceexe.txt`.
///
/// Tab and the plain direction marks U+200E, U+200F and U+061C are allowed,
/// since real filenames, such as Hebrew or Arabic ones, can contain them.
final _unsafeFilenameRgx = RegExp(
  r'[\x00-\x08\x0A-\x1F\x7F-\x9F\u2028-\u202E\u2066-\u2069]',
);

/// Content-Transfer-Encodings that leave a multipart part's bytes unchanged.
const _transparentEncodings = ['7bit', '8bit', 'binary'];
