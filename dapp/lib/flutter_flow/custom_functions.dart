import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';

String? uploadedFileToBase64WithDetectedMime(FFUploadedFile file) {
  if (file.bytes == null || file.bytes!.isEmpty) {
    return null;
  }

  final filename = file.name?.toLowerCase() ?? '';
  String mimeType;

  if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) {
    mimeType = 'image/jpeg';
  } else if (filename.endsWith('.png')) {
    mimeType = 'image/png';
  } else if (filename.endsWith('.gif')) {
    mimeType = 'image/gif';
  } else if (filename.endsWith('.pdf')) {
    mimeType = 'application/pdf';
  } else if (filename.endsWith('.svg')) {
    mimeType = 'image/svg+xml';
  } else if (filename.endsWith('.mp4')) {
    mimeType = 'video/mp4';
  } else if (filename.endsWith('.webp')) {
    mimeType = 'image/webp';
  } else {
    mimeType = 'application/octet-stream';
  }

  final base64String = base64Encode(file.bytes!);
  return 'data:$mimeType;base64,$base64String';
}
