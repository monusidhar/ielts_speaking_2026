# IELTS Speaking 2026 — Full App Context

> **Use this file** to give any AI assistant full context about this project.
> Last updated: 15 May 2026

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
│       └── update_service.dart        # Remote forced-update check
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

Routes are defined in `main.dart`. Simple routes use `routes:` map; `cueCardDetail`, `aiFeedback`, and `mockInterviewResult` use `onGenerateRoute`.

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

---

## 7. Premium vs Free Logic

| Feature | Free | Premium |
|---------|------|---------|
| Cue cards | First 50 (`id <= 50`) | All cards |
| Vocabulary | From first 50 cards only | All vocabulary |
| Random practice | Random from first 50 | Random from all |
| AI Speaking Coach (cue card) | 5 uses/day | 15 uses/day |
| **Full Mock Interview** | **1 lifetime trial** | **5/day** |
| Ads | Banner + interstitial + rewarded | No ads |
| Bookmarks | Unlimited | Unlimited |
| Practice history | Available | Available |

**Free card limit constant:** `kFreeCardLimit = 50` in `cue_card_repository.dart`.

**Purchase product ID:** `remove_ads_lifetime` (one-time, Google Play Billing).

---

## 8. Ad Placements (`ad_service.dart`)

| Ad Type | Where | Trigger |
|---------|-------|---------|
| **Banner** | Bottom of cue card list, cue card detail | Always visible (free users) |
| **Interstitial** | After random practice | Every 3 practices (`_interstitialFrequency = 3`) |
| **Rewarded** | After AI practice | After completing AI evaluation |

All ads auto-hidden when `isPremium == true`. Uses `google_mobile_ads` + `gma_mediation_unity`.

---

## 9. AI Services

### AiService (`ai_service.dart`) — Cue Card Practice
- **API:** Groq (`https://api.groq.com/openai/v1/chat/completions`)
- **Model:** Llama 3.3 70B Versatile
- **Input:** User transcript, cue card topic + prompts + sample answer, speaking duration
- **Output:** `AiFeedback` object with band scores, comment, strengths, improvements, suggested vocab, improved answer
- **Rate limiting:** 5 free / 15 premium per day
- **Method:** `AiService.evaluateAnswer()`
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
| `share_plus` | ^13.0.0 | Share app with friends |
| `package_info_plus` | ^10.0.0 | App version info |

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
