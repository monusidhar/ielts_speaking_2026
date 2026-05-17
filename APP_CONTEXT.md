# IELTS Speaking 2026 — Full App Context

> **Use this file** to give any AI assistant full context about this project.
> Last updated: 16 May 2026

---

## 1. Overview

| Field | Value |
|-------|-------|
| **App Name** | IELTS Speaking 2026 |
| **Package** | `com.monusidhar.ielts_speaking_2026` |
| **Framework** | Flutter (Dart) |
| **SDK** | `>=3.3.3 <4.0.0` |
| **Version** | `1.0.0+12` |
| **Status** | **LIVE on Google Play** |
| **Monetisation** | AdMob (banner + interstitial + rewarded) + ₹199 lifetime in-app purchase |
| **AI Backend** | Groq API (Llama 3.3 70B) |
| **Target SDK** | 36 |
| **Compile SDK** | 36 |
| **Min SDK** | Flutter default (from `flutter.minSdkVersion`) |
| **Multi-dex** | Enabled |

---

## 2. Project Structure

```
lib/
├── main.dart                          # App root, themes, routes, init
├── data/
│   ├── app_secrets.dart               # API keys (gitignored)
│   ├── app_secrets.dart.example       # Template for secrets
│   ├── models/
│   │   └── mock_interview_models.dart # MockInterviewQuestions, MockQATranscript, MockInterviewResult
│   ├── repositories/
│   │   ├── prefs_repository.dart      # SharedPreferences wrapper
│   │   ├── cue_card_repository.dart   # Loads/serves cue card data
│   │   └── practice_history_repository.dart  # AI practice session history
│   └── services/
│       ├── ad_service.dart            # AdMob banner/interstitial/rewarded
│       ├── ai_service.dart            # Groq API for AI feedback (cue card practice)
│       ├── mock_interview_service.dart # Groq API for mock interview (question gen + evaluation)
│       ├── billing_service.dart       # Google Play in-app purchase
│       ├── update_service.dart        # Remote forced-update check
│       ├── notification_service.dart  # Local push notifications (streak reminders)
│       ├── share_service.dart         # Share band scores to social media
│       └── review_service.dart        # In-app review prompt (Play Store rating)
├── screens/
│   ├── splash/splash_screen.dart      # Animated splash → /home
│   ├── home/home_screen.dart          # Dashboard with stats, daily tip, nav grid
│   ├── cue_cards/
│   │   ├── cue_cards_list_screen.dart # Searchable/filterable card list
│   │   └── cue_card_detail_screen.dart# Tabs: prompts, band-8 answer, vocab, tips
│   ├── random_practice/random_practice_screen.dart  # Timed random card practice
│   ├── bookmarks/bookmark_screen.dart # Bookmarked cards list
│   ├── vocabulary/vocabulary_screen.dart # Paginated vocabulary browser
│   ├── practice/
│   │   ├── ai_practice_screen.dart    # Speech-to-text → AI evaluation (cue card)
│   │   ├── ai_feedback_screen.dart    # Band score breakdown + feedback
│   │   └── practice_history_screen.dart # Band progress chart + session list
│   ├── mock_interview/
│   │   ├── mock_interview_intro_screen.dart  # Format explainer + credit check
│   │   ├── mock_interview_screen.dart       # Full interview flow (Part 1→2→3)
│   │   └── mock_interview_result_screen.dart # Band scores + per-part feedback + premium upsell
│   ├── daily_question/
│   │   └── daily_question_practice_screen.dart # Daily AI question practice (speak → AI score)
│   ├── premium/premium_screen.dart    # Purchase/restore premium
│   ├── privacy/privacy_screen.dart    # Privacy policy
│   └── about/about_screen.dart        # Version, contact, Play Store link
└── widgets/
    └── banner_ad_widget.dart          # Reusable banner ad (hidden for premium)

assets/
├── data/cue_cards.json                # 50 cue cards with vocab & tips
└── images/                            # App images
```

---

## 3. Named Routes

| Route Constant | Path | Screen | Args |
|---------------|------|--------|------|
| `AppRoutes.splash` | `/` | `SplashScreen` | — |
| `AppRoutes.home` | `/home` | `HomeScreen` | — |
| `AppRoutes.cueCardsList` | `/cue-cards` | `CueCardsListScreen` | — |
| `AppRoutes.cueCardDetail` | `/cue-card-detail` | `CueCardDetailScreen` | `{'cardId': int}` |
| `AppRoutes.randomPractice` | `/random-practice` | `RandomPracticeScreen` | — |
| `AppRoutes.bookmarks` | `/bookmarks` | `BookmarkScreen` | — |
| `AppRoutes.vocabulary` | `/vocabulary` | `VocabularyScreen` | — |
| `AppRoutes.premium` | `/premium` | `PremiumScreen` | — |
| `AppRoutes.privacy` | `/privacy` | `PrivacyScreen` | — |
| `AppRoutes.about` | `/about` | `AboutScreen` | — |
| `AppRoutes.aiPractice` | `/ai-practice` | `AiPracticeScreen` | — |
| `AppRoutes.aiFeedback` | `/ai-feedback` | `AiFeedbackScreen` | `{'feedback': AiFeedback, 'card': CueCard, 'transcript': String}` |
| `AppRoutes.practiceHistory` | `/practice-history` | `PracticeHistoryScreen` | — |
| `AppRoutes.mockInterviewIntro` | `/mock-interview-intro` | `MockInterviewIntroScreen` | — |
| `AppRoutes.mockInterview` | `/mock-interview` | `MockInterviewScreen` | — |
| `AppRoutes.mockInterviewResult` | `/mock-interview-result` | `MockInterviewResultScreen` | `{'result': MockInterviewResult, 'card': CueCard}` |
| `AppRoutes.dailyQuestionPractice` | `/daily-question-practice` | `DailyQuestionPracticeScreen` | `{'question': String, 'partType': String}` |

Routes are defined in `main.dart`. Simple routes use `routes:` map; `cueCardDetail`, `aiFeedback`, `mockInterviewResult`, and `dailyQuestionPractice` use `onGenerateRoute`.

---

## 4. Data Models

### CueCard (`cue_card_repository.dart`)
```dart
class CueCard {
  int id;
  String topic;
  String category;
  List<String> prompts;
  String bandAnswer;
  List<VocabWord> vocabulary;
  List<String> tips;
}
```

### VocabWord (`cue_card_repository.dart`)
```dart
class VocabWord {
  String word;
  String partOfSpeech;
  String meaning;
  String example;
}
```

### PracticeSession (`practice_history_repository.dart`)
```dart
class PracticeSession {
  int cardId;
  String topic;
  String category;
  double overallBand;
  double fluencyBand;
  double lexicalBand;
  double grammarBand;
  double pronunciationBand;
  String transcript;
  int durationSecs;
  DateTime dateTime;
}
```

### AiFeedback (`ai_service.dart`)
```dart
class AiFeedback {
  double overallBand;
  double fluencyBand;
  double lexicalBand;
  double grammarBand;
  double pronunciationBand;
  String overallComment;
  List<String> strengths;
  List<String> improvements;
  List<String> suggestedVocabulary;
  String improvedAnswer;
  List<String> pronunciationFlags;  // NEW: words flagged for pronunciation practice
}
```

### MockInterviewQuestions (`mock_interview_models.dart`)
```dart
class MockInterviewQuestions {
  List<MockPart1Topic> part1Topics;  // 2 topics × 3 questions
  List<String> part3Questions;       // 4 discussion questions
}

class MockPart1Topic {
  String topic;
  List<String> questions;
}
```

### MockQATranscript (`mock_interview_models.dart`)
```dart
class MockQATranscript {
  String question;
  String transcript;
  int durationSecs;
}
```

### MockInterviewResult (`mock_interview_models.dart`)
```dart
class MockInterviewResult {
  double overallBand;
  double fluencyBand, lexicalBand, grammarBand, pronunciationBand;
  double part1Band, part2Band, part3Band;
  String overallComment, part1Feedback, part2Feedback, part3Feedback;
  List<String> strengths, improvements, suggestedVocabulary;
  String improvedPart2Answer;
}
```

---

## 5. JSON Data Format (`assets/data/cue_cards.json`)

```json
{
  "version": "1.0.0",
  "total": 50,
  "cards": [
    {
      "id": 1,
      "topic": "Describe a place you visited recently",
      "category": "Travel",
      "prompts": ["Where the place is", "When you visited it", ...],
      "band_answer": "I'd like to talk about...",
      "vocabulary": [
        {
          "word": "Breathtaking",
          "part_of_speech": "adjective",
          "meaning": "Astonishing or awe-inspiring",
          "example": "The view was absolutely breathtaking."
        }
      ],
      "tips": ["Use vivid sensory details", ...]
    }
  ]
}
```

**Categories present:** Travel, Technology, People, Education, Health, Environment, Leisure, Work, Food, Culture (may vary).

---

## 6. SharedPreferences Keys (`prefs_repository.dart`)

| Key | Type | Purpose |
|-----|------|---------|
| `bookmarked_card_ids` | `List<String>` | IDs of bookmarked cards |
| `practiced_card_ids` | `List<String>` | IDs of cards user has practiced |
| `practiced_total_count` | `int` | Total practice count (all sessions) |
| `is_premium` | `bool` | Premium purchase status |
| `is_dark_mode` | `bool` | Dark mode toggle |
| `ai_daily_count` | `int` | AI cue card practice uses today |
| `ai_daily_date` | `String` | Date of last AI count reset |
| `ai_practice_history` | `String` (JSON) | Serialised list of `PracticeSession` |
| `mock_free_completed` | `bool` | Whether free user has used their 1 lifetime mock trial |
| `mock_daily_count` | `int` | Mock interviews done today (premium counter) |
| `mock_daily_date` | `String` | Date of last mock count reset |
| `daily_question_text` | `String` | Cached daily AI question text |
| `daily_question_part` | `String` | Part type of daily question ("Part 1" or "Part 3") |
| `daily_question_date` | `String` | Date of cached daily question |
| `streak_count` | `int` | Current daily streak count |
| `streak_last_date` | `String` | Date of last practice (streak tracking) |
| `target_band` | `double` | User's target band score (e.g. 7.0) |
| `exam_date` | `String` | User's exam date (yyyy-MM-dd) |
| `review_prompted` | `bool` | Whether in-app review has been shown |
| `total_ai_sessions` | `int` | Lifetime AI session count (for review trigger) |
| `notifications_enabled` | `bool` | Whether daily reminders are on (default: true) |

---

## 7. Premium vs Free Logic

| Feature | Free | Premium |
|---------|------|---------|
| Cue cards | First 50 (`id <= 50`) | All cards |
| Vocabulary | From first 50 cards only | All vocabulary |
| Random practice | Random from first 50 | Random from all |
| AI Speaking Coach (cue card) | 5 uses/day | 15 uses/day |
| **Full Mock Interview** | **1 lifetime trial** | **5/day** |
| **Daily AI Question** | **View question + practice (uses AI daily quota)** | **Same** |
| Ads | Banner + interstitial + rewarded | No ads |
| Bookmarks | Unlimited | Unlimited |
| Practice history | Available | Available |

**Free card limit constant:** `kFreeCardLimit = 50` in `cue_card_repository.dart`.

**Purchase product ID:** `remove_ads_lifetime` (one-time, Google Play Billing).

---

## 8. Ad Placements (`ad_service.dart`)

| Ad Type | Where | Trigger |
|---------|-------|---------|
| **Banner** | Bottom of cue card list, cue card detail, mock interview intro, mock interview result, daily question practice | Always visible (free users) |
| **Interstitial** | After random practice | Every 3 practices (`_interstitialFrequency = 3`) |
| **Rewarded/Video** | After AI cue card practice, after mock interview completes (before results), after daily question practice | After completing AI evaluation |

All ads auto-hidden when `isPremium == true`. Uses `google_mobile_ads` + `gma_mediation_unity`.

---

## 9. AI Services

### AiService (`ai_service.dart`) — Cue Card Practice
- **API:** Groq (`https://api.groq.com/openai/v1/chat/completions`)
- **Model:** Llama 3.3 70B Versatile
- **Input:** User transcript, cue card topic + prompts + sample answer, speaking duration
- **Output:** `AiFeedback` object with band scores, comment, strengths, improvements, suggested vocab, improved answer
- **Rate limiting:** 5 free / 15 premium per day
- **Methods:**
  - `AiService.evaluateAnswer()` — evaluates cue card Part 2 answer
  - `AiService.evaluateDailyAnswer()` — evaluates Part 1/3 daily question answer (different prompt tuned for short answers)
  - `AiService.generateDailyQuestion()` — generates a fresh Part 1 or Part 3 question per day (cached in SharedPreferences)
- **Pronunciation Flags:** Both evaluation methods now return `pronunciation_flags` — a list of 2-8 words from the transcript that are commonly mispronounced
- **Check:** `AiService.isConfigured` → false if API key is empty

### MockInterviewService (`mock_interview_service.dart`) — Full Mock Interview
- **Same API/Model** as AiService (Groq, Llama 3.3 70B)
- **2 API calls per interview:**
  1. `generateQuestions()` — generates Part 1 questions (2 topics × 3 Qs) + Part 3 questions (4 Qs) based on cue card topic
  2. `evaluateInterview()` — evaluates all transcripts across all 3 parts → `MockInterviewResult`
- **Rate limiting:** 1 lifetime free trial / 5 per day premium
- **Check:** `MockInterviewService.isConfigured` → false if API key is empty

---

## 10. Services

### BillingService (`billing_service.dart`)
- Uses `in_app_purchase` package
- Product: `remove_ads_lifetime`
- On purchase: sets `is_premium = true` in SharedPreferences
- Methods: `init()`, `buyPremium()`, `restorePurchases()`, `dispose()`

### UpdateService (`update_service.dart`)
- Remote config URL: `https://monusidhar.github.io/ielts-speaking-update.json`
- Checks remote JSON for forced update
- Methods: `checkForUpdate()`, `_shouldForceUpdate()`, `_compareVersions()`

### AdService (`ad_service.dart`)
- AdMob IDs: from `AppSecrets` (real) or test IDs (debug)
- Methods: `init()`, `createBanner()`, `showInterstitialAfterPractice()`, `showInterstitial()`, `showVideoAdAfterAiPractice()`

### NotificationService (`notification_service.dart`)
- Uses `flutter_local_notifications` for daily practice reminders
- Scheduled daily via `periodicallyShow()` (no exact-time permission needed)
- Content adapts to streak: "Don't lose your 5-day streak!" or "Time to practice!"
- Methods: `init()`, `requestPermission()`, `scheduleDailyReminder()`, `cancelAll()`, `setEnabled()`, `onPracticeCompleted()`
- Called from `main()` on app launch, and after each practice session

### ShareService (`share_service.dart`)
- Uses `share_plus` (already in deps)
- Generates formatted text with band scores + Play Store download link
- Methods: `shareBandScore()`, `shareMockResult()`, `shareDailyScore()`
- Share buttons on: AI feedback screen (app bar), mock interview results (header), daily question results

### ReviewService (`review_service.dart`)
- Uses `in_app_review` package for native Play Store/App Store review dialog
- Triggers once: after 3+ AI sessions AND band >= 6.0
- Tracked via `review_prompted` and `total_ai_sessions` in SharedPreferences
- Methods: `maybeRequestReview(double bandScore)`
- Called automatically after AI/mock/daily evaluations complete

---

## 11. Theme & Colors

### AppColors (`main.dart`)
```dart
primaryBlue:      0xFF1565C0    // Light mode primary
primaryBlueDark:  0xFF4DB6FF    // Dark mode primary
accentBlue:       0xFF0288D1
accentGold:       0xFFFFB300
bgLight:          0xFFF5F7FA
bgDark:           0xFF0F1B2D
cardLight:        0xFFFFFFFF
cardDark:         0xFF1A2E4A
textPrimaryLight: 0xFF1A1A2E
textPrimaryDark:  0xFFE8EAF0
success:          0xFF2E7D32
warning:          0xFFF57F17
error:            0xFFC62828
band7:            0xFF1976D2
band8:            0xFF6A1B9A
```

- Material 3 enabled
- Light/dark themes fully defined in `main.dart`
- Toggle via `IELTSSpeakingApp.toggleTheme(bool)` → saves to `PrefsRepository`

---

## 12. Dependencies (`pubspec.yaml`)

| Package | Version | Purpose |
|---------|---------|---------|
| `shared_preferences` | ^2.2.2 | Local key-value storage |
| `google_mobile_ads` | ^8.0.0 | AdMob ads |
| `gma_mediation_unity` | 1.7.0 | Unity mediation for AdMob |
| `in_app_purchase` | ^3.2.0 | Google Play billing |
| `speech_to_text` | ^7.0.0 | Microphone → text |
| `fl_chart` | ^0.70.2 | Band score progress charts |
| `in_app_update` | ^4.2.3 | Google Play in-app update |
| `url_launcher` | ^6.3.0 | Open URLs (Play Store, email) |
| `share_plus` | ^13.0.0 | Share app/scores with friends |
| `package_info_plus` | ^10.0.0 | App version info |
| `in_app_review` | ^2.0.10 | Play Store in-app review prompt |
| `flutter_local_notifications` | ^18.0.1 | Local push notifications (streak reminders) |

---

## 13. Android Build Config

| Setting | Value |
|---------|-------|
| `applicationId` | `com.monusidhar.ielts_speaking_2026` |
| `compileSdkVersion` | 36 |
| `targetSdkVersion` | 36 |
| `minSdkVersion` | `flutter.minSdkVersion` |
| `multiDexEnabled` | true |
| `minifyEnabled` | true (release) |
| `shrinkResources` | true (release) |
| ProGuard | `proguard-rules.pro` |
| Signing | Loaded from `key.properties` |
| NDK | `28.2.13676358` |

---

## 14. Key Architecture Patterns

1. **No state management library** — uses `StatefulWidget` + `setState` + static singletons
2. **Repository pattern** — `PrefsRepository`, `CueCardRepository`, `PracticeHistoryRepository` centralise data access
3. **Service layer** — `AdService`, `AiService`, `BillingService`, `UpdateService` are static utility classes
4. **Route observer** — `homeRouteObserver` (RouteAware) refreshes Home stats when navigating back
5. **Theme switching** — global static method `IELTSSpeakingApp.toggleTheme(bool)` with SharedPreferences persistence
6. **JSON-driven content** — all cue cards loaded from bundled `cue_cards.json` asset
7. **Secrets management** — `app_secrets.dart` (gitignored), template provided as `.example`

---

## 15. Contact & Links

| Item | Value |
|------|-------|
| **Developer** | Monu Sidhar |
| **Contact Email** | In `AppSecrets.contactEmail` |
| **Play Store** | URL in `about_screen.dart` (`_playStoreUrl`) |
| **Update Config** | `https://monusidhar.github.io/ielts-speaking-update.json` |

---

## 16. Important Notes for Development

- **App is LIVE** — never break existing functionality
- **Free card limit** = 50 — changing `kFreeCardLimit` affects premium gating everywhere
- **AI cue card daily limit** — 5 (free) / 15 (premium) — hardcoded in `PrefsRepository`
- **Mock interview limit** — 1 lifetime free trial / 5 per day premium — in `PrefsRepository`
- **All new features should be additive** — new files, new routes, new JSON assets
- **No backend server** — everything is local storage + Groq API + Google Play
- **Test on both light and dark themes** — both are fully customised
- **AdMob test IDs** are used in debug mode automatically
- **`app_secrets.dart`** must exist locally with real keys for AI and ads to work

---

## 17. Full Mock Interview Feature

### Overview
Simulates a complete IELTS Speaking test (Part 1 + Part 2 + Part 3) with AI-powered evaluation.

### Interview Flow
1. **Home** → tap "Full Mock Interview" → **Intro Screen** (explains format, checks credits)
2. **Loading** → AI generates Part 1 + Part 3 questions (1 API call)
3. **Part 1 Intro** → animated title card (auto-advance 2.5s)
4. **Part 1** → 6 questions (2 topics × 3), 30s per question, tap mic to speak
5. **Part 2 Intro** → animated title card (auto-advance 2.5s)
6. **Part 2 Prep** → Cue card displayed, 60s preparation timer
7. **Part 2 Speaking** → 120s speaking timer with live transcription
8. **Part 3 Intro** → animated title card (auto-advance 2.5s)
9. **Part 3** → 4 discussion questions, 45s per question, tap mic to speak
10. **Analyzing** → AI evaluates all transcripts (1 API call)
11. **Results Screen** → overall band, per-criterion bars, per-part scores + feedback, vocab, improved answer
12. **Free users** → premium upsell card below results ("Unlock Unlimited — ₹199 Lifetime")

### Timing Constants (in `mock_interview_screen.dart`)
| Constant | Value | Purpose |
|----------|-------|---------|
| `kPart1SecsPerQ` | 30 | Seconds per Part 1 question |
| `kPart2PrepSecs` | 60 | Part 2 preparation time |
| `kPart2SpeakSecs` | 120 | Part 2 speaking time |
| `kPart3SecsPerQ` | 45 | Seconds per Part 3 question |
| `kPartIntroDurationMs` | 2500 | Part intro screen display time |

### Credit System
| User Type | Mock Interviews | Tracked By |
|-----------|----------------|------------|
| Free | 1 total (lifetime trial) | `mock_free_completed` bool |
| Premium | 5/day | `mock_daily_count` + `mock_daily_date` |

### Key Methods in PrefsRepository
- `canDoMockInterview()` — checks if user can start a mock interview
- `getMockRemaining()` — remaining interviews available
- `hasMockFreeBeenUsed()` — whether free trial is consumed
- `incrementMockCount()` — called after completing a mock interview

### Monetisation Strategy
- Free user completes 1 mock interview → sees results → premium upsell card appears
- After trial used, intro screen "Start" button changes to "Upgrade to Premium"
- Existing cue card AI practice (5/day free) runs independently — not affected

---

## 18. AI Pronunciation Highlights Feature

### Overview
After AI practice (cue card or daily question), mispronounced/weak words in the user's transcript are color-coded orange.

### How It Works
1. AI prompt includes `pronunciation_flags` field — asks Groq to identify 2-8 commonly mispronounced words from the transcript
2. `AiFeedback.pronunciationFlags` stores the flagged words (lowercase)
3. Transcript display uses `RichText` + `TextSpan` to highlight matching words
4. Orange background + bold styling for flagged words
5. Legend text explains the highlighting below the transcript

### Screens With Highlighting
- **`ai_feedback_screen.dart`** — "Your Response" section uses `_buildHighlightedTranscript()`
- **`daily_question_practice_screen.dart`** — inline results also use `_buildHighlightedTranscript()`

### Graceful Fallback
- If `pronunciationFlags` is empty (older API responses, API failure), transcript renders as plain text — no highlighting, no errors

---

## 19. Daily AI Question Feature

### Overview
A fresh AI-generated IELTS Speaking question appears on the Home screen every day. Users can practice speaking the answer and get AI feedback.

### Flow
1. **Home Screen** → "Daily AI Question" card shows question + Part badge
2. Card loads from SharedPreferences cache first; if no cache for today, calls `AiService.generateDailyQuestion()` (1 Groq API call)
3. Tap "Practice with AI" → navigates to `/daily-question-practice` with question + partType
4. **Daily Question Practice Screen** → shows question → user taps mic to speak (30s Part 1 / 60s Part 3) → AI evaluates → shows band score + feedback inline (with pronunciation highlights)
5. Uses the shared AI daily quota (5 free / 15 premium per day)

### Home Screen Widget (`_buildDailyQuestion`)
- Blue gradient card between Explore grid and Daily Tip
- Shows: brain icon, "Daily AI Question" title, Part badge, question text, "Practice with AI" button
- Loading state: spinner + "Generating today's question..."
- Hidden if no question loaded and not loading

### Daily Question Practice Screen (`daily_question_practice_screen.dart`)
- Phases: `idle` → `speaking` → `analyzing` → `done`
- No prep timer (unlike cue card practice)
- Timing: 30s for Part 1, 60s for Part 3
- Uses `speech_to_text` for recording (same restart/safety pattern as AI practice)
- AI evaluation via `AiService.evaluateDailyAnswer()` (separate prompt tuned for Part 1/3)
- Results shown inline (no separate feedback screen) — band score, criteria bars, comment, strengths, improvements, improved answer, highlighted transcript
- Banner ad at bottom, video ad after evaluation completes

### Caching (in `PrefsRepository`)
- `daily_question_text` — cached question string
- `daily_question_part` — "Part 1" or "Part 3"
- `daily_question_date` — date string, resets daily
- Methods: `getDailyQuestion()`, `getDailyQuestionPart()`, `saveDailyQuestion()`

### API Cost
- 1 Groq call/day for question generation (temperature 0.9 for variety)
- 1 Groq call per practice attempt (uses AI daily quota)
- Fallback question if API fails: "What do you enjoy doing in your free time?" (Part 1)

---

## 20. Daily Streak System

### Overview
Tracks consecutive days of practice. Any practice (random, AI, mock, daily question) counts.

### How It Works
1. After any practice completes → `PrefsRepository.recordStreakToday()` is called
2. If `streak_last_date == today` → already counted, skip
3. If `streak_last_date == yesterday` → increment streak
4. If gap > 1 day → streak resets to 1
5. Home screen displays streak count with fire emoji (🔥) in orange gradient card

### Home Screen Widget (`_buildStreakAndGoal`)
- Left: streak card (🔥 + count + "Day streak ✓")
- Right: target band + exam countdown (tap to edit)
- Streak 0 = muted card (💤), streak > 0 = orange gradient with shadow

### SharedPreferences Keys
- `streak_count` — current streak number
- `streak_last_date` — date string (yyyy-MM-dd)

### Methods in PrefsRepository
- `getStreakCount()` — returns 0 if streak is broken (gap > 1 day)
- `recordStreakToday()` — called after any practice
- `hasPracticedToday()` — used for UI checkmark

---

## 21. Push Notifications (Daily Reminders)

### Overview
Local push notifications remind users to practice daily, mentioning their streak.

### Implementation
- **Package:** `flutter_local_notifications` ^18.0.1
- **Channel:** `daily_reminder` ("Daily Practice Reminder")
- **Schedule:** `periodicallyShow()` with `RepeatInterval.daily`
- **No server needed** — fully local

### Notification Content (dynamic)
- Streak active + not practiced today: "Don't lose your X-day streak! 🔥"
- Streak active + practiced today: "Keep your X-day streak going! 🔥"
- No streak: "Time to practice speaking! 🎯"

### Lifecycle
1. `NotificationService.init()` called in `main()` (try/catch, non-fatal)
2. If `notifications_enabled == true`, schedules daily reminder
3. After each practice → `onPracticeCompleted()` reschedules with updated streak text
4. User can toggle via `setEnabled(bool)`

---

## 22. Share Band Score

### Overview
Users can share their band scores on social media (WhatsApp, Instagram, etc.) with a Play Store link.

### Share Buttons Location
- **AI Feedback Screen** — share icon in app bar
- **Mock Interview Results** — "Share Result" button in header
- **Daily Question Results** — "Share" button below band score

### Generated Text Format
```
🎯 I scored Band 7.0 on IELTS Speaking practice!
📝 Topic: Describe a place you visited
🗣️ Fluency: 7.0 | 📖 Lexical: 6.5
✏️ Grammar: 7.0 | 🔊 Pronunciation: 7.5
Practicing with IELTS Speaking 2026 app!
Download: https://play.google.com/store/apps/details?id=com.monusidhar.ielts_speaking_2026
```

### Methods in ShareService
- `shareBandScore()` — AI cue card practice
- `shareMockResult()` — mock interview (overall + per-part bands)
- `shareDailyScore()` — daily question practice

---

## 23. In-App Review Prompt

### Overview
Asks users to rate the app on Play Store at the optimal moment — one time only.

### Trigger Conditions (ALL must be met)
1. User has completed 3+ AI practice sessions (tracked via `total_ai_sessions`)
2. User just scored Band 6.0+ (good experience = good review)
3. `review_prompted` is false (never asked before)

### Implementation
- **Package:** `in_app_review` ^2.0.10
- Checks `InAppReview.isAvailable()` before showing
- Uses native Play Store review dialog (not a custom popup)
- Called from: `ai_practice_screen`, `daily_question_practice_screen`, `mock_interview_screen`

---

## 24. Target Band & Exam Countdown

### Overview
Users set their target band score and exam date. Shown on home screen to create urgency.

### Home Screen Display
- Part of the streak row (`_buildStreakAndGoal`)
- Shows: 🎯 "Target Band 7.0" + 📅 "Exam in 23 days"
- Turns red when exam is within 7 days
- Tap to open edit dialog

### Edit Dialog (`_showGoalDialog`)
- Band slider: 5.0 → 9.0 (step 0.5)
- Date picker for exam date (optional, can clear)
- Saves to SharedPreferences immediately

### SharedPreferences Keys
- `target_band` — double (e.g. 7.0)
- `exam_date` — string (yyyy-MM-dd), nullable

### Methods in PrefsRepository
- `getTargetBand()` / `setTargetBand()`
- `getExamDate()` / `setExamDate()` / `clearExamDate()`
- `getDaysUntilExam()` — computed, returns null if no date set

---

## 25. Weak Area Analysis

### Overview
Analyzes practice history to identify the user's weakest IELTS criterion and shows an actionable tip.

### How It Works
1. Reads last 10 `PracticeSession` entries from `PracticeHistoryRepository`
2. Computes average for each criterion: Fluency, Lexical Resource, Grammar, Pronunciation
3. Identifies the lowest-scoring criterion
4. Displays as a card on home screen with icon, avg score, and specific improvement tip

### Home Screen Card (`_buildWeakAreaCard`)
- Only shown after 3+ AI practice sessions (otherwise hidden)
- Example: "📝 Focus Area — Grammar needs work (Avg 5.5) — Practice using past perfect and conditionals in answers."
- Color-coded by criterion type (purple/green/orange/blue)

### Tips per Area
- **Fluency:** "Try speaking non-stop for 1 minute on any topic daily."
- **Lexical Resource:** "Learn 3 new topic-specific words every day and use them."
- **Grammar:** "Practice using past perfect and conditionals in answers."
- **Pronunciation:** "Record yourself and compare with native speaker audio."

### No API Calls
Purely local computation from existing practice history data — zero API cost.
