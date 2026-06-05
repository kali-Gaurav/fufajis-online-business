import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for AI-powered image processing including background removal
/// Integrates with various background removal APIs
class ImageProcessingService {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // API endpoints for background removal (configurable)
  static const String _removeBgApiUrl = 'https://api.remove.bg/v1.0/removebg';
  static const String _photoroomApiUrl = 'https://api.photoroom.com/v1/segment';
  static const String _clipdropApiUrl = 'https://clipdrop-api.co/remove-background/v1';     

  /// Pick an image from gallery or camera and process it
  Future<File?> pickAndProcessImage(BuildContext context, {
    ImageSource source = ImageSource.gallery,
    bool removeBackground = true,
    bool enhanceColors = true,
    double? targetWidth,
    double? targetHeight,
  }) async {
    try {
      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: targetWidth,
        maxHeight: targetHeight,
        imageQuality: 90,
      );

      if (pickedFile == null) return null;

      File imageFile = File(pickedFile.path);

      // Process image if requested
      if (removeBackground || enhanceColors) {
        imageFile = await processImage(
          imageFile,
          removeBackground: removeBackground,
          enhanceColors: enhanceColors,
        );
      }

      return imageFile;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Process an image with AI enhancements
  Future<File> processImage(
    File imageFile, {
    bool removeBackground = false,
    bool enhanceColors = false,
    bool sharpen = false,
    double brightness = 0.0,
    double contrast = 0.0,
  }) async {
    File processedFile = imageFile;

    // Apply background removal if requested
    if (removeBackground) {
      processedFile = await removeBackgroundAI(processedFile);
    }

    // Apply color enhancement if requested
    if (enhanceColors) {
      processedFile = await enhanceColorsAI(processedFile, brightness, contrast);
    }

    // Apply sharpening if requested
    if (sharpen) {
      processedFile = await sharpenImage(processedFile);
    }

    return processedFile;
  }

  /// Remove background from image using AI
  /// Note: This requires an API key from remove.bg or similar service
  Future<File> removeBackgroundAI(File imageFile) async {
    String apiKey = const String.fromEnvironment('REMOVE_BG_API_KEY', defaultValue: '');
    if (apiKey.isEmpty) {
      try {
        apiKey = dotenv.env['REMOVE_BG_API_KEY'] ?? '';
      } catch (_) {}
    }
    
    if (apiKey.isEmpty) {
      debugPrint('No Background Removal API Key found. Returning original image.');
      return imageFile;
    }

    try {
      debugPrint('Calling background removal API...');
      
      final request = http.MultipartRequest('POST', Uri.parse(_removeBgApiUrl))
        ..headers['X-Api-Key'] = apiKey
        ..fields['size'] = 'auto'
        ..files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBytes = await response.stream.toBytes();
        final directory = await getTemporaryDirectory();
        final outputPath = '${directory.path}/nobg_${DateTime.now().millisecondsSinceEpoch}.png';
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(responseBytes);
        return outputFile;
      } else {
        debugPrint('Background removal failed with status: ${response.statusCode}');
        return imageFile;
      }
    } catch (e) {
      debugPrint('Background removal failed with error: $e');
      return imageFile;
    }
  }

  Future<File> enhanceColorsAI(File imageFile, double brightness, double contrast) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      final double targetContrast = 1.0 + contrast;
      final double targetBrightness = 1.0 + brightness;

      image = img.adjustColor(image, contrast: targetContrast, brightness: targetBrightness);

      final directory = await getTemporaryDirectory();
      final outputPath = '${directory.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(image));
      return outputFile;
    } catch (e) {
      debugPrint('Error enhancing colors: $e');
      return imageFile;
    }
  }

  Future<File> sharpenImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      image = img.convolution(image, filter: [
         0, -1,  0,
        -1,  5, -1,
         0, -1,  0
      ]);

      final directory = await getTemporaryDirectory();
      final outputPath = '${directory.path}/sharpened_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(image));
      return outputFile;
    } catch (e) {
      debugPrint('Error sharpening image: $e');
      return imageFile;
    }
  }

  /// Uploads a compressed image to Firebase Storage (Step 8.2)
  Future<String?> uploadCompressedImage(XFile image, String path) async {
    try {
      final bytes = await image.readAsBytes();
      // Compression is implicitly handled by pickImage's quality in real usage,
      // here we just upload the bytes.
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putData(
        bytes, 
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('[ImageProcessingService] Upload failed: $e');
      return null;
    }
  }
}
