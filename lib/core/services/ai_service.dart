import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AI Service — currently powered by Groq (Llama 3.3 70B, free tier).
/// To switch to Claude later, only change _baseUrl, _headers, and _generate().
/// All prompts, methods, providers, and UI stay the same.
class AIService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  String get _apiKey => dotenv.env['GROQ_API_KEY']!;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  /// Core generation method — the ONLY thing that changes when swapping APIs.
  Future<String> _generate(String systemPrompt, String userMessage) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: _headers,
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.7,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception(
        'Groq API error: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Streaming generation — yields tokens as they arrive from Groq SSE.
  Stream<String> _generateStream(
    String systemPrompt,
    String userMessage,
  ) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll(_headers);
    request.body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
      'temperature': 0.7,
      'max_tokens': 1024,
      'stream': true,
    });

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Groq API error: ${response.statusCode} $body');
    }

    // Parse SSE stream
    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast(); // keep incomplete line in buffer

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6);
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data);
          final delta = json['choices']?[0]?['delta']?['content'] as String?;
          if (delta != null && delta.isNotEmpty) {
            yield delta;
          }
        } catch (_) {
          // Skip malformed JSON chunks
        }
      }
    }
  }

  // ─── STREAMING CONVERSATION (for voice mode) ───────────────────────────────

  /// Stream a conversational AI response token-by-token.
  /// Used in voice mode so TTS can start speaking mid-response.
  Stream<String> respondToUserStream(
    String rawText, {
    required List<Map<String, String>> relevantEntries,
    String? imageDescription,
  }) {
    final contextInfo = relevantEntries.isNotEmpty
        ? relevantEntries
              .map(
                (e) =>
                    'Date: ${e['date']}\nSummary: ${e['summary']}\nThemes: ${e['themes']}\nEmotions: ${e['emotions']}',
              )
              .join('\n\n---\n\n')
        : 'No relevant past entries found.';

    final imageContext = imageDescription != null && imageDescription.isNotEmpty
        ? '\n\nThe user also attached an image: $imageDescription'
        : '';

    return _generateStream(
      '''
You are Emori, a warm, caring AI best friend — not a therapist, not an assistant.
Someone is talking to you live via voice. Respond like a real friend would in a voice conversation:
- Be concise and natural — this will be spoken aloud
- Keep sentences short and conversational
- Show genuine warmth and understanding
- Ask one follow-up question to keep the conversation going
- No bullet points, no markdown, no emojis — this is a spoken conversation
- 2-4 sentences max. Keep it brief like a real conversation.
''',
      '''
Here is context from their past entries:
$contextInfo

They just said:
"$rawText"$imageContext

Respond naturally as their caring friend.
''',
    );
  }

  // ─── 1. SUMMARIZE & TAG ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> analyzeEntry(
    String rawText, {
    String? imageDescription,
  }) async {
    final imageContext = imageDescription != null && imageDescription.isNotEmpty
        ? '\n\nThe user also attached an image: $imageDescription'
        : '';

    final result = await _generate(
      'You are a deeply empathetic personal journal assistant. Always respond with valid JSON only. No markdown, no extra text.',
      '''
Analyze this journal entry and return ONLY a valid JSON object.

Entry: "$rawText$imageContext"

Return exactly this structure:
{
  "summary": "2-3 sentence summary capturing the core meaning and emotion. Address the user directly using 'you' and 'your' (e.g., 'You felt anxious today...'). NEVER use 'the writer', 'they', or third person.",
  "emotions": ["emotion1", "emotion2"],
  "life_area": "one of: career, relationships, health, money, identity, growth, other",
  "type": "one of: lesson, feeling, idea, goal, mistake, gratitude, observation",
  "themes": ["theme1", "theme2", "theme3"],
  "people": ["first names of people mentioned, empty if none"]
}
''',
    );

    final cleaned = result
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // Extract JSON using regex in case Groq adds conversational padding
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleaned);
    if (jsonMatch != null) {
      return jsonDecode(jsonMatch.group(0)!);
    }

    return jsonDecode(cleaned);
  }

  // ─── 1b. CONVERSATIONAL FOLLOW-UP ──────────────────────────────────────────

  Future<String> respondToCapture(
    String rawText, {
    String? imageDescription,
    bool hasImages = false,
  }) async {
    final imageContext = hasImages && imageDescription != null
        ? '\nThey also shared a photo: $imageDescription'
        : hasImages
        ? '\nThey also shared a photo with this entry.'
        : '';

    return await _generate(
      '''
You are Emori, a warm, caring AI best friend — not a therapist, not an assistant.
Someone just shared something personal with you. Respond like a real friend would:
- Acknowledge what they shared with genuine warmth
- Show you understand the emotion behind it
- Ask 1-2 thoughtful follow-up questions to understand more
- Be curious, not clinical. Be human, not robotic.
- Keep it short — 2-3 sentences max, like a text from a close friend
- Use casual, warm language. Emoji sparingly (1 max).
- Never say "I'm here for you" or "that must be hard" — those are generic. Be specific.
''',
      '''
The person just shared this with you:
"$rawText"$imageContext

Respond warmly and ask a follow-up question to understand more.
''',
    );
  }

  // ─── 2. ANSWER FROM MEMORY ─────────────────────────────────────────────────

  Future<String> answerFromMemory({
    required String userQuestion,
    required List<Map<String, String>> relevantEntries,
  }) async {
    final context = relevantEntries
        .map(
          (e) =>
              'Date: ${e['date']}\nEntry: ${e['summary']}\nThemes: ${e['themes']}\nEmotions: ${e['emotions']}',
        )
        .join('\n\n---\n\n');

    return await _generate(
      '''
You are Emori, a deeply personal AI companion and memory keeper.
You speak like a warm, honest, wise best friend — not like a therapist or assistant.
You only answer based on the journal entries provided. Never make things up.
If entries don't have enough information, say so honestly.
Speak directly and personally. Use "you" naturally.
Keep responses short, conversational, and easy to read. 
Use bullet points occasionally to break down thoughts, but keep them brief.
NEVER write long, thick paragraphs. Speak slowly, build trust, and act like a real, caring friend texting them.
''',
      '''
Here are my journal entries relevant to the question:

$context

My question: $userQuestion
''',
    );
  }

  // ─── 2b. UNIFIED INTERACTION ROUTER ────────────────────────────────────────

  Future<Map<String, dynamic>> processUnifiedInteraction(
    String rawText, {
    String? imageDescription,
    required List<Map<String, String>> relevantEntries,
  }) async {
    final imageContext = imageDescription != null && imageDescription.isNotEmpty
        ? '\n\nThe user also attached an image: $imageDescription'
        : '';

    final contextInfo = relevantEntries.isNotEmpty
        ? relevantEntries
              .map(
                (e) =>
                    'Date: ${e['date']}\nSummary: ${e['summary']}\nThemes: ${e['themes']}\nEmotions: ${e['emotions']}',
              )
              .join('\n\n---\n\n')
        : 'No relevant past entries found.';

    final now = DateTime.now();
    final currentDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final weekday = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][now.weekday - 1];

    final result = await _generate(
      '''
You are Emori, a warm, intelligent AI companion that serves as both a memory keeper and a knowing friend.
You receive messages from the user. Your job is to determine their intent and respond appropriately.

IMPORTANT CONTEXT:
- Today's date: $currentDate ($weekday)
- Current time: $currentTime
- Current year: ${now.year}

There are two possible intents:
1. NEW MEMORY (is_new_memory: true): The user is sharing ANYTHING about their day, life, feelings, events (like "playing cricket"), random thoughts, or observations. EVEN CASUAL OR BRIEF UPDATES must be saved as a new memory. If they are telling you something they did or felt, it is a NEW MEMORY.
2. QUESTION (is_new_memory: false): The user is explicitly asking you a question about their past, their patterns, or seeking your advice/opinion ON past context, WITHOUT sharing new events or feelings.

ALWAYS respond with valid JSON ONLY. No markdown, no extra text.

IMPORTANT: If the user mentions ANY future event, important date, deadline, meeting, appointment (e.g., dentist, doctor), birthday, exam, assignment, or asks you to remind them about anything, you MUST extract it as a reminder. Even if `is_new_memory` is false, you must populate the `reminders` array if they mention an event.

CRITICAL REMINDER RULES:
- Convert relative dates like "tomorrow", "next Monday", "in 3 days", "28th February" into exact ISO format using today's date ($currentDate) and time ($currentTime) as reference.
- If the user specifies a time (e.g., "at 2:30 PM", "in 10 minutes", "at night"), you MUST include that exact time in the due_date. 
- If no time is specified, default to 09:00:00.
- MUST use exact format: YYYY-MM-DD HH:MM:SS

Return exactly this JSON structure:
{
  "is_new_memory": true or false,
  "response_to_user": "Your response to the user. Write this like a caring friend. Keep it short (2-3 sentences max). If it's a new memory, acknowledge it warmly and ALWAYS ask 1-2 thoughtful follow-up questions to understand them better. If it's a question, answer it directly and honestly based ONLY on the provided past context. If there's a deadline/event, acknowledge it and reassure them you'll remember and remind them.",
  
  // If and ONLY if is_new_memory is true, provide these fields:
  "summary": "2-3 sentence summary of what they shared. Address them as 'you'/'your'. NO third person.",
  "emotions": ["emotion1", "emotion2"],
  "life_area": "one of: career, relationships, health, money, identity, growth, other",
  "type": "one of: lesson, feeling, idea, goal, mistake, gratitude, observation",
  "themes": ["theme1", "theme2", "theme3"],
  "people": ["first names of people mentioned, empty if none"],
  
  // ALWAYS include this field. Empty array if no dates/events detected.
  "reminders": [
    {
      "title": "Short title for the reminder (e.g. 'Assignment deadline', 'Call Raj')",
      "description": "Brief description with context",
      "due_date": "YYYY-MM-DD HH:MM:SS format. MUST include time. Extract exact time if specified, else default to 09:00:00."
    }
  ]
}
''',
      '''
Here is context from their past entries related to their message:
$contextInfo

And here is the new message they just sent:
"$rawText"$imageContext

Process this message and return exactly the required JSON.
''',
    );

    final cleaned = result
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // Extract JSON using regex in case Groq adds conversational padding
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleaned);
    if (jsonMatch != null) {
      return jsonDecode(jsonMatch.group(0)!);
    }

    return jsonDecode(cleaned);
  }

  // ─── 3. DETECT PATTERNS ────────────────────────────────────────────────────

  Future<String> detectPatterns(List<String> summaries) async {
    final context = summaries
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    return await _generate(
      '''
You are Emori, a warm and honest AI best friend.
You notice patterns in someone's life that they themselves might not see.
Speak warmly and directly. Be honest but kind.
Never be clinical or listy. Write like you are talking to a close friend.
''',
      '''
Here are my journal entries from the last 30 days:

$context

What patterns do you notice in my thoughts, emotions, and behaviors?
What am I not seeing about myself?
''',
    );
  }

  // ─── 4. WEEKLY REFLECTION ──────────────────────────────────────────────────

  Future<String> generateWeeklyReflection(List<String> summaries) async {
    final context = summaries
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    return await _generate(
      '''
You are Emori, a deeply caring AI best friend who has been listening all week.
Write a warm, personal weekly reflection like a letter from a best friend
who truly paid attention to everything shared this week.

IMPORTANT FORMATTING RULES:
- Use bullet points to highlight key points, patterns, and insights from the week.
- Keep the structure clean and very easy to read.

Notice what was hard, what was beautiful, what changed, what stayed the same.
End with one gentle, honest insight they might carry into next week.
Never be generic. Every word should feel like it was written only for them.
''',
      '''
Here is what I shared with you this week:

$context

Write my weekly reflection.
''',
    );
  }
}
