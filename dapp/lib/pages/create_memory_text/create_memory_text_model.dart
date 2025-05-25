import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'create_memory_text_widget.dart' show CreateMemoryTextWidget;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateMemoryTextModel extends FlutterFlowModel<CreateMemoryTextWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for MemoryName widget.
  FocusNode? memoryNameFocusNode;
  TextEditingController? memoryNameTextController;
  String? Function(BuildContext, String?)? memoryNameTextControllerValidator;
  String? _memoryNameTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Memory Name is required';
    }

    return null;
  }

  // State field(s) for MemoryDescription widget.
  FocusNode? memoryDescriptionFocusNode;
  TextEditingController? memoryDescriptionTextController;
  String? Function(BuildContext, String?)?
      memoryDescriptionTextControllerValidator;
  DateTime? datePicked;
  // State field(s) for SecretText widget.
  FocusNode? secretTextFocusNode;
  TextEditingController? secretTextTextController;
  String? Function(BuildContext, String?)? secretTextTextControllerValidator;

  @override
  void initState(BuildContext context) {
    memoryNameTextControllerValidator = _memoryNameTextControllerValidator;
  }

  @override
  void dispose() {
    memoryNameFocusNode?.dispose();
    memoryNameTextController?.dispose();

    memoryDescriptionFocusNode?.dispose();
    memoryDescriptionTextController?.dispose();

    secretTextFocusNode?.dispose();
    secretTextTextController?.dispose();
  }
}
