import 'dart:math';

import 'package:quiver/core.dart';

/// Represents an individual range, with an optional start index and optional end index.
class RangeHeaderItem implements Comparable<RangeHeaderItem> {
  /// The index at which this chunk begins. May be `-1`.
  final int start;

  /// The index at which this chunk ends. May be `-1`.
  final int end;

  const RangeHeaderItem([this.start = -1, this.end = -1]);

  /// Joins two items together into the largest possible range.
  RangeHeaderItem consolidate(RangeHeaderItem other) {
    if (!(other.overlaps(this))) {
      throw ArgumentError('The two ranges do not overlap.');
    }
    // Two suffix ranges, such as `-500` and `-200`: the longer one covers both.
    if (start == -1) return RangeHeaderItem(-1, max(end, other.end));
    return RangeHeaderItem(
      min(start, other.start),
      end == -1 || other.end == -1 ? -1 : max(end, other.end),
    );
  }

  @override
  int get hashCode => hash2(start, end);

  @override
  bool operator ==(other) =>
      other is RangeHeaderItem && other.start == start && other.end == end;

  /// Returns `true` if this range and [other] share at least one index.
  ///
  /// A suffix range, such as `-500`, depends on the total size, so it is only
  /// considered to overlap another suffix range.
  bool overlaps(RangeHeaderItem other) {
    if (start == -1 || other.start == -1) {
      return start == -1 && other.start == -1;
    }
    return (end == -1 || other.start <= end) &&
        (other.end == -1 || start <= other.end);
  }

  @override
  int compareTo(RangeHeaderItem other) {
    if (other.start > start) {
      return -1;
    } else if (other.start == start) {
      if (other.end == end) {
        return 0;
      } else if (other.end < end) {
        return 1;
      } else {
        return -1;
      }
    } else if (other.start < start) {
      return 1;
    } else {
      return -1;
    }
  }

  @override
  String toString() {
    if (start > -1 && end > -1) {
      return '$start-$end';
    } else if (start > -1) {
      return '$start-';
    } else {
      return '-$end';
    }
  }

  /// Creates a representation of this instance suitable for a `Content-Range` header.
  ///
  /// This can only be used if the user request only one range. If not, send a
  /// `multipart/byteranges` response.
  ///
  /// Please adhere to the standard!!!
  /// http://httpwg.org/specs/rfc7233.html

  ///
  /// A suffix range, such as `-500`, covers the last bytes of [totalSize], and an end
  /// past the last byte is cut back to it. Without a [totalSize], the size is written as `*`.
  String toContentRange([int? totalSize]) {
    if (totalSize == null) {
      if (start == -1 || end == -1) {
        throw UnsupportedError(
          'If the start or end of this range is unknown, `totalSize` must not be null.',
        );
      }
      return '$start-$end/*';
    }

    var first = start == -1 ? max(0, totalSize - end) : start;
    var last = start == -1 || end == -1
        ? totalSize - 1
        : min(end, totalSize - 1);
    return '$first-$last/$totalSize';
  }
}
