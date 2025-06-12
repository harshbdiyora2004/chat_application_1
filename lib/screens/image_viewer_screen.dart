import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageViewerScreen extends StatefulWidget {
  final String base64Image;
  final String? caption;
  final String senderName;
  final DateTime timestamp;

  const ImageViewerScreen({
    super.key,
    required this.base64Image,
    this.caption,
    required this.senderName,
    required this.timestamp,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isDownloading = false;

  // ignore: unused_element
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted) return true;
      if (await Permission.storage.request().isGranted) return true;

      // For Android 11+ (API 30+)
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }

      // For Android 13+ (API 33+)
      if (await Permission.photos.isGranted) return true;
      if (await Permission.photos.request().isGranted) return true;

      return false;
    }
    // For iOS, just return true (handled by image_gallery_saver)
    return true;
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    try {
      setState(() => _isDownloading = true);

      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }

      // Save to app-specific external storage
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Could not access storage');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/IMG_$timestamp.jpg';
      final imageBytes = base64Decode(widget.base64Image);
      final file = File(path);
      await file.writeAsBytes(imageBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareImage() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/share_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(base64Decode(widget.base64Image));
      await Share.shareFiles([tempFile.path], text: widget.caption);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareImage,
          ),
          IconButton(
            icon: Icon(
              _isDownloading ? Icons.downloading : Icons.download,
              color: Colors.white,
            ),
            onPressed: _downloadImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PhotoView(
              imageProvider: MemoryImage(base64Decode(widget.base64Image)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Text(
                widget.caption!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
