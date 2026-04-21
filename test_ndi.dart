import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Copying necessary parts of NDI bindings
typedef NDIlib_send_instance_t = Pointer<Void>;

final class NDIlib_send_create_t extends Struct {
  external Pointer<Utf8> p_ndi_name;
  external Pointer<Utf8> p_groups;
  @Bool()
  external bool clock_video;
  @Bool()
  external bool clock_audio;
}

typedef NDIlib_initialize_func = Bool Function();
typedef NDIlib_initialize_dart = bool Function();

typedef NDIlib_destroy_func = Void Function();
typedef NDIlib_destroy_dart = void Function();

typedef NDIlib_send_create_func = NDIlib_send_instance_t Function(Pointer<NDIlib_send_create_t>);
typedef NDIlib_send_create_dart = NDIlib_send_instance_t Function(Pointer<NDIlib_send_create_t>);

void main() {
  late DynamicLibrary dylib;
  try {
    dylib = DynamicLibrary.open('Processing.NDI.Lib.x64.dll');
  } catch (e) {
    print('Failed to open dll directly: $e');
    for (final version in ['V6', 'V5', 'V4', 'V3', 'V2']) {
      final envVar = 'NDI_RUNTIME_DIR_$version';
      final ndiPath = Platform.environment[envVar];
      if (ndiPath != null) {
        final dllPath = '$ndiPath\\Processing.NDI.Lib.x64.dll';
        if (File(dllPath).existsSync()) {
          dylib = DynamicLibrary.open(dllPath);
          break;
        }
      }
    }
  }

  print('Library loaded successfully.');

  final initialize = dylib.lookupFunction<NDIlib_initialize_func, NDIlib_initialize_dart>('NDIlib_initialize');
  final sendCreate = dylib.lookupFunction<NDIlib_send_create_func, NDIlib_send_create_dart>('NDIlib_send_create');
  
  if (!initialize()) {
    print('Failed to initialize NDI.');
    return;
  }
  
  print('NDI Initialized.');
  
  final pCreateSettings = calloc<NDIlib_send_create_t>();
  pCreateSettings.ref.p_ndi_name = 'Test Stream'.toNativeUtf8();
  pCreateSettings.ref.clock_video = false;
  pCreateSettings.ref.clock_audio = false;
  
  final sender = sendCreate(pCreateSettings);
  if (sender == nullptr || sender.address == 0) {
    print('Failed to create sender.');
    return;
  }
  
  print('Sender created successfully! Address: ${sender.address}');
  print('Holding stream for 10 seconds...');
  sleep(Duration(seconds: 10));
  print('Done.');
}
