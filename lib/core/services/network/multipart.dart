import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class MultipartBody {
  String key;
  File? file;

  MultipartBody({required this.key,required this.file});
}

class MultipartDocument {
  String key;
  FilePickerResult? file;

  MultipartDocument(this.key, this.file);
}
