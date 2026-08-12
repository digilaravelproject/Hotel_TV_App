import 'dart:io';

class MultipartBody {
  String key;
  File? file;

  MultipartBody({required this.key, required this.file});
}

class MultipartDocument {
  String key;
  File? file;

  MultipartDocument(this.key, this.file);
}
