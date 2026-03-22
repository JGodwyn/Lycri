import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_colors.dart';

/// A widget that handles the automatic generation and display of a 
/// video thumbnail from a local file path.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailPath;
  bool _error = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      // 1. Get unique cache filename for this video path
      final bytes = md5.convert(widget.videoPath.codeUnits).toString();
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(tempDir.path, 'lycri_thumbnails'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final thumbFile = p.join(cacheDir.path, '$bytes.jpg');

      // 2. Check if already exists in cache
      if (await File(thumbFile).exists()) {
        if (mounted) {
          setState(() {
            _thumbnailPath = thumbFile;
            _loading = false;
          });
        }
        return;
      }

      // 3. Generate thumbnail
      final plugin = FcNativeVideoThumbnail();
      await plugin.saveThumbnailToFile(
        srcFile: widget.videoPath,
        destFile: thumbFile,
        width: 120,
        height: 120,
        format: 'jpeg',
        quality: 80,
      );


      if (mounted) {
        setState(() {
          _thumbnailPath = thumbFile;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_loading) {
      child = Container(
        color: AppColors.surface3,
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.orange400,
            ),

          ),
        ),
      );
    } else if (_error || _thumbnailPath == null) {
      child = Container(
        color: AppColors.surface3,
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Icon(Icons.videocam_off, size: 16, color: AppColors.iconSubtle),
        ),
      );
    } else {
      child = Image.file(
        File(_thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        cacheWidth: 80,
        cacheHeight: 80,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.surface3,
          child: const Center(
            child: Icon(Icons.broken_image, size: 16, color: AppColors.iconSubtle),
          ),
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    return child;
  }
}
