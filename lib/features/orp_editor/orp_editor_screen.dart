import 'package:flutter/material.dart';
import 'abbreviation_editor.dart';
class OrpEditorScreen extends StatelessWidget {
  const OrpEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Ausnahmen',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const AbbreviationEditor(),
    );
  }
}