import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
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

class NDIlibFourCCVideoType {
  static const int RGBA = 0x41424752; // 'R', 'G', 'B', 'A'
}

class NDIlibFrameFormatType {
  static const int progressive = 1;
}

final class NDIlib_video_frame_v2_t extends Struct {
  @Int32()
  external int xres;
  @Int32()
  external int yres;
  @Int32()
  external int FourCC;
  @Int32()
  external int frame_rate_N;
  @Int32()
  external int frame_rate_D;
  @Float()
  external double picture_aspect_ratio;
  @Int32()
  external int frame_format_type;
  @Int64()
  external int timecode;
  external Pointer<Uint8> p_data;
  @Int32()
  external int line_stride_in_bytes;
  external Pointer<Utf8> p_metadata;
  @Int64()
  external int timestamp;
}

typedef NDIlib_initialize_func = Bool Function();
typedef NDIlib_initialize_dart = bool Function();

typedef NDIlib_destroy_func = Void Function();
typedef NDIlib_destroy_dart = void Function();

typedef NDIlib_send_create_func = NDIlib_send_instance_t Function(Pointer<NDIlib_send_create_t>);
typedef NDIlib_send_create_dart = NDIlib_send_instance_t Function(Pointer<NDIlib_send_create_t>);

typedef NDIlib_send_send_video_v2_func = Void Function(NDIlib_send_instance_t, Pointer<NDIlib_video_frame_v2_t>);
typedef NDIlib_send_send_video_v2_dart = void Function(NDIlib_send_instance_t, Pointer<NDIlib_video_frame_v2_t>);

void main() async {
  late DynamicLibrary dylib;
  try {
    dylib = DynamicLibrary.open('Processing.NDI.Lib.x64.dll');
  } catch (e) {
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
  final sendSendVideo = dylib.lookupFunction<NDIlib_send_send_video_v2_func, NDIlib_send_send_video_v2_dart>('NDIlib_send_send_video_v2');
  
  if (!initialize()) {
    print('Failed to initialize NDI.');
    return;
  }
  
  print('NDI Initialized.');
  
  final pCreateSettings = calloc<NDIlib_send_create_t>();
  pCreateSettings.ref.p_ndi_name = 'Test Solid Red'.toNativeUtf8();
  pCreateSettings.ref.clock_video = false;
  pCreateSettings.ref.clock_audio = false;
  
  final sender = sendCreate(pCreateSettings);
  if (sender == nullptr || sender.address == 0) {
    print('Failed to create sender.');
    return;
  }
  
  print('Sender created successfully! Address: ${sender.address}');

  // Create a red frame
  const width = 1920;
  const height = 1080;
  const bytesPerPixel = 4;
  final totalBytes = width * height * bytesPerPixel;
  
  final frameBuffer = calloc<Uint8>(totalBytes);
  // Fill with solid red: R=255, G=0, B=0, A=255
  for (int i = 0; i < totalBytes; i += 4) {
    frameBuffer[i] = 255;     // R
    frameBuffer[i + 1] = 0;   // G
    frameBuffer[i + 2] = 0;   // B
    frameBuffer[i + 3] = 255; // A
  }

  final ndiFrame = calloc<NDIlib_video_frame_v2_t>();
  ndiFrame.ref.xres = width;
  ndiFrame.ref.yres = height;
  ndiFrame.ref.FourCC = NDIlibFourCCVideoType.RGBA;
  ndiFrame.ref.frame_rate_N = 30000;
  ndiFrame.ref.frame_rate_D = 1000;
  ndiFrame.ref.picture_aspect_ratio = width / height;
  ndiFrame.ref.frame_format_type = NDIlibFrameFormatType.progressive;
  ndiFrame.ref.timecode = 0x7FFFFFFFFFFFFFFF; // INT64_MAX
  ndiFrame.ref.p_data = frameBuffer;
  ndiFrame.ref.line_stride_in_bytes = width * bytesPerPixel;
  ndiFrame.ref.timestamp = 0;

  print('Sending frames for 15 seconds...');
  int framesSent = 0;
  
  final timer = Timer.periodic(Duration(milliseconds: 33), (t) {
    sendSendVideo(sender, ndiFrame);
    framesSent++;
    if (framesSent % 30 == 0) {
      print('Sent $framesSent frames. Check NDI Studio Monitor for "Test Solid Red"!');
    }
  });

  await Future.delayed(Duration(seconds: 15));
  timer.cancel();
  print('Done.');
}
