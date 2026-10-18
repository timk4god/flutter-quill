@internal
library;

// This file should not be exported as the APIs in it are meant for internal usage only

import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:meta/meta.dart';

import '../../../quill_delta.dart';
import '../../delta/delta_x.dart';
import '../../editor_toolbar_controller_shared/clipboard/clipboard_service_provider.dart';
import '../quill_controller.dart';

extension QuillControllerRichPaste on QuillController {
  /// Paste the HTML into the document from [html] if not null, otherwise
  /// will read it from the Clipboard in case the [ClipboardServiceProvider.instance]
  /// support it on the current platform.
  ///
  /// Return `true` if can paste or have pasted using HTML.
  Future<bool> pasteHTML({String? html}) async {
    final clipboardService = ClipboardServiceProvider.instance;

    final htmlText =
        html ??
        await clipboardService.getHtmlText() ??
        await clipboardService.getHtmlFile();
    if (htmlText != null) {
      final body = html_parser.parse(htmlText).body;
      // Docs uses a neutral <b> around whole documents. Treating it as inline
      // bold text flattens its paragraphs and lists in the HTML converter.
      for (final wrapper
          in body?.querySelectorAll('b[id^="docs-internal-guid-"]') ?? []) {
        wrapper.replaceWith(
          dom.DocumentFragment()..nodes.addAll(wrapper.nodes.toList()),
        );
      }
      final htmlBody = body?.outerHtml;
      final clipboardDelta = HtmlToDelta(
        // The converter's default block test omits paragraphs, merging adjacent
        // <p> elements. Keep its other block rules and include paragraphs.
        isBlockValidator: (tag) => tag == 'p' || dom.Element.tag(tag).isBlock,
      ).convert(htmlBody ?? htmlText);
      if (clipboardDelta.isEmpty) return false;

      await _pasteDelta(clipboardDelta);

      return true;
    }
    return false;
  }

  // Paste the Markdown into the document from [markdown] if not null, otherwise
  /// will read it from the Clipboard in case the [ClipboardServiceProvider.instance]
  /// support it on the current platform.
  ///
  /// Return `true` if can paste or have pasted using Markdown.
  Future<bool> pasteMarkdown() async {
    final clipboardService = ClipboardServiceProvider.instance;

    Future<String?> getMarkdown() async {
      final clipboardMarkdownFile = await clipboardService.getMarkdownFile();
      if (clipboardMarkdownFile != null) {
        return clipboardMarkdownFile;
      }
      return null;
    }

    final markdownText = await getMarkdown();
    if (markdownText != null) {
      // ignore: deprecated_member_use_from_same_package
      final clipboardDelta = DeltaX.fromMarkdown(markdownText);

      await _pasteDelta(clipboardDelta);

      return true;
    }
    return false;
  }

  @visibleForTesting
  Future<Delta> getDeltaToPaste(Delta clipboardDelta) async {
    final onRichTextPaste = config.clipboardConfig?.onRichTextPaste;
    if (onRichTextPaste != null) {
      final delta = await onRichTextPaste(clipboardDelta, true);
      if (delta != null) {
        return delta;
      }
    }
    return clipboardDelta;
  }

  Future<void> _pasteDelta(Delta clipboardDelta) async {
    replaceText(
      selection.start,
      selection.end - selection.start,
      // Ensure to await to pass Delta instead of Future<Delta> since this accept Object
      await getDeltaToPaste(clipboardDelta),
      TextSelection.collapsed(offset: selection.end),
    );
  }
}
