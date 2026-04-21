import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ndi_bindings_ffi.dart';

part 'ndi_service.g.dart';

@Riverpod(keepAlive: true)
class NdiService extends _$NdiService {
  final NDIBindings _bindings = NDIBindings();
  NDIlib_send_instance_t? _sender_instance;
  Pointer<NDIlib_video_frame_v2_t>? _ndiFrame;
  Pointer<Uint8>? _frameBuffer;
  
  Timer? _streamingTimer;
  
  static const int _width = 1920;
  static const int _height = 1080;
  static const int _bytesPerPixel = 4; // RGBA
  
  @override
  bool build() {
    ref.onDispose(() {
      stopStreaming();
    });
    return false; // represents 'isStreaming' state
  }

  Future<void> startStreaming() async {
    if (state) return;
    
    // 1. Setup Bindings
    if (!_bindings.setup()) {
      print('NDI: Failed to load bindings.');
      return;
    }
    
    // 2. Initialize NDI
    if (!_bindings.initialize()) {
      print('NDI: Failed to initialize NDI.');
      return;
    }
    
    // 3. Create NDI Sender
    final pCreateSettings = calloc<NDIlib_send_create_t>();
    pCreateSettings.ref.p_ndi_name = 'Lycri Lyrics Output'.toNativeUtf8();
    pCreateSettings.ref.clock_video = false; // We manage timing ourselves
    pCreateSettings.ref.clock_audio = false;
    
    _sender_instance = _bindings.sendCreate(pCreateSettings);
    
    // Do not free pCreateSettings or p_ndi_name here, as NDI might retain these pointers internally.
    
    if (_sender_instance == nullptr || _sender_instance!.address == 0) {
      print('NDI: Failed to create sender.');
      return;
    }
    
    // 4. Allocate Frame Buffer
    int totalBytes = _width * _height * _bytesPerPixel;
    _frameBuffer = calloc<Uint8>(totalBytes);
    
    _ndiFrame = calloc<NDIlib_video_frame_v2_t>();
    _ndiFrame!.ref.xres = _width;
    _ndiFrame!.ref.yres = _height;
    // We get RGBA from Flutter's rawRgba
    _ndiFrame!.ref.FourCC = NDIlibFourCCVideoType.RGBA;
    _ndiFrame!.ref.frame_rate_N = 30000;
    _ndiFrame!.ref.frame_rate_D = 1000;
    _ndiFrame!.ref.picture_aspect_ratio = _width / _height;
    _ndiFrame!.ref.frame_format_type = NDIlibFrameFormatType.progressive;
    _ndiFrame!.ref.timecode = 0x7FFFFFFFFFFFFFFF; // NDIlib_send_timecode_synthesize
    _ndiFrame!.ref.p_data = _frameBuffer!;
    _ndiFrame!.ref.line_stride_in_bytes = _width * _bytesPerPixel;
    _ndiFrame!.ref.timestamp = 0;
    
    // Start continuous timer (30 fps)
    state = true;
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _sendFrame();
    });
    print('NDI: Streaming started');
  }

  void stopStreaming() {
    print('NDI: Stopping stream.');
    _streamingTimer?.cancel();
    _streamingTimer = null;
    
    if (_sender_instance != null && _sender_instance!.address != 0) {
      _bindings.sendDestroy(_sender_instance!);
      _sender_instance = null;
    }
    
    if (_frameBuffer != null) {
      calloc.free(_frameBuffer!);
      _frameBuffer = null;
    }
    
    if (_ndiFrame != null) {
      calloc.free(_ndiFrame!);
      _ndiFrame = null;
    }
    
    // NDIlib_destroy might interfere if other NDI components exist, but safe here.
    try {
      _bindings.destroy();
    } catch (_) {}
    
    state = false;
  }

  int _frameUpdateCount = 0;
  void updateFrameBuffer(Uint8List newBytes) {
    if (!state || _frameBuffer == null) return;
    
    _frameUpdateCount++;
    if (_frameUpdateCount % 30 == 0) {
      print('NDI: updateFrameBuffer called (frame $_frameUpdateCount), size: ${newBytes.length}');
    }

    // Very fast copy from Uint8List to native Pointer
    final nativeBytes = _frameBuffer!.asTypedList(newBytes.length);
    nativeBytes.setAll(0, newBytes);
  }

  void _sendFrame() {
    if (!state || _sender_instance == null || _ndiFrame == null) return;
    
    // Send the video frame
    try {
      _bindings.sendSendVideo(_sender_instance!, _ndiFrame!);
    } catch (e) {
      print('NDI: Error sending frame: $e');
    }
  }
}
