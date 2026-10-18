@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late QuillController first, second;
  late FocusNode firstFocus, secondFocus;
  late ScrollController firstScroll, secondScroll;

  setUp(() {
    first = QuillController(
      document: Document.fromJson([
        {'insert': 'Title'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    second = QuillController.basic();
    firstFocus = FocusNode();
    secondFocus = FocusNode();
    firstScroll = ScrollController();
    secondScroll = ScrollController();
  });

  tearDown(() {
    first.dispose();
    second.dispose();
    firstFocus.dispose();
    secondFocus.dispose();
    firstScroll.dispose();
    secondScroll.dispose();
  });

  Future<void> showEditors(
    WidgetTester tester, {
    bool readOnly = false,
    bool disableClipboard = false,
  }) async {
    first.readOnly = readOnly;
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(
              child: QuillEditor(
                controller: first,
                focusNode: firstFocus,
                scrollController: firstScroll,
                config: QuillEditorConfig(disableClipboard: disableClipboard),
              ),
            ),
            Expanded(
              child: QuillEditor(
                controller: second,
                focusNode: secondFocus,
                scrollController: secondScroll,
              ),
            ),
          ],
        ),
      ),
    );
    firstFocus.requestFocus();
    await tester.pumpAndSettle();
  }

  web.ClipboardEvent event(String type, web.DataTransfer data) =>
      web.ClipboardEvent(
        type,
        web.ClipboardEventInit(
          clipboardData: data,
          bubbles: true,
          cancelable: true,
        ),
      );

  web.DataTransfer richData() => web.DataTransfer()
    ..setData('text/plain', 'Item')
    ..setData('text/html', '<ul><li>Item</li></ul>');

  void clipboardTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }

  clipboardTest('copy and cut publish HTML and plain text once', (
    tester,
  ) async {
    await showEditors(tester);
    first.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    final data = web.DataTransfer();
    final copy = event('copy', data);
    web.document.dispatchEvent(copy);
    expect(copy.defaultPrevented, isTrue);
    expect(data.getData('text/plain'), 'Title');
    expect(data.getData('text/html'), '<h1>Title</h1>');
    expect(first.document.toPlainText(), 'Title\n');
    final cut = event('cut', web.DataTransfer());
    web.document.dispatchEvent(cut);
    await tester.pumpAndSettle();
    expect(cut.defaultPrevented, isTrue);
    expect(first.document.toPlainText(), '\n');
    expect(second.document.toPlainText(), '\n');
  });

  clipboardTest('only the focused editor receives paste; focus can switch', (
    tester,
  ) async {
    await showEditors(tester);
    final paste = event('paste', richData());
    web.document.dispatchEvent(paste);
    await tester.pumpAndSettle();
    expect(paste.defaultPrevented, isTrue);
    expect('Item'.allMatches(first.document.toPlainText()).length, 1);
    expect(first.document.toPlainText(), endsWith('Title\n'));
    expect(second.document.toPlainText(), '\n');
    secondFocus.requestFocus();
    await tester.pumpAndSettle();
    web.document.dispatchEvent(event('paste', richData()));
    await tester.pumpAndSettle();
    expect(second.document.toPlainText().trim(), 'Item');
    expect(
      second.document.toDelta().toJson(),
      contains(
        equals({
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        }),
      ),
    );
  });

  clipboardTest('Google Docs paste event preserves heading, color, and lists', (
    tester,
  ) async {
    await showEditors(tester);
    final data = web.DataTransfer()
      ..setData('text/plain', 'Docs heading\nRed item\nNested item')
      ..setData(
        'text/html',
        '<b id="docs-internal-guid-browser" style="font-weight:normal">'
            '<h2>Docs heading</h2><ol><li><p><span style="color:#ff0000">Red item</span></p>'
            '<ol><li>Nested item</li></ol></li></ol></b>',
      );
    final paste = event('paste', data);
    web.document.dispatchEvent(paste);
    await tester.pumpAndSettle();
    expect(paste.defaultPrevented, isTrue);
    expect(
      first.document.toPlainText(),
      contains('Docs heading\nRed item\nNested item\n'),
    );
    final ops = first.document.toDelta().toJson();
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
          'attributes': {'list': 'ordered', 'indent': 1},
        }),
      ),
    );
    expect(
      ops,
      contains(
        equals({
          'insert': 'Red item',
          'attributes': {'color': '#ff0000'},
        }),
      ),
    );
  });

  clipboardTest('native DOM fields retain their paste event', (tester) async {
    await showEditors(tester);
    final field = web.HTMLTextAreaElement();
    web.document.body!.append(field);
    field.focus();
    final paste = event('paste', richData());
    field.dispatchEvent(paste);
    await tester.pumpAndSettle();
    expect(paste.defaultPrevented, isFalse);
    expect(first.document.toPlainText(), 'Title\n');
    field.remove();
  });

  clipboardTest('read-only copy works, but cut and paste are untouched', (
    tester,
  ) async {
    await showEditors(tester, readOnly: true);
    first.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    final copy = event('copy', web.DataTransfer());
    web.document.dispatchEvent(copy);
    expect(copy.defaultPrevented, isTrue);
    final cut = event('cut', web.DataTransfer());
    final paste = event('paste', richData());
    web.document.dispatchEvent(cut);
    web.document.dispatchEvent(paste);
    await tester.pumpAndSettle();
    expect(cut.defaultPrevented, isFalse);
    expect(paste.defaultPrevented, isFalse);
    expect(first.document.toPlainText(), 'Title\n');
  });

  clipboardTest('disabled clipboard and disposed editors do not intercept', (
    tester,
  ) async {
    await showEditors(tester, disableClipboard: true);
    final paste = event('paste', richData());
    web.document.dispatchEvent(paste);
    expect(paste.defaultPrevented, isFalse);
    await tester.pumpWidget(const SizedBox());
    final afterDispose = event('paste', richData());
    web.document.dispatchEvent(afterDispose);
    expect(afterDispose.defaultPrevented, isFalse);
  });

  clipboardTest('non-text paste is left to existing image and file handling', (
    tester,
  ) async {
    await showEditors(tester);
    final paste = event('paste', web.DataTransfer());
    web.document.dispatchEvent(paste);
    expect(paste.defaultPrevented, isFalse);
    expect(first.document.toPlainText(), 'Title\n');
    final files = richData();
    files.items.add(
      web.File(
        ['image'.toJS].toJS,
        'image.png',
        web.FilePropertyBag(type: 'image/png'),
      ),
    );
    final imagePaste = event('paste', files);
    web.document.dispatchEvent(imagePaste);
    expect(imagePaste.defaultPrevented, isFalse);
  });
}
