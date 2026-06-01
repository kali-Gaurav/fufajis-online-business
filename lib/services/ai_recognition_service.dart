import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

/// Service for AI-powered product recognition and OCR
class AIRecognitionService {
  ImageLabeler? _imageLabeler;
  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;

  /// Initialize ML services
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configure image labeling for product recognition
    final ImageLabelerOptions options = ImageLabelerOptions(
      confidenceThreshold: 0.5,
    );
    _imageLabeler = ImageLabeler(options: options);

    // Configure text recognition for OCR
    _textRecognizer = TextRecognizer();

    _isInitialized = true;
  }

  /// Check if the device is currently offline
  Future<bool> isOffline() async {
    try {
      final dynamic connectivityRes = await Connectivity().checkConnectivity();
      final List<ConnectivityResult> connectivityResult = (connectivityRes is List) 
          ? List<ConnectivityResult>.from(connectivityRes) 
          : [connectivityRes as ConnectivityResult];
      return connectivityResult.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Identify product from image using AI
  Future<List<ProductRecognitionResult>> identifyProduct(XFile image) async {
    if (!_isInitialized) await initialize();

    final offline = await isOffline();
    if (offline) {
      debugPrint('AIRecognitionService: Edge Mode Active: On-Device ML running locally (Offline)');
    }

    final inputImage = InputImage.fromFilePath(image.path);
    final labels = await _imageLabeler!.processImage(inputImage);

    return labels.map((label) {
      return ProductRecognitionResult(
        label: label.label,
        confidence: label.confidence,
      );
    }).toList();
  }

  /// Extract text from image (OCR) - for batch numbers, MRP, expiry
  Future<OCRResult> extractText(XFile image) async {
    if (!_isInitialized) await initialize();

    final offline = await isOffline();
    if (offline) {
      debugPrint('AIRecognitionService: Edge Mode Active: On-Device ML running locally (Offline)');
    }

    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _textRecognizer!.processImage(inputImage);

    // Parse extracted text
    final String fullText = recognizedText.text;
    final List<TextLine> lines = [];
    for (TextBlock block in recognizedText.blocks) {
      lines.addAll(block.lines);
    }

    // Extract key information
    String? batchNumber;
    String? expiryDate;
    double? mrp;

    for (final line in lines) {
      final text = line.text.toUpperCase();

      // Batch number patterns
      if (text.contains('BATCH') || text.contains('LOT')) {
        final match = RegExp(r'[A-Z0-9]{5,12}').firstMatch(text);
        if (match != null) {
          batchNumber = match.group(0);
        }
      }

      // Expiry date patterns
      if (text.contains('EXP') ||
          text.contains('EXPIRY') ||
          text.contains('BEST BEFORE')) {
        final dateMatch = RegExp(
          r'(\d{2}[/-]\d{2}[/-]\d{2,4})|(\d{2}[/-]\d{4})|(\d{4}[/-]\d{2}[/-]\d{2})',
        ).firstMatch(text);
        if (dateMatch != null) {
          expiryDate = dateMatch.group(0);
        }
      }

      // MRP patterns
      if (text.contains('MRP')) {
        final mrpMatch = RegExp(r'₹?\s*(\d+\.?\d*)').firstMatch(text);
        if (mrpMatch != null) {
          mrp = double.tryParse(mrpMatch.group(1)!);
        }
      }
    }

    return OCRResult(
      fullText: fullText,
      lines: lines.map((e) => e.text).toList(),
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      mrp: mrp,
      isEdgeMode: offline,
    );
  }

  /// Dispose resources
  void dispose() {
    _imageLabeler?.close();
    _textRecognizer?.close();
    _isInitialized = false;
  }
}

class ProductRecognitionResult {
  final String label;
  final double confidence;

  ProductRecognitionResult({
    required this.label,
    required this.confidence,
  });
}

class OCRResult {
  final String fullText;
  final List<String> lines;
  final String? batchNumber;
  final String? expiryDate;
  final double? mrp;
  final bool isEdgeMode;

  OCRResult({
    required this.fullText,
    required this.lines,
    this.batchNumber,
    this.expiryDate,
    this.mrp,
    this.isEdgeMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullText': fullText,
      'lines': lines,
      'batchNumber': batchNumber,
      'expiryDate': expiryDate,
      'mrp': mrp,
      'isEdgeMode': isEdgeMode,
    };
  }
}
