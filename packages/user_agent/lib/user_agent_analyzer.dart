library;

/// Utils for device detection.
class UserAgent {
  String? _cachedCssPrefix;
  String? _cachedPropertyPrefix;

  final String value, _lowerValue;

  static const List<String> knownMobileUserAgentPrefixes = [
    'w3c ',
    'w3c-',
    'acs-',
    'alav',
    'alca',
    'amoi',
    'audi',
    'avan',
    'benq',
    'bird',
    'blac',
    'blaz',
    'brew',
    'cell',
    'cldc',
    'cmd-',
    'dang',
    'doco',
    'eric',
    'hipt',
    'htc_',
    'inno',
    'ipaq',
    'ipod',
    'jigs',
    'kddi',
    'keji',
    'leno',
    'lg-c',
    'lg-d',
    'lg-g',
    'lge-',
    'lg/u',
    'maui',
    'maxo',
    'midp',
    'mits',
    'mmef',
    'mobi',
    'mot-',
    'moto',
    'mwbp',
    'nec-',
    'newt',
    'noki',
    'palm',
    'pana',
    'pant',
    'phil',
    'play',
    'port',
    'prox',
    'qwap',
    'sage',
    'sams',
    'sany',
    'sch-',
    'sec-',
    'send',
    'seri',
    'sgh-',
    'shar',
    'sie-',
    'siem',
    'smal',
    'smar',
    'sony',
    'sph-',
    'symb',
    't-mo',
    'teli',
    'tim-',
    'tosh',
    'tsm-',
    'upg1',
    'upsi',
    'vk-v',
    'voda',
    'wap-',
    'wapa',
    'wapi',
    'wapp',
    'wapr',
    'webc',
    'winw',
    'xda ',
    'xda-',
  ];

  static const List<String> knownMobileUserAgentKeywords = [
    'blackberry',
    'webos',
    'ipod',
    'lge vx',
    'midp',
    'maemo',
    'mmp',
    'mobile',
    'netfront',
    'hiptop',
    'nintendo DS',
    'novarra',
    'openweb',
    'opera mobi',
    'opera mini',
    'palm',
    'psp',
    'phone',
    'smartphone',
    'symbian',
    'up.browser',
    'up.link',
    'wap',
    'windows ce',
  ];

  /// Keywords from [knownMobileUserAgentKeywords] short enough to appear inside other words,
  /// so they only match at the start of a word, as in `WAP2.0` but not `SwapBrowser`.
  static const Set<String> _wordStartKeywords = {'mmp', 'palm', 'psp', 'wap'};

  static const List<String> knownTabletUserAgentKeywords = [
    'ipad',
    'playbook',
    'hp-tablet',
    'kindle',
  ];

  UserAgent(this.value) : _lowerValue = value.toLowerCase();

  /// Determines if the user agent string contains the desired string. Case-insensitive.
  bool contains(String needle) => _lowerValue.contains(needle.toLowerCase());

  /// Determines if the user agent string contains [word] at the start of a word. Case-insensitive.
  bool _containsWordStart(String word) =>
      RegExp('(^|[^a-z])${RegExp.escape(word.toLowerCase())}')
          .hasMatch(_lowerValue);

  bool get isDesktop => !isMobile && !isTablet;

  bool get isTablet =>
      knownTabletUserAgentKeywords.any(contains) ||
      isAndroidTablet ||
      isBlackberryTablet;

  bool get isMobile =>
      knownMobileUserAgentKeywords.any(
        (k) => _wordStartKeywords.contains(k)
            ? _containsWordStart(k)
            : contains(k),
      ) ||
      (_lowerValue.length >= 4 &&
          knownMobileUserAgentPrefixes.contains(_lowerValue.substring(0, 4)));

  /// Determines if the current device is an iPhone, iPad or iPod.
  ///
  /// iPads that request desktop sites send a macOS user agent, and cannot be told apart from a Mac.
  bool get isIOS => contains('iphone') || contains('ipad') || contains('ipod');

  bool get isMacOS => (contains('Macintosh') || contains('Mac OS X')) && !isIOS;

  /// Determines if the current device is running Safari, and not another browser built on WebKit.
  bool get isSafari =>
      value.contains('Safari') &&
      !value.contains('Chrome') &&
      !value.contains('Chromium') &&
      !value.contains('CriOS') &&
      !value.contains('FxiOS') &&
      !value.contains('EdgiOS') &&
      !value.contains('OPiOS') &&
      !isAndroid;

  bool get isAndroid => contains('android');

  bool get isAndroidPhone => contains('android') && contains('mobile');

  bool get isAndroidTablet => contains('android') && !contains('mobile');

  bool get isWindows => contains('windows');

  bool get isWindowsPhone => isWindows && contains('phone');

  bool get isWindowsTablet => isWindows && contains('touch');

  bool get isBlackberry =>
      contains('blackberry') || contains('bb10') || contains('rim tablet');

  bool get isBlackberryPhone => isBlackberry && !contains('tablet');

  bool get isBlackberryTablet => isBlackberry && contains('tablet');

  /// Determines if the current device is running Chrome, including Chrome on iOS.
  ///
  /// Other browsers built on Chromium, such as Edge, Opera and Samsung Internet, are not Chrome.
  bool get isChrome =>
      (value.contains('Chrome') || value.contains('CriOS')) &&
      !isEdge &&
      !isOpera &&
      !value.contains('SamsungBrowser');

  /// Determines if the current device is running Microsoft Edge.
  bool get isEdge =>
      value.contains('Edg/') ||
      value.contains('Edge/') ||
      value.contains('EdgA/') ||
      value.contains('EdgiOS/');

  /// Determines if the current device is running Opera.
  bool get isOpera =>
      value.contains('Opera') ||
      value.contains('OPR/') ||
      value.contains('OPiOS/');

  /// Determines if the current device is running Internet Explorer.
  bool get isIE =>
      !isOpera && (value.contains('Trident/') || value.contains('MSIE '));

  /// Determines if the current device is running Firefox, including Firefox on iOS.
  bool get isFirefox => value.contains('Firefox') || value.contains('FxiOS');

  /// Determines if the current device is running WebKit, or Blink, which is built on it.
  bool get isWebKit => value.contains('WebKit');

  /// Opera before version 15 used its own Presto engine, with its own CSS prefix.
  bool get _isPresto =>
      value.contains('Presto') || (value.contains('Opera') && !isWebKit);

  /// Gets the CSS property prefix for the current platform.
  String get cssPrefix {
    var prefix = _cachedCssPrefix;
    if (prefix != null) return prefix;
    if (isFirefox) {
      prefix = '-moz-';
    } else if (isIE) {
      prefix = '-ms-';
    } else if (_isPresto) {
      prefix = '-o-';
    } else {
      prefix = '-webkit-';
    }
    return _cachedCssPrefix = prefix;
  }

  /// Prefix as used for JS property names.
  String get propertyPrefix {
    var prefix = _cachedPropertyPrefix;
    if (prefix != null) return prefix;
    if (isFirefox) {
      prefix = 'moz';
    } else if (isIE) {
      prefix = 'ms';
    } else if (_isPresto) {
      prefix = 'o';
    } else {
      prefix = 'webkit';
    }
    return _cachedPropertyPrefix = prefix;
  }
}
