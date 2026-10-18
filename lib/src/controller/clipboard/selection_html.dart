import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../../document/attribute.dart';
import '../quill_controller.dart';

/// Include the last line's block style even when its newline is not selected.
String selectionToHtml(QuillController controller) {
  final selection = controller.selection;
  final delta = controller.document.toDelta().slice(
    selection.start,
    selection.end,
  );
  if (delta.isEmpty) return '';
  final last = delta.last.data;
  if (last is! String || !last.endsWith('\n')) {
    final style = controller.document.collectStyle(selection.end - 1, 1);
    delta.insert('\n', {
      for (final attr in style.values)
        if (attr.scope == AttributeScope.block) attr.key: attr.value,
    });
  }
  return QuillDeltaToHtmlConverter(
    delta.toJson(),
    ConverterOptions(
      multiLineHeader: false,
      multiLineParagraph: false,
      converterOptions: OpConverterOptions(inlineStylesFlag: true),
    ),
  ).convert();
}
