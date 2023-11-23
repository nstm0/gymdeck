import 'dart:io';
import 'dart:ffi';

String _filename() {
  return 'libsysres-x86_64.so';
}

Future<DynamicLibrary> loadLibsysres = () async {
  String objectFile;

  objectFile = '${File.fromUri(Platform.script).parent.path}/${_filename()}';

  return DynamicLibrary.open(objectFile);
}();
