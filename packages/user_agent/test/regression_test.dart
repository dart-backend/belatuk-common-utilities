import 'package:test/test.dart';
import 'package:user_agent_analyzer/user_agent_analyzer.dart';

const iPhone =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1';
const iPad =
    'Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1';
const androidTablet =
    'Mozilla/5.0 (Linux; Android 10; SM-T510) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36';
const androidPhone =
    'Mozilla/5.0 (Linux; Android 10; Pixel 4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';
const transformerPrime =
    'Mozilla/5.0 (Linux; U; Android 4.0.3; en-us; Transformer Prime TF201 Build/IML74K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Safari/534.30';
const playbook =
    'Mozilla/5.0 (PlayBook; U; RIM Tablet OS 2.1.0; en-US) AppleWebKit/536.2+ (KHTML, like Gecko) Version/7.2.1.0 Safari/536.2+';
const macSafari =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';
const edge =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36 Edg/120.0';
const opera =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36 OPR/106.0';
const operaPresto =
    'Opera/9.80 (Windows NT 6.1; WOW64) Presto/2.12.388 Version/12.18';
const chromeIOS =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/120.0 Mobile/15E148 Safari/604.1';
const ie7 = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)';
const firefoxIOS =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/120.0 Mobile/15E148 Safari/605.1.15';

void main() {
  group('devices', () {
    test('an iPhone is mobile, not a Mac or a desktop', () {
      var ua = UserAgent(iPhone);
      expect(ua.isIOS, isTrue);
      expect(ua.isMobile, isTrue);
      expect(ua.isMacOS, isFalse);
      expect(ua.isDesktop, isFalse);
    });

    test('an iPad is a tablet, not a Mac or a desktop', () {
      var ua = UserAgent(iPad);
      expect(ua.isTablet, isTrue);
      expect(ua.isMacOS, isFalse);
      expect(ua.isDesktop, isFalse);
    });

    test('an Android tablet is a tablet, not a desktop', () {
      var ua = UserAgent(androidTablet);
      expect(ua.isAndroidTablet, isTrue);
      expect(ua.isTablet, isTrue);
      expect(ua.isDesktop, isFalse);
    });

    test('an Android phone is mobile, not a tablet', () {
      var ua = UserAgent(androidPhone);
      expect(ua.isMobile, isTrue);
      expect(ua.isTablet, isFalse);
    });

    test('a Mac is a desktop', () {
      var ua = UserAgent(macSafari);
      expect(ua.isMacOS, isTrue);
      expect(ua.isDesktop, isTrue);
    });

    test('"rim" inside another word is not a BlackBerry', () {
      expect(UserAgent(transformerPrime).isBlackberry, isFalse);
    });

    test('a PlayBook is a BlackBerry tablet', () {
      var ua = UserAgent(playbook);
      expect(ua.isBlackberryTablet, isTrue);
      expect(ua.isTablet, isTrue);
    });

    test('known prefixes are mobile', () {
      expect(
        UserAgent('SAMSUNG-SGH-E250/1.0 Profile/MIDP-2.0').isMobile,
        isTrue,
      );
      expect(UserAgent('SonyEricssonK750i/R1AA Browser/SEMC').isMobile, isTrue);
    });

    test('short keywords only match at the start of a word', () {
      expect(UserAgent('SwapBrowser/1.0 (Windows NT 10.0)').isMobile, isFalse);
      expect(UserAgent('Generic WAP2.0 browser').isMobile, isTrue);
    });
  });

  group('browsers', () {
    test('Safari', () {
      expect(UserAgent(macSafari).isSafari, isTrue);
      expect(UserAgent(iPhone).isSafari, isTrue);
      for (var other in [edge, opera, chromeIOS, firefoxIOS, androidPhone]) {
        expect(UserAgent(other).isSafari, isFalse, reason: other);
      }
    });

    test('Chrome', () {
      expect(UserAgent(chromeIOS).isChrome, isTrue);
      expect(UserAgent(androidPhone).isChrome, isTrue);
      expect(UserAgent(edge).isChrome, isFalse);
      expect(UserAgent(opera).isChrome, isFalse);
    });

    test('Edge', () {
      expect(UserAgent(edge).isEdge, isTrue);
      expect(UserAgent(androidPhone).isEdge, isFalse);
    });

    test('Opera', () {
      var ua = UserAgent(opera);
      expect(ua.isOpera, isTrue);
      expect(ua.cssPrefix, '-webkit-');
      expect(ua.propertyPrefix, 'webkit');
      var presto = UserAgent(operaPresto);
      expect(presto.isOpera, isTrue);
      expect(presto.cssPrefix, '-o-');
      expect(presto.propertyPrefix, 'o');
    });

    test('IE 7', () {
      var ua = UserAgent(ie7);
      expect(ua.isIE, isTrue);
      expect(ua.cssPrefix, '-ms-');
    });

    test('Firefox on iOS', () {
      expect(UserAgent(firefoxIOS).isFirefox, isTrue);
    });
  });
}
