import 'package:flutter/services.dart';

import '../../editor/raw_editor/raw_editor_state.dart';

class WebClipboard {
  WebClipboard(QuillRawEditorState state);
  void dispose() {}
}

Future<void> writeWebClipboard(String text, String html) =>
    Clipboard.setData(ClipboardData(text: text));
