# User Agent Analyzer

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/user_agent_analyzer?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/user_agent/LICENSE)

A library to identify the type of device and web browser from a `User-Agent` string. It has no dependencies and runs anywhere Dart does: on a server, in a browser or in a Flutter app.

## Installation

```yaml
dependencies:
  user_agent_analyzer: ^6.0.0
```

## Usage

Create a `UserAgent` from the header value, then check its getters.

```dart
import 'dart:io';

import 'package:user_agent_analyzer/user_agent_analyzer.dart';

void main() async {
  var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);

  await for (var request in server) {
    var ua = UserAgent(
      request.headers.value(HttpHeaders.userAgentHeader) ?? '',
    );

    if (ua.isIE) {
      request.response.redirect(Uri.parse('/upgrade-your-browser'));
    } else if (ua.isMobile) {
      request.response.write('Mobile site');
    } else {
      request.response.write('Desktop site');
    }

    await request.response.close();
  }
}
```

## Devices and operating systems

| Getter | `true` for |
| --- | --- |
| `isMobile` | Phones and other handheld devices, including iPads, which send `Mobile` |
| `isTablet` | iPads, Android tablets, BlackBerry PlayBooks, HP tablets and Kindles |
| `isDesktop` | Anything that is neither mobile nor a tablet |
| `isIOS` | iPhones, iPads and iPods |
| `isMacOS` | Macs, but not iOS devices |
| `isAndroid`, `isAndroidPhone`, `isAndroidTablet` | Android devices. An Android user agent without `Mobile` is a tablet |
| `isWindows`, `isWindowsPhone`, `isWindowsTablet` | Windows devices |
| `isBlackberry`, `isBlackberryPhone`, `isBlackberryTablet` | BlackBerry devices |

`isMobile` checks for the keywords in `knownMobileUserAgentKeywords`, and checks the first four characters against `knownMobileUserAgentPrefixes`. `isTablet` also checks `knownTabletUserAgentKeywords`.

## Browsers

| Getter | `true` for |
| --- | --- |
| `isChrome` | Chrome, including Chrome on iOS. Not Edge, Opera or Samsung Internet, which are also built on Chromium |
| `isEdge` | Microsoft Edge, on any platform |
| `isFirefox` | Firefox, including Firefox on iOS |
| `isSafari` | Safari only. Not the other browsers that also send `Safari` in their user agent |
| `isOpera` | Opera, including Opera 15 and later |
| `isIE` | Internet Explorer, including version 7 and earlier |
| `isWebKit` | Browsers built on WebKit, or on Blink, which is built on it |

## CSS and JavaScript prefixes

`cssPrefix` gives the vendor prefix for CSS properties, such as `-webkit-`, and `propertyPrefix` gives the one for JavaScript properties, such as `webkit`:

| Browser | `cssPrefix` | `propertyPrefix` |
| --- | --- | --- |
| Firefox | `-moz-` | `moz` |
| Internet Explorer | `-ms-` | `ms` |
| Opera 12 and earlier | `-o-` | `o` |
| Everything else | `-webkit-` | `webkit` |

## Limitations

User agents can be changed or faked, so use these checks to adjust what you show, never for security decisions.

An iPad set to request desktop websites, which is the default since iPadOS 13, sends the same user agent as a Mac. It is reported as `isMacOS` and `isDesktop`, and `isIOS` is `false`.

## Upgrading from 5.x

Version 6.0.0 corrects several checks, so some getters return different results. For example, iPhones are no longer reported as desktops, and `isSafari` is no longer `true` for Chrome. See the [changelog](CHANGELOG.md) for the full list.
