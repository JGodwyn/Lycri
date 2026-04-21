import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- NDI Type Definitions ---

typedef NDIlib_send_instance_t = Pointer<Void>;

final class NDIlib_send_create_t extends Struct {
  external Pointer<Utf8> p_ndi_name;
  external Pointer<Utf8> p_groups;
  @Bool()
  external bool clock_video;
  @Bool()
  external bool clock_audio;
}

// enum NDIlib_FourCC_video_type_e
class NDIlibFourCCVideoType {
  static const int UYVY = 0x59565955;
  static const int UYVA = 0x41565955;
  static const int P216 = 0x36313250;
  static const int PA16 = 0x36314150;
  static const int YV12 = 0x32315659;
  static const int I420 = 0x30323449;
  static const int NV12 = 0x3231564E;
  static const int BGRA = 0x41524742;
  static const int BGRX = 0x58524742;
  static const int RGBA = 0x41424752;
  static const int RGBX = 0x58424752;
}

// enum NDIlib_frame_format_type_e
class NDIlibFrameFormatType {
  static const int progressive = 1;
  static const int interleaved = 0;
  static const int field_0 = 2;
  static const int field_1 = 3;
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

// --- FFI Signature Definitions ---

// bool NDIlib_initialize(void);
typedef NDIlib_initialize_func = Bool Function();
typedef NDIlib_initialize_dart = bool Function();

// void NDIlib_destroy(void);
typedef NDIlib_destroy_func = Void Function();
typedef NDIlib_destroy_dart = void Function();

// NDIlib_send_instance_t NDIlib_send_create(const NDIlib_send_create_t* p_create_settings);
typedef NDIlib_send_create_func = NDIlib_send_instance_t Function(Pointer<NDIlib_send_create_t>);
typedef NDIlib_send_create_dart = NDIlib_send_instance_t Function(Pointer<NDIlib_send_create_t>);

// void NDIlib_send_destroy(NDIlib_send_instance_t p_instance);
typedef NDIlib_send_destroy_func = Void Function(NDIlib_send_instance_t);
typedef NDIlib_send_destroy_dart = void Function(NDIlib_send_instance_t);

// void NDIlib_send_send_video_v2(NDIlib_send_instance_t p_instance, const NDIlib_video_frame_v2_t* p_video_data);
typedef NDIlib_send_send_video_v2_func = Void Function(NDIlib_send_instance_t, Pointer<NDIlib_video_frame_v2_t>);
typedef NDIlib_send_send_video_v2_dart = void Function(NDIlib_send_instance_t, Pointer<NDIlib_video_frame_v2_t>);

// --- NDI Bindings Wrapper ---

class NDIBindings {
  late DynamicLibrary _dylib;

  late NDIlib_initialize_dart initialize;
  late NDIlib_destroy_dart destroy;
  late NDIlib_send_create_dart sendCreate;
  late NDIlib_send_destroy_dart sendDestroy;
  late NDIlib_send_send_video_v2_dart sendSendVideo;

  bool setup() {
    try {
      _dylib = _openNdiLibrary();
      initialize = _dylib.lookupFunction<NDIlib_initialize_func, NDIlib_initialize_dart>('NDIlib_initialize');
      destroy = _dylib.lookupFunction<NDIlib_destroy_func, NDIlib_destroy_dart>('NDIlib_destroy');
      sendCreate = _dylib.lookupFunction<NDIlib_send_create_func, NDIlib_send_create_dart>('NDIlib_send_create');
      sendDestroy = _dylib.lookupFunction<NDIlib_send_destroy_func, NDIlib_send_destroy_dart>('NDIlib_send_destroy');
      sendSendVideo = _dylib.lookupFunction<NDIlib_send_send_video_v2_func, NDIlib_send_send_video_v2_dart>('NDIlib_send_send_video_v2');
      return true;
    } catch (e) {
      print('NDI: Failed to load NDI library: $e');
      return false;
    }
  }

  /// Opens the NDI dynamic library for the current platform.
  ///
  /// - **macOS**: Looks for `libndi.dylib` at `/usr/local/lib/` (NDI Runtime
  ///   standard install location).
  /// - **Windows**: Looks for `Processing.NDI.Lib.x64.dll`. The NDI Runtime
  ///   installer adds its directory to the system PATH, so
  ///   `DynamicLibrary.open` resolves it automatically.
  static DynamicLibrary _openNdiLibrary() {
    if (Platform.isMacOS) {
      return DynamicLibrary.open('/usr/local/lib/libndi.dylib');
    } else if (Platform.isWindows) {
      try {
        return DynamicLibrary.open('Processing.NDI.Lib.x64.dll');
      } catch (_) {
        for (final version in ['V6', 'V5', 'V4', 'V3', 'V2']) {
          final envVar = 'NDI_RUNTIME_DIR_$version';
          final ndiPath = Platform.environment[envVar];
          if (ndiPath != null) {
            final dllPath = '$ndiPath\\Processing.NDI.Lib.x64.dll';
            if (File(dllPath).existsSync()) {
              return DynamicLibrary.open(dllPath);
            }
          }
        }
        rethrow;
      }
    } else {
      throw UnsupportedError(
        'NDI is not supported on ${Platform.operatingSystem}',
      );
    }
  }
}
