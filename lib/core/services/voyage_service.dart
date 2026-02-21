import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VoyageService {
  final String _baseUrl = 'https://api.voyageai.com/v1/embeddings';

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${dotenv.env['VOYAGE_API_KEY']}',
    'content-type': 'application/json',
  };

  /// Generate embedding for any text. Returns a list of doubles.
  Future<List<double>> generateEmbedding(String text) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: _headers,
      body: jsonEncode({
        'model': 'voyage-3-lite', // smallest, fastest, free tier
        'input': text,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final embedding = data['data'][0]['embedding'] as List<dynamic>;
      return embedding.map((e) => (e as num).toDouble()).toList();
    } else {
      throw Exception(
        'Voyage API error: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Convert embedding list to bytes for SQLite BLOB storage.
  static Uint8List embeddingToBytes(List<double> embedding) {
    final buffer = ByteData(embedding.length * 8);
    for (int i = 0; i < embedding.length; i++) {
      buffer.setFloat64(i * 8, embedding[i]);
    }
    return buffer.buffer.asUint8List();
  }

  /// Convert bytes back to embedding list.
  static List<double> bytesToEmbedding(Uint8List bytes) {
    final buffer = ByteData.sublistView(bytes);
    return List.generate(bytes.length ~/ 8, (i) => buffer.getFloat64(i * 8));
  }
}
