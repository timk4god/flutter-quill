# Rich clipboard implementation and validation

Scope: web rich-text interoperability and shared HTML import corrections.

## Design

- Browser copy/cut writes HTML and plain text in one clipboard item. The native
  path retains plain copy; the existing `ClipboardService` interface is unchanged.
- Editor-owned listeners check focus, read-only/selection settings, and native DOM
  fields. They are removed on disposal; file/image events retain existing handling.
- Browser paste consumes event data without another clipboard read. Matching text
  and HTML use the internal Delta cache to retain custom styles and embeds.
- Export preserves the final selected line's block style without requiring its
  newline. Semantic headings/lists and inline styles work without Quill CSS.
- Google Docs' neutral `<b id="docs-internal-guid-...">` wrapper is removed before
  conversion. Paragraphs supplement the converter's existing block rules, keeping
  paragraph boundaries, colors, nested lists, and genuine bold text.
- Conversion uses local libraries. HTML converter 1.5.3 supplies the block override;
  no account integrations, generated bridge code, or native platform changes are added.

## Validation

115 core tests and 7 Chromium clipboard tests passed. Library/changed-test analysis
is clean, and the release web example builds. Coverage includes partial/reversed
selections, nested lists, escaping, internal Delta preservation, cache collisions,
paste callbacks/opt-out, read-only behavior, focus switching, disposal, and files.

Real Chromium keyboard checks cover dual-format copy, rich paste in both directions,
plain fields, cut/undo, and a representative Google Docs clipboard fixture that
reproduced the collapsed-text failure. Synthetic events alone do not verify OS
clipboard interoperability.

```sh
flutter pub get
flutter analyze --no-pub lib test/controller/rich_clipboard_test.dart test/editor/web_clipboard_test.dart
flutter test
flutter test --platform chrome test/editor/web_clipboard_test.dart
cd example
flutter build web -t lib/clipboard_demo.dart --no-web-resources-cdn
python3 -m http.server 8080 --directory build/web
```

Use Flutter 3.44.9 / Dart 3.12.2 or compatible newer versions. Open
`http://localhost:8080/clipboard_lab.html`; its local diagnostic reports whether
HTML and a Docs wrapper were supplied, without sending clipboard content anywhere.

## Limits

Safari, Firefox, mobile devices, and live application-specific payloads still need
manual verification. Native rich-copy support is outside this change. Custom
embeds, tables, and annotations may not survive external HTML conversion. Existing
caret/style issues in #2776 remain separate.

Optional parameters added to experimental controller clipboard methods can require
matching signatures in custom overrides. Whole-repository analysis also visits
extension-package tests with unresolved symbols; the library and changed tests
are checked separately.
