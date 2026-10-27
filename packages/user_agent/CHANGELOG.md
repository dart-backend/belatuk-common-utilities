# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** iPhones, iPads and iPods are no longer reported as macOS or as desktops.
* **Breaking:** `isTablet` is `true` for Android tablets and BlackBerry tablets, so they are no longer reported as desktops.
* **Breaking:** `isMobile` also checks the first four characters against `knownMobileUserAgentPrefixes`, and the keywords `mmp`, `palm`, `psp` and `wap` only match at the start of a word.
* **Breaking:** `isBlackberry` no longer matches `rim` inside other words, and matches `RIM Tablet` instead.
* **Breaking:** `isSafari` is `false` for Chrome, Edge, Opera, Firefox on iOS and Android browsers, which also send `Safari`.
* **Breaking:** `isChrome` is `false` for Edge, Opera and Samsung Internet, and `true` for Chrome on iOS.
* **Breaking:** `isOpera` is `true` for Opera 15 and later, and `cssPrefix` and `propertyPrefix` only give the Opera prefix for Opera 12 and earlier.
* **Breaking:** `isIE` is `true` for Internet Explorer 7 and earlier, and `isFirefox` for Firefox on iOS.

### New in 6.0.0

* Added `isIOS` and `isEdge`.

## 5.5.0

* Require Dart >= 3.13

## 5.4.0

* Require Dart >= 3.8

## 5.3.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0

## 5.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 5.1.0

* Updated `lints` to 3.0.0

## 5.0.0

* Require Dart >= 3.0

## 5.0.0-beta.1

* Require Dart >= 3.0

## 4.0.0

* Require Dart >= 2.17

## 3.1.0

* Fixed license link
* Upgraded from `pendantic` to `lints` linter
* Fixed linter warnings
  
## 3.0.2

* Updated repository links

## 3.0.1

* Updated to use non nullable results

## 3.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 2.0.0

* Dart 2 updates.

## 0.0.1

* Initial version, created by Stagehand
