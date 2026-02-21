import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Pick from gallery
  Future<File?> pickFromGallery() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile == null) return null;
    return await _saveToAppDirectory(File(xfile.path));
  }

  /// Take a photo
  Future<File?> takePhoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (xfile == null) return null;
    return await _saveToAppDirectory(File(xfile.path));
  }

  /// Save image permanently in app's documents directory (compressed)
  Future<File> _saveToAppDirectory(File image) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/emori_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final id = const Uuid().v4();
    final destPath = '${imagesDir.path}/$id.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      image.path,
      destPath,
      quality: 75,
      minWidth: 1024,
      minHeight: 1024,
    );

    return File(compressed?.path ?? image.path);
  }

  /// Send image to Groq Vision and get description
  Future<String> describeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final apiKey = dotenv.env['GROQ_API_KEY'];

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.2-11b-vision-preview',
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
              {
                'type': 'text',
                'text': '''
You are helping a personal journal app understand an image someone shared.
Describe what you see in 2-3 sentences focusing on:
- What is happening or what this image captures
- The mood, atmosphere or emotion it conveys
- Any context that would help understand why someone might have saved this

Be warm and personal in tone, not clinical. Write as if describing a memory.
''',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      // If vision fails, return empty — entry still saves
      return '';
    }
  }

  /// Delete image from device
  Future<void> deleteImage(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
