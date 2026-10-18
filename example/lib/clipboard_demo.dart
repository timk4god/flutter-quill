import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    home: const ClipboardDemo(),
  ),
);

class ClipboardDemo extends StatefulWidget {
  const ClipboardDemo({super.key});

  @override
  State<ClipboardDemo> createState() => _ClipboardDemoState();
}

class _ClipboardDemoState extends State<ClipboardDemo> {
  final _source = QuillController(
    document: Document.fromJson([
      {'insert': 'Clipboard test'},
      {
        'insert': '\n',
        'attributes': {'header': 1},
      },
      {'insert': 'Copy headings, '},
      {
        'insert': 'bold',
        'attributes': {'bold': true},
      },
      {'insert': ' and '},
      {
        'insert': 'italic',
        'attributes': {'italic': true},
      },
      {'insert': ' text.\nFirst bullet'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet'},
      },
      {'insert': 'Nested bullet'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet', 'indent': 1},
      },
      {'insert': 'Numbered item'},
      {
        'insert': '\n',
        'attributes': {'list': 'ordered'},
      },
    ]),
    selection: const TextSelection.collapsed(offset: 0),
  );
  final _target = QuillController.basic();
  final _focus = [FocusNode(), FocusNode()];
  final _scroll = [ScrollController(), ScrollController()];

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    for (final node in _focus) {
      node.dispose();
    }
    for (final scroll in _scroll) {
      scroll.dispose();
    }
    super.dispose();
  }

  Widget _editor(String label, QuillController controller, int index) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: QuillEditor(
                  controller: controller,
                  focusNode: _focus[index],
                  scrollController: _scroll[index],
                  config: const QuillEditorConfig(padding: EdgeInsets.all(16)),
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FlutterQuill clipboard lab · build 2')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Select and copy from either editor. Paste into the other editor, '
            'the plain field, or another app. Try a heading without its final newline.',
          ),
          const SizedBox(height: 12),
          QuillSimpleToolbar(controller: _source),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                _editor('Source', _source, 0),
                const SizedBox(width: 16),
                _editor('Paste here', _target, 1),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Plain-text fallback',
            ),
          ),
        ],
      ),
    ),
  );
}
