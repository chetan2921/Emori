# Emori — Your AI-Powered Emotional Second Brain

<p align="center">
  <strong>Talk to an AI that truly knows you.</strong><br/>
  Emori remembers every thought, emotion, and experience you share — and helps you understand yourself better over time.
</p>

---

## What is Emori?

Emori is a **personal AI companion** that acts as your **emotional second brain**. Unlike generic chatbots, Emori builds a deep, searchable memory of everything you share — your thoughts, feelings, experiences, and reflections. Over time, it becomes the one friend who truly _remembers_.

**Talk or type naturally** → Emori listens, understands the emotion behind your words, and saves structured journal entries automatically. Later, ask it anything — _"What have I been stressed about?"_, _"How was I feeling last month?"_, _"What patterns do you see in me?"_ — and it answers from your own history.

---

## Core Features

### 🧠 AI Second Brain

- Every conversation becomes a **searchable memory** with emotions, themes, life areas, and people automatically tagged
- AI uses **semantic search** (vector embeddings) to find relevant past entries when you ask questions
- Your personal knowledge base grows smarter with every interaction

### 💬 Natural Conversation

- Talk to Emori like a **caring best friend**, not a clinical tool
- **Voice mode** with real-time streaming: speak → AI responds sentence-by-sentence via TTS
- Auto-detects intent: sharing a memory vs. asking a question — no mode switching needed

### 📊 Emotional Pattern Detection

- Visual charts showing your **emotion frequency** over the past 30 days
- AI-powered analysis that spots **patterns you don't see** in yourself
- Highlights recurring emotions, themes, and behavioral cycles

### 📝 Weekly Reflections

- AI writes a **personalized weekly letter** based on everything you shared that week
- Notices what was hard, what was beautiful, what changed
- Ends with one gentle, honest insight to carry into the next week

### 🔒 Privacy-First

- All data stored **locally on your device** (SQLite)
- Encrypted storage for sensitive content
- No social features, no data selling — your thoughts stay yours

---

## Tech Stack

| Layer                | Technology                                           |
| -------------------- | ---------------------------------------------------- |
| **Framework**        | Flutter (Dart) — cross-platform mobile               |
| **State Management** | Riverpod                                             |
| **AI / LLM**         | Groq API (Llama 3.3 70B) with SSE streaming          |
| **Embeddings**       | Voyage AI (semantic search)                          |
| **Local Database**   | SQLite via sqflite                                   |
| **Auth**             | Supabase (email/password + Google Sign-In)           |
| **Voice**            | speech_to_text + flutter_tts (sentence-chunked)      |
| **Image Analysis**   | Image description pipeline for photo journal entries |

---

## How Is Emori Different?

There are several apps in this space. Here's how Emori compares:

| App              |      Voice       | AI Memory / Second Brain  | Pattern Detection |     Free LLM      | Open Source |
| ---------------- | :--------------: | :-----------------------: | :---------------: | :---------------: | :---------: |
| **Emori**        | ✅ Streaming TTS | ✅ Semantic vector search |  ✅ Charts + AI   | ✅ Groq free tier |     ✅      |
| Rosebud          |        ✅        |        ⚠️ Limited         |        ❌         |      ❌ Paid      |     ❌      |
| Reflection       |   ⚠️ STT only    |            ✅             |     ⚠️ Basic      |      ❌ Paid      |     ❌      |
| Honestly         |        ✅        |            ❌             |  ⚠️ Weekly only   |      ❌ Paid      |     ❌      |
| Voice Journal AI |        ✅        |            ❌             |   ⚠️ Mood score   |     ❌ GPT-4      |     ❌      |
| ABY Journal      |        ❌        |       ⚠️ On-device        |        ✅         |      ❌ Paid      |     ❌      |

**Emori's unique combination:**

1. **True second brain** — vector embedding search across all entries, not just keyword matching
2. **Streaming voice** — sentence-by-sentence TTS for conversational feel (not batch)
3. **Unified AI** — one conversation interface that auto-detects if you're sharing or asking
4. **Free AI tier** — runs on Groq's free Llama 3.3 70B, no subscription needed
5. **Open source** — fully customizable and self-hostable

---

## Getting Started

### Prerequisites

- Flutter SDK (^3.10.8)
- A [Groq](https://console.groq.com) API key (free)
- A [Voyage AI](https://www.voyageai.com) API key (free tier)
- A [Supabase](https://supabase.com) project (free tier) — for auth

### Setup

```bash
# Clone the repo
git clone https://github.com/your-username/emori.git
cd emori

# Install dependencies
flutter pub get

# Configure environment
cp .env.example .env
# Edit .env with your API keys:
#   GROQ_API_KEY=your_key
#   VOYAGE_API_KEY=your_key
#   SUPABASE_URL=your_project_url
#   SUPABASE_ANON_KEY=your_anon_key

# Run on device/emulator
flutter run
```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point + Supabase init
├── core/
│   ├── database/                      # SQLite database + DAOs
│   ├── models/                        # Entry, ChatMessage models
│   ├── providers/                     # Riverpod providers (chat, auth, entries)
│   ├── router/                        # App flow: onboarding → login → home
│   ├── services/                      # AI, TTS, auth, embedding, image services
│   └── theme/                         # App-wide theme (colors, typography)
└── features/
    ├── auth/                          # Login / register screen
    ├── chat/                          # Main chat interface
    ├── history/                       # Past journal entries
    ├── insights/                      # Pattern detection + weekly reflections
    └── onboarding/                    # 3-slide intro screen
```

---

## License

MIT

---

<p align="center">
  Built with 💜 by Chetan Jain
</p>
