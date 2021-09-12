# User Agent Analyzer

[![version](https://img.shields.io/badge/pub-v3.1.0-brightgreen)](https://pub.dev/packages/user_agent_analyzer)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/user_agent/LICENSE)

**Replacement of `package:user_agent` with breaking changes to support NNBD.**

A library to identify the type of devices and web browsers based on `User-Agent` string.

Runs anywhere.

```dart
void main() async {
    app.get('/', (req, res) async {
        var ua = UserAgent(req.headers.value('user-agent'));

        if (ua.isChrome) {
            res.redirect('/upgrade-your-browser');
            return;
        } else {
            // ...
        }
    });
}
```
