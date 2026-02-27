import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tfliteServiceProvider = Provider((ref) => TFLiteService());

enum DetectionMode { plant, disease }

class TFLiteService {
  Interpreter? _plantInterpreter;
  Interpreter? _diseaseInterpreter;
  List<String>? _plantLabels;
  List<String>? _diseaseLabels;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      _plantInterpreter = await Interpreter.fromAsset(
        'assets/model/plant_model_quantized.tflite',
      );
      _diseaseInterpreter = await Interpreter.fromAsset(
        'assets/model/disease_model_quantized.tflite',
      );
      _plantLabels = await _loadLabels('assets/labels/plant_labels.txt');
      _diseaseLabels = await _loadLabels('assets/labels/disease_labels.txt');
      _isLoaded = true;

      _logTensorInfo('Plant', _plantInterpreter!);
      _logTensorInfo('Disease', _diseaseInterpreter!);
      print(
        'Labels: ${_plantLabels?.length} plants, ${_diseaseLabels?.length} diseases',
      );
    } catch (e) {
      print('Failed to load models: $e');
    }
  }

  void _logTensorInfo(String name, Interpreter interp) {
    final inT = interp.getInputTensor(0);
    final outT = interp.getOutputTensor(0);
    print(
      '$name model — input: shape=${inT.shape} type=${inT.type}, output: shape=${outT.shape} type=${outT.type}',
    );
  }

  Future<List<String>> _loadLabels(String path) async {
    try {
      final labelData = await rootBundle.loadString(path);
      return labelData.split('\n').where((l) => l.trim().isNotEmpty).toList();
    } catch (e) {
      print('Labels not found at $path');
      return [];
    }
  }

  /// Preprocess image for EfficientNetB0 — raw 0-255 float values (NO /255)
  Float32List _preprocessImage(String imagePath, Interpreter interpreter) {
    final imageFile = File(imagePath);
    final rawImage = img.decodeImage(imageFile.readAsBytesSync());
    if (rawImage == null) throw Exception('Could not decode image');

    final shape = interpreter.getInputTensor(0).shape;
    final w = shape[1];
    final h = shape[2];
    final resized = img.copyResize(rawImage, width: w, height: h);

    var input = Float32List(1 * w * h * 3);
    var idx = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = resized.getPixelSafe(x, y);
        input[idx++] = p.r.toDouble(); // raw 0-255
        input[idx++] = p.g.toDouble();
        input[idx++] = p.b.toDouble();
      }
    }
    return input;
  }

  Map<String, dynamic> _runSingleModel(
    Interpreter interpreter,
    List<String> labels,
    Float32List input,
  ) {
    final inShape = interpreter.getInputTensor(0).shape;
    final outShape = interpreter.getOutputTensor(0).shape;
    var output = List.filled(
      outShape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outShape);

    interpreter.run(input.reshape(inShape), output);

    final results = List<double>.from(output[0]);
    var maxConf = -1.0;
    var maxIdx = -1;
    for (var i = 0; i < results.length; i++) {
      if (results[i] > maxConf) {
        maxConf = results[i];
        maxIdx = i;
      }
    }

    final label = (maxIdx >= 0 && maxIdx < labels.length)
        ? labels[maxIdx]
        : 'Unknown';

    // Top 3 debug
    final indexed = results.asMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = indexed
        .take(3)
        .map((e) {
          final name = e.key < labels.length ? labels[e.key] : '${e.key}';
          return '$name(${(e.value * 100).toStringAsFixed(1)}%)';
        })
        .join(', ');
    print('Top 3: $top3');

    return {'label': label, 'confidence': maxConf};
  }

  /// Run ONLY the plant identification model
  Future<Map<String, dynamic>?> identifyPlant(String imagePath) async {
    if (!_isLoaded) return null;
    try {
      print('--- Running plant identification ---');
      final input = _preprocessImage(imagePath, _plantInterpreter!);
      final result = _runSingleModel(_plantInterpreter!, _plantLabels!, input);
      print(
        'Plant: ${result['label']} (${((result['confidence'] as double) * 100).toStringAsFixed(1)}%)',
      );
      return {
        'plant': result['label'],
        'confidence': result['confidence'],
        'isHealthy': true,
        'disease': null,
        'mode': 'plant',
      };
    } catch (e) {
      print('Plant identification failed: $e');
      return null;
    }
  }

  /// Run ONLY the disease detection model
  Future<Map<String, dynamic>?> detectDisease(String imagePath) async {
    if (!_isLoaded) return null;
    try {
      print('--- Running disease detection ---');
      final input = _preprocessImage(imagePath, _diseaseInterpreter!);
      final result = _runSingleModel(
        _diseaseInterpreter!,
        _diseaseLabels!,
        input,
      );
      print(
        'Disease: ${result['label']} (${((result['confidence'] as double) * 100).toStringAsFixed(1)}%)',
      );
      return {
        'plant': result['label'],
        'disease': result['label'],
        'confidence': result['confidence'],
        'isHealthy': false,
        'mode': 'disease',
      };
    } catch (e) {
      print('Disease detection failed: $e');
      return null;
    }
  }

  void close() {
    _plantInterpreter?.close();
    _diseaseInterpreter?.close();
  }
}
