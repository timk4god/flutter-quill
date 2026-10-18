import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../../editor/raw_editor/raw_editor_state.dart';

/// Listen only while this editor owns the Flutter and DOM focus.
class WebClipboard {
  WebClipboard(this.state) {
    _copy = ((web.ClipboardEvent e) => _onCopy(e, true)).toJS;
    _cut = ((web.ClipboardEvent e) => _onCopy(e, false)).toJS;
    _paste = _onPaste.toJS;
    web.document.addEventListener('copy', _copy, true.toJS);
    web.document.addEventListener('cut', _cut, true.toJS);
    web.document.addEventListener('paste', _paste, true.toJS);
  }

  final QuillRawEditorState state;
  late final JSFunction _copy, _cut, _paste;

  bool _ownsEvent(web.ClipboardEvent event) {
    if (!state.mounted ||
        !state.widget.config.focusNode.hasFocus ||
        state.widget.config.disableClipboard ||
        event.defaultPrevented) {
      return false;
    }
    final target = event.target;
    // A native field can have focus without updating Flutter's focus tree.
    if (target.isA<web.Element>()) {
      final field = (target as web.Element).closest(
        'input, textarea, [contenteditable]',
      );
      if (field != null && !field.classList.contains('flt-text-editing')) {
        return false;
      }
    }
    return event.clipboardData != null;
  }

  void _onCopy(web.ClipboardEvent event, bool copy) {
    if (!_ownsEvent(event) || !state.widget.config.selectionEnabled) return;
    final handled = state.controller.clipboardSelection(
      copy,
      onCopy: (text, html) {
        event.clipboardData!
          ..setData('text/plain', text)
          ..setData('text/html', html);
      },
    );
    if (handled) {
      event
        ..preventDefault()
        ..stopImmediatePropagation();
    }
  }

  void _onPaste(web.ClipboardEvent event) {
    if (!_ownsEvent(event) || state.widget.config.readOnly) return;
    final data = event.clipboardData!;
    // Let the existing image/file paste paths handle non-text transfers.
    if (data.files.length > 0) return;
    final html = data.getData('text/html');
    final text = data.getData('text/plain');
    if (html.isEmpty && text.isEmpty) return;
    event
      ..preventDefault()
      ..stopImmediatePropagation();
    state.pasteText(
      SelectionChangedCause.keyboard,
      html: html,
      plainText: text,
    );
  }

  void dispose() {
    web.document.removeEventListener('copy', _copy, true.toJS);
    web.document.removeEventListener('cut', _cut, true.toJS);
    web.document.removeEventListener('paste', _paste, true.toJS);
  }
}

/// One clipboard item with both representations; two writes overwrite each other.
Future<void> writeWebClipboard(String text, String html) async {
  try {
    final item = web.ClipboardItem(
      {
            'text/plain': web.Blob(
              [text.toJS].toJS,
              web.BlobPropertyBag(type: 'text/plain'),
            ),
            'text/html': web.Blob(
              [html.toJS].toJS,
              web.BlobPropertyBag(type: 'text/html'),
            ),
          }.jsify()
          as JSObject,
    );
    await web.window.navigator.clipboard.write([item].toJS).toDart;
  } catch (_) {
    // Unsupported API, insecure context, or denied permission: retain plain copy.
    await Clipboard.setData(ClipboardData(text: text));
  }
}
