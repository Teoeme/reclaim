import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'create_memory_image_widget.dart' show CreateMemoryImageWidget;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateMemoryImageModel extends FlutterFlowModel<CreateMemoryImageWidget> {
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
  bool isDataUploading = false;
  FFUploadedFile uploadedLocalFile =
      FFUploadedFile(bytes: Uint8List.fromList([]));

  // Stores action output result for [Backend Call - API (IPFS uploader)] action in Button widget.
  ApiCallResponse? apiResultrar;

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
  }
}
