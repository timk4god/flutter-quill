import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/src/controller/clipboard/selection_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final clipboardCalls = <MethodCall>[];

  setUp(() {
    clipboardCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          clipboardCalls.add(call);
          if (call.method == 'Clipboard.getData') {
            throw StateError('Event paste must not read the system clipboard');
          }
          return null;
        });
  });

  QuillController controller(List<Map<String, dynamic>> ops) {
    final result = QuillController(
      document: Document.fromJson(ops),
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(result.dispose);
    return result;
  }

  test('partial heading selection retains block style and escapes HTML', () {
    final c =
        controller([
          {'insert': '<Title>&'},
          {
            'insert': '\n',
            'attributes': {'header': 2},
          },
        ])..updateSelection(
          const TextSelection(baseOffset: 8, extentOffset: 0),
          ChangeSource.local,
        );
    expect(selectionToHtml(c), '<h2>&lt;Title&gt;&amp;</h2>');
    expect(c.document.toPlainText(), '<Title>&\n');
  });

  test(
    'Google Docs neutral bold wrapper retains blocks and span styles',
    () async {
      final c = controller([
        {'insert': '\n'},
      ]);
      await c.clipboardPaste(
        html:
            '<b id="docs-internal-guid-example" style="font-weight:normal">'
            '<h1><span style="font-weight:400">Launch Setup</span></h1>'
            '<p><span style="color:#ffcc00">SECONDARY </span>'
            '<span style="color:#ff0000">Customized</span></p>'
            '<ol><li><p><span>Saleable Products</span></p></li>'
            '<li><p><span>Basic Accounting</span></p>'
            '<ol><li><p><span>Full Chart of Accounts setup</span></p></li></ol>'
            '</li></ol><p><strong>Sales and CRM process</strong></p></b>',
        plainText:
            'Launch Setup\nSECONDARY Customized\nSaleable Products\n'
            'Basic Accounting\nFull Chart of Accounts setup\nSales and CRM process',
      );
      final ops = c.document.toDelta().toJson();
      expect(
        c.document.toPlainText(),
        contains('Launch Setup\nSECONDARY Customized\n'),
      );
      expect(
        ops,
        contains(
          equals({
            'insert': '\n',
            'attributes': {'header': 1},
          }),
        ),
      );
      expect(
        ops,
        contains(
          equals({
            'insert': '\n',
            'attributes': {'list': 'ordered', 'indent': 1},
          }),
        ),
      );
      expect(
        ops,
        contains(
          equals({
            'insert': 'Customized',
            'attributes': {'color': '#ff0000'},
          }),
        ),
      );
      final title = ops.firstWhere(
        (op) => (op['insert'] as String).contains('Launch Setup'),
      );
      expect(title['attributes']?['bold'], isNot(true));
      expect(
        ops,
        contains(
          equals({
            'insert': 'Sales and CRM process',
            'attributes': {'bold': true},
          }),
        ),
      );
    },
  );

  test('ordinary bold HTML and surrounding content are preserved', () async {
    final c = controller([
      {'insert': '\n'},
    ]);
    await c.clipboardPaste(
      html:
          '<p>Before</p><b id="docs-internal-guid-example" style="font-weight:normal">'
          '<p>Inside <b>genuine bold</b></p></b><p>After</p>',
      plainText: 'Before\nInside genuine bold\nAfter',
    );
    final ops = c.document.toDelta().toJson();
    expect(
      c.document.toPlainText(),
      contains('Before\nInside genuine bold\nAfter'),
    );
    expect(
      ops,
      contains(
        equals({
          'insert': 'genuine bold',
          'attributes': {'bold': true},
        }),
      ),
    );
  });

  test('partial final list item and nested lists retain semantic markup', () {
    final c =
        controller([
          {'insert': 'First'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'Child'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
        ])..updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 11),
          ChangeSource.local,
        );
    expect(selectionToHtml(c), contains('<ul>'));
    expect(
      selectionToHtml(c),
      contains('<li>First<ul><li>Child</li></ul></li>'),
    );
  });

  test(
    'event copy writes both formats without clearing the system clipboard',
    () {
      final c =
          controller([
            {'insert': 'Heading'},
            {
              'insert': '\n',
              'attributes': {'header': 1},
            },
          ])..updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 7),
            ChangeSource.local,
          );
      String? text, html;
      expect(
        c.clipboardSelection(
          true,
          onCopy: (t, h) {
            text = t;
            html = h;
          },
        ),
        isTrue,
      );
      expect(text, 'Heading');
      expect(html, '<h1>Heading</h1>');
      expect(clipboardCalls, isEmpty);
    },
  );

  test(
    'collapsed copy and read-only cut leave clipboard and document alone',
    () {
      final c = controller([
        {'insert': 'Keep\n'},
      ]);
      expect(c.clipboardSelection(true), isFalse);
      c
        ..readOnly = true
        ..updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
          ChangeSource.local,
        );
      expect(c.clipboardSelection(false), isFalse);
      expect(c.document.toPlainText(), 'Keep\n');
      expect(clipboardCalls, isEmpty);
    },
  );

  test(
    'native copy retains a plain-text fallback',
    () async {
      final c =
          controller([
            {'insert': 'Keep\n'},
          ])..updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
            ChangeSource.local,
          );
      expect(c.clipboardSelection(true), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(clipboardCalls.single.method, 'Clipboard.setData');
      expect(clipboardCalls.single.arguments, {'text': 'Keep'});
    },
    skip: const bool.fromEnvironment('dart.library.js_interop'),
  );

  test(
    'event HTML paste inserts headings and bullets without a clipboard read',
    () async {
      final c = controller([
        {'insert': '\n'},
      ]);
      await c.clipboardPaste(
        html: '<h2>Title</h2><ul><li>Item</li></ul>',
        plainText: 'Title\nItem',
      );
      final ops = c.document.toDelta().toJson();
      expect(
        ops,
        contains(
          equals({
            'insert': '\n',
            'attributes': {'header': 2},
          }),
        ),
      );
      expect(
        ops,
        contains(
          equals({
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          }),
        ),
      );
      expect(clipboardCalls, isEmpty);
    },
  );

  test(
    'empty HTML falls back to text without deleting the selection',
    () async {
      final c =
          controller([
            {'insert': 'Keep\n'},
          ])..updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
            ChangeSource.local,
          );
      await c.clipboardPaste(
        html: '<meta charset="utf-8"><span></span>',
        plainText: 'Safe',
      );
      expect(c.document.toPlainText(), 'Safe\n');
    },
  );

  test(
    'internal paste keeps exact Delta rather than round-tripping through HTML',
    () async {
      final source =
          controller([
            {
              'insert': 'Ab',
              'attributes': {'bold': true, 'custom': 'kept'},
            },
            {'insert': '\n'},
          ])..updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 2),
            ChangeSource.local,
          );
      late String text, html;
      source.clipboardSelection(
        true,
        onCopy: (t, h) {
          text = t;
          html = h;
        },
      );
      final target = controller([
        {'insert': '\n'},
      ]);
      await target.clipboardPaste(html: html, plainText: text);
      expect(
        target.document.toDelta().toJson().first,
        source.pasteDelta.toJson().first,
      );
    },
  );

  test(
    'external text matching the cache does not inherit cached styles',
    () async {
      controller([
          {
            'insert': 'Same',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ])
        ..updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
          ChangeSource.local,
        )
        ..clipboardSelection(true, onCopy: (_, _) {});
      final target = controller([
        {'insert': '\n'},
      ]);
      await target.clipboardPaste(html: '', plainText: 'Same');
      expect(target.document.toDelta().toJson(), [
        {'insert': 'Same\n'},
      ]);
    },
  );

  test('rich-paste opt-out and plain callback are respected', () async {
    final c = QuillController.basic(
      config: QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(
          enableExternalRichPaste: false,
          onPlainTextPaste: (text) async => text.toUpperCase(),
        ),
      ),
    );
    addTearDown(c.dispose);
    await c.clipboardPaste(html: '<h1>Title</h1>', plainText: 'Title');
    expect(c.document.toDelta().toJson(), [
      {'insert': 'TITLE\n'},
    ]);
  });

  test(
    'paste override and read-only controller prevent event insertion',
    () async {
      final c = QuillController.basic(
        config: QuillControllerConfig(
          clipboardConfig: QuillClipboardConfig(
            onClipboardPaste: () async => true,
          ),
        ),
      );
      addTearDown(c.dispose);
      await c.clipboardPaste(html: '<h1>Ignored</h1>', plainText: 'Ignored');
      expect(c.document.toPlainText(), '\n');
      c.readOnly = true;
      await c.clipboardPaste(html: '', plainText: 'Ignored');
      expect(c.document.toPlainText(), '\n');
    },
  );
}
