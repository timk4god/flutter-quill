# Rich clipboard implementation and validation

Base: `singerdmx/flutter-quill` at `e880534f8750072c879fecd72ada72d0902bc5e8`.
Scope: web rich-text interoperability and shared HTML import corrections.

## Design review

- Follow the existing `ClipboardService` and conditional web-import patterns.
- Use local Delta/HTML conversion. `vsc_quill_delta_to_html` is already recommended
  by this repository; it is a library dependency, not an external API connection.
  `web` provides Dart bindings for browser APIs and was already used transitively.
- Copy HTML and plain text in one item. The existing bridge's HTML-only writer
  is deliberately not used: it can replace or corrupt the plain representation.
- Attach listeners per editor state, check focus and editing permissions, and
  remove the same listeners on disposal. Do not intercept other DOM fields.
- Use the browser paste-event payload rather than reading the clipboard again.
- Keep the internal Delta cache for exact same-session editor-to-editor paste.
  Both text and HTML must match the cached copy; matching plain text alone must
  not apply stale formatting to an unrelated external paste.
- Keep a final selected line's block attributes even if its newline is excluded.
  Escape text and use semantic headings/lists plus inline styles for other apps.

## Regression review

Controller tests cover partial and reversed selections, nested lists, escaping,
copy without an extra clipboard clear, read-only cut, collapsed copy, native
plain-text fallback, external HTML paste, empty HTML fallback, exact internal
Delta preservation, cache collisions, paste overrides, and rich-paste opt-out.

Chromium widget tests cover copy/cut, switching focus between editors, a native
DOM field, read-only copy with blocked mutations, disabled clipboard handling,
disposal, and leaving file/image transfer events alone.

Real Chromium keyboard testing additionally checks the operating-system clipboard
representations and transfers between FlutterQuill and a normal contenteditable
element and textarea. Synthetic events alone do not establish OS interoperability.

## Platform boundaries

| Platform or operation | Scope |
| --- | --- |
| Chromium web, keyboard copy/cut/paste | Automated browser tests and real clipboard checks |
| Web toolbar copy | Writes HTML/plain text together; falls back to plain copy if unsupported or denied |
| Firefox/Safari and mobile browsers | Same event-based design; real-browser/device verification still required |
| Native Android/iOS/macOS/Windows/Linux | Plain copy and existing native rich-paste paths retained; no claim of new native rich-copy support |
| Images, GIFs, HTML/Markdown files | Existing paths retained; web text listener does not consume file transfers |
| Google Docs, Word, Notion, Odoo | Application-specific round trips still need manual testing; no account integrations are introduced |

The HTML converter controls the fidelity of external formats. App-specific embeds,
tables, annotations, and custom formatting may not survive an HTML round trip.
Existing paste caret/style issues discussed in PR #2776 are separate from this
clipboard-format patch.

## Reproduce

Verified locally: 115 core tests passed, 7 Chromium clipboard tests passed, and
targeted analysis reported no issues. The release web build succeeded. Five real
keyboard/clipboard checks passed: dual-format copy, outbound heading/nested-list
paste, inbound heading/bullet/numbered-list paste without duplicate text, plain
field fallback, and formatted cut/undo.

No generated bridge code or native platform changes are included.

Use Flutter 3.44.9 / Dart 3.12.2 or a compatible newer SDK.

```sh
flutter pub get
flutter analyze --no-pub lib test/controller/rich_clipboard_test.dart test/editor/web_clipboard_test.dart
flutter test
flutter test --platform chrome test/editor/web_clipboard_test.dart
cd example
flutter build web -t lib/clipboard_demo.dart --no-web-resources-cdn
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080/clipboard_lab.html`. Test headings and nested lists in
both directions, then plain-text paste, cut/undo, partial-line selections, and
copy/paste between the two Flutter editors. A clipboard read/write permission may
be requested for toolbar actions; keyboard events use the supplied event data.

The root library and changed tests are analyzed separately because the initial
whole-repository analysis also visited extension-package tests and reported
unresolved symbols outside this change.

## Google Docs import correction

A representative Google Docs clipboard fixture reproduced the reported failure:
a neutral `<b id="docs-internal-guid-..." style="font-weight:normal">` wrapped
headings, paragraphs, and lists. The importer treated that entire subtree as
inline bold content, discarding the block boundaries and span formatting.
The paste path now unwraps this identified Docs container before conversion.
Ordinary bold tags and content before/after the wrapper are retained.

The converter also omitted paragraphs from its block-boundary rules, merging
adjacent `<p>` elements. The paste path now includes paragraphs while reusing the
converter's existing rules for other elements. The minimum converter dependency
is 1.5.3, which supplies the required block-override API.

New unit and Chromium tests cover headings, colors, nested numbering, paragraph
boundaries, and genuine bold. A real Chromium clipboard keyboard round trip with
this Docs-style fixture also passed. Live Google Docs clipboard payloads still
need application-specific verification.

The lab's local diagnostic reports HTML presence, character counts, and the Docs
wrapper marker. It does not send clipboard content anywhere. The build number
is visible in both the lab header and Flutter app title.
