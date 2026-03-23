# FITFUSION

**Brief Overview**
- A mobile game for Android.
- A fitness-centered game that gamifies fitness activities.
- Aesthetically High Fantasy-inspired
- Motion Detection using the camera.
- Body is the controller similar to the Xbox Kinect. 
- Game is 2D rendered AR overlays.

---

**Formal Thesis Detail**

## General Objective:

This study aims to analyze, design, and develop "FitFusion", A platform for immersive fitness realities enhancing engagement through augmented gamification in digital workouts, to promote a meaningful exercise participation. 

### Specific Objectives

Specifically, the study aims to:

1. Assess the current state of digital workout solutions, particularly:
    1. User engagement
    2. Interaction, and
    3. Retention.
2. Utilize mobile platforms to design interactive and immersive game-centric functionality, including:
    1. Motion-detection as an input data, and
    2. Augmented reality for game rendering.
3. Implement gamification elements to promote platform engagement, such as:
    1. Competitive Leaderboards
    2. Player Statistics
    3. Achievements

## Scope and Limitations

### Scope of the Study

The study focuses on the analysis, design, and development of Fitfusion: A digital platform that incorporates augmented reality (AR) and motion-tracking with interactive gamification elements, to promote meaningful exercise participation.

The scope of the study encompasses the implementation of core functionalities within a mobile-based platform, such as input data from motion detection, immersive game design fronted by AR, tied with gamified elements such as leaderboards, player statistics, and achievements. 

Central to the design of FitFusion is to create a unique solution utilizing smartphones, to primarily use in tandem; performance-sensitive camera-based motion detection as an input source, and visually engaging AR game design feedback to render output.

With all this, the platform will then tie in gamification elements promoting fitness. Competitive elements include ranked leaderboards, game achievements, and player statistics.

### Limitations of the Study

While FitFusion is designed to offer a unique digital platform for exercise enhancing measures in general, the study is limited in a few key areas.

The study is conducted within a specific group of users in mind, primarily the student populace from the University of Cebu Lapu-Lapu and Mandaue. As such, findings may not fully represent the general population in terms of age, physical ability, or access to advanced mobile technology.

The study is limited especially in regards to system design and development. This is largely due to time constraints and technical ability. Compromises and omissions have been made to account for these limitations.

Technical ability and time limits game rendering to 2D AR renders only. 3D rendering is omitted as the current project's limitations.

Complex multiplayer, including both online and local forms are omitted. As such, FitFusion is strictly a single-player game experience. Only a selected amount of workouts are available to perform at a time, so a session of gameplay is limited to only one specific type of exercise at any given moment.

Any sort of complex personalization will be omitted. This would include setting gender, height/weight parameters, BMI, physical build, etc. The system is disregarding such metrics with the platform.

Naturally, performance may vary depending on device compatibility, sensor accuracy, and physical environment, especially for features involving AR interaction and motion tracking. External factors such as lighting, movement, form, precision, and user connectivity are beyond the scope of this study and may affect the overall experience and results.

---

## Context Overview

**FitFusion** is an Android mobile application that is simultaneously a fitness tool and a 2D augmented reality game. The core concept is simple: the player's physical body is the game controller. To play the game, you must exercise. To exercise effectively, the game must reward you. These two things are inseparable — the exercise IS the gameplay.

The app uses the phone's front-facing camera to detect the player's body movements in real time via Google ML Kit Pose Detection. The game renders as a 2D overlay drawn directly on top of the live camera feed, creating an augmented reality effect. The player sees themselves on screen with game elements — monsters, health bars, HUD — composited as a layer over the camera image. The body is tracked, reps are counted, and those reps drive every game mechanic.

## Visual Design Direction

### Theme: High Fantasy
Bright, vibrant, heroic. Think classic JRPG meets Western high fantasy — golden UI frames, glowing spell effects, colorful monster sprites, ornate borders. Reference: Final Fantasy, Might & Magic, early Dragon Quest aesthetic.

NOT: dark/gritty, desaturated, horror, steampunk, sci-fi.

### Typography
- **Display / headers:** "Cinzel" (Google Fonts) — serif, classical Roman letterform, feels ancient and heroic
- **Body / HUD:** "Cinzel Decorative"

### Color Palette
| Role | Color | Hex |
|------|-------|-----|
| Primary dark | Blood Red | `#660000` |
| Primary accent | Gold | `#FFD700` |
| Secondary | Emerald | `#2E7D32` |
| Danger | Crimson | `#B71C1C` |
| Background | Midnight Navy | `#0D1B3E` |
| UI panel fill | Parchment | `#FFF8E1` |
| Glow / damage | Bright Gold | `#FFEE58` |
| Text on dark | Cream White | `#FFFDE7` |

---

# System Architecture/Design

```
        FITFUSION GAME APP (PLAYERS)
 ╔═══════════════════════════════════════════╗
 ║                                           ║
 ║  ┌─────────────────────────────────────┐  ║
 ║  │          MOTION PIPELINE            │  ║
 ║  │  Phone Camera --> CameraService --> │  ║
 ║  │  PoseDetectorService --> RepDetector│  ║
 ║  │  --> PaceMonitor                    │  ║
 ║  └─────────────────────────────────────┘  ║
 ║           │                               ║
 ║           │  Stream <RepEvent>            ║
 ║           │  Stream <PaceEvent>           ║
 ║           ▼                               ║
 ║  ┌─────────────────────────────────────┐  ║
 ║  │         GAME CONTROLLER             │  ║
 ║  │  ( bridge layer --> decouples       │  ║
 ║  │    motion from game )               │  ║
 ║  └─────────────────────────────────────┘  ║
 ║           │                               ║
 ║           │  method calls                 ║
 ║           ▼                               ║
 ║  ┌─────────────────────────────────────┐  ║
 ║  │           FLAME GAME                │  ║
 ║  │  FitFusionGame ( FlameGame subclass)│  ║
 ║  │  Components: Monster, HealthBar,    │  ║
 ║  │  HUD, Cooldown, etc.                │  ║
 ║  └─────────────────────────────────────┘  ║
 ║           │                               ║
 ╚═══════════╪═══════════════════════════════╝
             │  GameSession ( on end )
             ▼
 ╔═══════════════════════════════════════════╗
 ║                                           ║
 ║  ┌─────────────────────────────────────┐  ║
 ║  │      SUPABASE/POSTGRES BACKEND      │  ║
 ║  │  Interface data: Stats, sessions,   │  ║
 ║  │  profiles, leaderboards             │  ║
 ║  │  Auth: Login/Sign Up, Email         │  ║
 ║  │  Verification, Reset Password       │  ║
 ║  └─────────────────────────────────────┘  ║
 ║           ▲                               ║
 ║           │                               ║
 ║  ┌─────────────────────────────────────┐  ║
 ║  │         ADMIN DASHBOARD             │  ║
 ║  │  Manage user and database data      │  ║
 ║  └─────────────────────────────────────┘  ║
 ║                                           ║
 ╚═══════════════════════════════════════════╝
      FITFUSION DATABASE DASHBOARD (ADMIN)
```

Each box is independent. Each arrow is a clean interface. This separation is what makes the system debuggable under time pressure — you can test each layer in isolation.

---

## Screens Navigation Flow

```
APP LAUNCH (ANDROID APP)
├── Splash Screen (Welcome)
│   ├── [User already logged in?]
│   │     └── Yes → HomeScreen
│   └── No
│         ├── Login
│         │   ├── Enter Credentials
│         │   ├── Reset Password (optional)
│         │   └── Success → HomeScreen
│         │
│         └── Sign Up
│             ├── Enter Credentials
│             ├── Check Email/Username Uniqueness
│             ├── Validate Password Rules
│             ├── Email Verification (6-digit OTP)
│             └── Success → Login
│
└── HomeScreen (Dynamic per User)
    ├── Play
    │   └── WorkoutSelectScreen
    │       ├── Select Workout Type
    │       └── Start Game Session
    │            ├── Game In Progress
    │            └── Game End Screen
    │                 ├── Retry (same workout)
    │                 └── Quit → HomeScreen
    │   
    ├── Leaderboards
    |
    ├── Acheivements
    |
    ├── Stats
    │
    └── Profile
        ├── Edit Profile
        │     ├── Username
        │     ├── Email
        │     └── Password
        |
        ├── Volume Slider Setting
        ├── Reset Game Data (Stats)
        ├── Sign Out
        └── Delete Account
```


No such "Guest account" function; account is needed to play.

All navigation uses Flutter's `Navigator`. Named routes defined in `app.dart`.


```
Database / Admin Launch (WEB PORTAL)
│
├── Admin Login
│   ├── Enter Credentials (preset / seeded in DB)
│   ├── Auth Check (email 6-digit OTP)
│   └── Admin Dashboard
│
└── Admin Dashboard
    │
    ├── Overview
    │   ├── Total Users
    │   ├── Database Statistics (logs, info)
    │   └── System Status (DB, Server Health)
    │
    ├── User Management
    │   │
    │   ├── View Users
    │   │   ├── Search / Filter / Sort Columns
    │   │   └── View Profile Details
    │   │
    │   └── User Management
    │       ├── Force Password Reset
    │       ├── Force Email Re-Verification
    │       └── Delete User
    │
    ├── Data Management
    │   ├── Tables List (view, sort/filter)
    │   │   ├── Users Table
    │   │   ├── Sessions Table
    │   │   └── Leaderboards Table  
    |   |       ├── Remove Invalid Scores 
    │   |       └── Reset Leaderboards
    │   │
    │   └── Export Data
    │       ├── CSV
    │       └── JSON
    │
    ├── Logs
    │
    └── Admin Account
        ├── Change Email
        ├── Change Password
        └── Log Out
```
---

# Game Design

## Loop

### Workout Selection Screen 
Before any game session, the player is shown a screen with three options:
- **Squats**
- **Jumping Jacks**
- **Side Crunches**

The player taps one to select it. The game session is built around whichever type the player picks. The workout type is passed into the game session and into the rep detector — only that exercise type is detected during play.

### The 10-Round Progression Loop

The game is a linear sequence of 10 rounds. Each round presents one monster. The player must defeat all 10 to win.

**Loop Overview:**
1. The loop begins when the player selects any workout type.
2. Upon selection, a cooldown period of 15 seconds begin (for the player to get ready)
3. Then the round starts. A monster appears with a health pool equal to `round + 1` hit points
4. The player must perform the reps of their chosen exercise within at least 5 seconds of each other
5. Each completed rep deals 1 damage to the monster (reduces its health by 1)
6. When the monster's health reaches 0, the round is won
7. A cooldown period of 15 seconds begin (for the player rest/get ready)
8. After cooldown, the next round starts automatically (hands-free experience)
9. This loops incrementally until round 10 is beaten.
10. Round 10 is beaten, the player wins, and the loop ends, game is over.

**Rep requirements table:**

| Round | Reps to Win |
|-------|-------------|
| 1     | 2           |
| 2     | 3           |
| 3     | 4           |
| 4     | 5           |
| 5     | 6           |
| 6     | 7           |
| 7     | 8           |
| 8     | 9           |
| 9     | 10          |
| 10    | 11          |

Formula: `repsRequired(round) = round + 1`

**Total reps to complete a full game session:** 2+3+4+5+6+7+8+9+10+11 = **65 reps**

## Gameplay Proper

### Rep Counter
- Displays reps done/reps needed.
- Looks bold and clear as to be viewed from afar.
- Below the health bar, top center area.

### Health Bar (coded in)
- Displayed on Top Center.
- Looks bold and clear as to be viewed from afar.
- Health Bar shrinks relevant to the Total Reps Done/Reps Needed 
- Equivalent and Tied to Rep Counter
S
### Monsters (sprite)
- Displayed on the upper left corner below the health bar.
- Monsters are displayed at random: `assets/images/monster/monster_*.png` with no repetition linearly.
- Must preserve original PNG aspect ratio; can be resized larger, but not stretched.
- Sized appropriately as viewed from afar.
- The player performs a rep, and a monster takes damage
- Damage is visualized by the monster flashing as a white silhouette very quickly (like in Zelda II)
- Damage also provides sonic feedback, `assets/audio/sfx/thud.mp3`

## Pace Mechanic

The pace mechanic is what makes FitFusion a game rather than a rep counter. It enforces continuous movement.

**Rule:** After the first rep of a round, the player must perform each subsequent rep within **5 seconds** of the previous rep.

## Pace Timer (coded in)

- A visualized countdown timer is displayed on the top right corner below the health bar.
- Looks bold and clear as to be viewed from afar.
- It counts down from 5 sec to 0 sec, relative to the pace mechanic logic
- It is green when in pace, then flashing in solid red when falling behind (threshold: 2 seconds)

**Implementation logic:**
- The pace timer does not start at the beginning of a round — it starts after the first rep of that round is detected. This gives the player time to get into position.
- If the next rep is detected within 5 seconds after any given rep → timer resets, no penalty
- If 5 seconds elapse with no rep detected → monster attacks → player loses 1 life → timer resets and the player must continue (round does not restart, progress is not lost — only a life is lost)
- The pace timer is paused during cooldown periods

## Lives System

- Player starts each game with **3 lives** — displayed as 3 cyan heart icons in the HUD
- Looks bold and clear as to be viewed from afar.

- Each monster attack (pace failure) costs 1 life → one heart goes dark/empty
- **Lives carry across all rounds for the entire session** — they do not reset between rounds
- When the player takes damage, the screen goes to a brief red filter at 40%, Similar to Doom 1993
- Then fades back to normal from red as a 2 sec animation. 
- Lives cannot be recovered or gained during a session
- At 0 lives: game over, player loses, player is defeated, and must retry from Round 1.
- Plays audio `assets/audio/sfx/damage.mp3` file whenever a player loses life.

## Cooldown Period

- Duration: 15 seconds
- Rep detection, and pace timer is paused throughout the duration
- Triggered before each round begins, and after each successful round.
- Round 10 will not play ending cooldown period, as game is over when beaten.
- Player can use this time to rest and prepare
- Cooldown sequence initiates automatically — no player input required.

## Aesthetics:

- Gameplay HUDs at the top like the health bar, pace timer, rep counter, and monster sprite is made temporarily invisible at this time.
- A 40% black tint/filter is overlaid over the camera to visualize this cooldown period.
- The camera tint is removed and is displayed back to normal when the cooldown is over.
- A timer ticks down from 15 secs - 0 secs as is the duration.
- Header that displays the next round number

Each time the cooldown period screen enters or exits, it must enter and exit with an intutive "gaming" animation. The complete cooldown sequence starts here:

1. Before the countdown starts, animate the screen sliding from the left for 1 second to enter.
2. The Gameplay HUD at the top is temporarily invisible.
3. Play `assets/audio/sfx/win_violin.mp3` for every time you enter the cooldown period.
4. Begin 15 second countdown for the cooldown period.
5. When the countdown reaches 0, animate the screen for 1 second to slide to the right to exit.
6. All the Gameplay HUD is visible and restored to normal operation.

## Win and Lose Conditions

| Condition | Event |
|-----------|-------|
| Defeat monster after any round | Player continue — proceed to cooldown period screen, game continue |
| Defeat monster in Round 10 | Player victory — show victory screen, game over |
| Lose all 3 lives at any point | Player defeated — show defeat screen , game over |

Neither condition is reversible mid-session.

### Victory Screen
1. Play `assets/audio/sfx/victory_orchestra.mp3`
2. Each time the Victory screen enters it must enter with an intutive "gaming" animation. So animate the screen sliding from the left for 1 second to enter.

- Header: "VICTORY" in green
- Displays stats:
    1. Clear time = the session time elapsed; key competitive metric (minutes:seconds.milliseconds | 01:59.033)
    2. Rounds Complete = rounds played/rounds total (2/10)
    3. Reps finished = reps performed/reps total (5/65)
    4. Best Rep interval = (2.455 secs)
    5. Average Rep Interval (2.920 secs)
- Subtext: "You have defeated all 10 monsters!"
- Shows "Retry" and 'Quit" button, each with "Are you sure you want to [X]?" confirmation screen

### Defeat Screen
1. Play `assets/audio/sfx/lose_violin.mp3`
2. Each time the Defeat screen enters it must enter with an intutive "gaming" animation. So animate the screen sliding from the left for 1 second to enter.

- Screen is tinted red at ~25% opacity
- Header: "DEFEAT" in red
- Displays stats:
    1. Clear time = the session time elapsed; key competitive metric (minutes:seconds.milliseconds | 01:59.033)
    2. Rounds Complete = rounds played/rounds total (2/10)
    3. Reps finished = reps performed/reps total (5/65)
    4. Best Rep interval = (2.455 secs)
    5. Average Rep Interval (2.920 secs)
- Shows "Retry" and 'Quit" button, each with "Are you sure you want to [X]?" confirmation screen

## Achievements

| #  | Name                     | Unlock Condition                                | Key Metric                 |
|----|--------------------------|--------------------------------------------------|----------------------------|
| 1  | First Blood              | Complete your first session (win or lose)        | total sessions played      |
| 2  | Iron Will                | Complete 30 total sessions                       | lifetime sessions          |
| 3  | Blood Pumper             | Reach 300 lifetime reps                          | lifetime reps              |
| 4  | Survivor                 | Complete 100 total rounds                        | lifetime rounds            |
| 5  | Halfway Hero             | Reach 5 rounds in a single session               | roundsCompleted            |
| 6  | Monster Hunter           | Win a full 10-round session                      | won == true                |
| 7  | Triple Crown             | Win at least one session in all 3 workout types  | victories per workout      |
| 8  | Speed Demon              | Achieve a best rep interval under 1.8 seconds    | bestRepIntervalSeconds     |
| 9  | Blinding Steel           | Win with an average rep interval under 2.3 sec   | won, avgRepIntervalSeconds |
| 10 | Record Breaker           | Beat your personal best clear time               | historical PB comparison   |
| 11 | Sharper Than Yesterday   | Beat your personal best rep interval             | historical PB comparison   |
| 12 | Untouchable              | Win with 0 lives lost                            | livesLost == 0             |
| 13 | Last Stand               | Win with exactly 2 lives lost                    | livesLost == 2             |

### Gameplay Proper
During proper gameplay in the middle of a session, should any achievement be unlocked, a small popup should appear below the pace timer.

This popup is a visual/sonic cue and does not interrupt gameplay. It is just a simple trophy icon enclosed within a circle. It should follow the established project aesthetic parameter, but is ultimately designed to be visible from a distance. It may be following a similar aesthetic as the pace timer.

The popup should have a subtle slide-in/slide-out effect from right to left. The popup is really only visible for 2 seconds. The animations only take 0.5 seconds for both entry/exit.

Any achievement must be accompanied by the simultaneous and immediate playing of an audio cue: `assets/audio/sfx/achievement.mp3` 

In the rare event that more than 1 acheivement is unlocked simultaneously, we can have multiple popups, but is stacking towards a downward directions. 

### Home Screen

The achievements are displayed like a table and hard locked that's sorted following the index in the achievements table above. Grayed out when not yet unlocked, and in full color when unlocked. Also a medal icon is displayed when unlocked. Must have a description (unlock condition) for each achievement displayed.

### Gameplay Flow

```
                    ___________
                   /           \
                  |    START    |
                   \___________/
                        |
                        |
                        v
                    __________
                   /          \
                  /  Workout   \
                 <     Type?    >
                  \            /
                   \__________/
                    |    |    |
         +----------+    |    +----------+
         |               |               |
         v               v               v
    +---------+    +----------+    +-----------+
    | Squats  |    | Jumping  |    |   Side    |
    |         |    |  Jacks   |    | Crunches  |
    +---------+    +----------+    +-----------+
         |               |               |
         +-------+-------+-------+-------+
                 |               |
                 v               |
          +-------------+<-------+
          |Begin Session|
          +-------------+
                 |
                 v
    +-----+---------------------+       +---------------------------+
    |     |Cooldown Period      |------>| - Entry/Exit sequence     |
    |     |Sequence             |       | - Countdown Timer         |
    |     +---------------------+       | - win_violin.mp3          |
    |            |                      +---------------------------+
    |            v
    |     +-------------+
    |     | Gameplay    |               +---------------------------+
    |     | Proper      |-------------->| - HUD (sprites, bars,     |
    |     +-------------+               |   timers, hearts, etc.)   |
    |            |                      | - Overall Game Logic      |
    |            v                      | - Core Loop               |
    |        __________                 +---------------------------+
    |       /          \
    |      /  Finished  \
    |     <   Round 10?  >
    |      \            /
    |       \__________/
    |         |      |
    |         |No,   |Yes, Performed all 65 reps
    |    game |      |
    |    prog.|      +----------------+
    |         |                       |
    | +---------------+               |
    | | Round >10     |               |
    | | Completed     |               |
    | +---------------+               |
    |         ^                       |
    |         |                       v
    +---------+         No, Lost all 3 Lives
                                      |
                                      v
                        +-------------+        +-------------+
                        |  Defeat,    |        |  Victory,   |
                        | Game Over   |        | Game Over   |
                        +-------------+        +-------------+
                                |                       |
                                |                       |
                                v                       v
                             ___________         _______/
                            /           \       /
                           |  END: Retry  |<----+
                           |   or Quit    |
                            \___________/
```

## Miscellaneous Info

- In gameplay proper, is a hands-free experience.
- In general, we want it to be intuitive and sensible, first and foremost.
- Logo is located in `fitfusion/assets/images/logo.png`
- Pressing back button, home button, or recent apps/overview button immediately ends the session to the defeat screen anywhere during gameplay proper, and all player lives are lost (There is no such pause or exit function mid game; this is by design)
- All gameplay mockup screenshots are located in `fitfusion/docs/*.png`, and is the basis for most description. May include visual elements unexpounded upon verbally.

---

# App Screens

## Auth

### Log In
- Email/Username
- Password

### Sign Up
- Email (unique, no database existing)
- Username (unique, no database existing and no matching characters regardless of capitalization)
- Password (with rules [1 uppercase and lowercase alpha numeric minimum, 1 special characters, 8 characters total minimum]confirm twice)
- Verify Email (6-digit OTP)

### Reset Password
- Send OTP to Existing Account Email (6 digit OTP)
- Create new passowrd (with rules)

## Home Screen

### Leaderboards

- Displays best metrics amongst users for each key session metric, per workout type.

Tabbed:
- Squats
- Jumping Jacks
- Side Oblique Crunches

Metric Category:
- Clear Time
- Best Rep Interval
- Average Rep Interval

Display by Row:

` 1 - JOHNDOE - (metric)`

- Lists top 10 best of the entire user base
- Ascending order (1st place to 10th place)
- Table dynamically updates 

### Acheivements
- Show user-specific dynamically tracked lifetime game acheivements.

### Stats

- Contains the current logged in users individual stats
- Contains historical data of user sessions totaled up.
- Comprised metrics of Personal Bests, Totals, and Averages
    1. Fastest Clear Time (per 3 workout types)
    2. Average Clear Time (per 3 workout types, if at least 2 or more sessions recorded for any 1 type of workout)
    3. Rounds Completed (per 3 workout types, and lifetime total)
    4. Reps Finished (per 3 workout types, and lifetime total)
    5. Victories (per 3 workout types, and lifetime total)
    6. Defeats (per 3 workout types, and lifetime total)
    7. Best Rep Interval (per 3 workout types)
    8. Average Rep Interval (per 3 workout types, if at least 2 or more sessions recorded for any 1 type of workout)

### Profile Settings
- User can reset game data
- Can change email/username (must be unique/not already taken for either credential)
- Can reset password in current login (confirm current password needed)
- Can delete account
- Volume Slider for App
- Sign Out of current account

---

# Development

### Code Style Rules
- Dart file names: `snake_case.dart`
- Class names: `PascalCase`
- Constants: prefix `k`, camelCase — e.g., `kPaceThresholdSeconds`, `kTotalRounds`, `kStartingLives`
- Enum types and values: `PascalCase` — e.g., `WorkoutType.squats`, `GamePhase.cooldown`
- Private members: prefix `_`
- No `print()` in production code — use Flutter's `debugPrint()` wrapped in `assert`
- Prefer `const` constructors wherever possible

## Current Project Stack

(may or may not be subject to change)

**App**
- Flutter (Dart)
- Flame Game Engine
- Google ML Kit Pose Detection
- Android SDK cmd-line tools
- Gradle 8
- ADB

**Database**
Website:
- HTMl, CSS, Javascript/Typescript
- Vue/React, Tailwind
Backend:
- Supabase/Postgres
- Vercel

**Environment**
- Tecno Spark Go 30c
- Android 14 HiOS + 8GB RAM
- Lenovo Thinkpad T470 + 16GB RAM
- Fedora Linux 43 GNOME Workstation
- BASH
- Windsurf
- VS Code
- Chromium
- Git + Github @ wukinnin/fitfusion

## `flutter analyze` dependencies

At time of writing (subject to change)
```
$ flutter pub get
Resolving dependencies... 
Downloading packages... 
  app_links 6.4.1 (7.0.0 available)
  camera 0.11.4 (0.12.0+1 available)
  camera_android_camerax 0.6.30 (0.7.1 available)
  camera_avfoundation 0.9.23+2 (0.10.1 available)
  flame 1.35.1 (1.36.0 available)
  flame_audio 2.11.14 (2.12.0 available)
  google_fonts 6.3.3 (8.0.2 available)
  hooks 1.0.1 (1.0.2 available)
  matcher 0.12.18 (0.12.19 available)
  meta 1.17.0 (1.18.2 available)
  native_toolchain_c 0.17.4 (0.17.6 available)
  permission_handler 11.4.0 (12.0.1 available)
  permission_handler_android 12.1.0 (13.0.1 available)
  test_api 0.7.9 (0.7.11 available)
  vector_math 2.2.0 (2.3.0 available)
Got dependencies!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

```

Don't fix what isn't broken. This works so far, despite the outdated versions. Compatibility > Latest versions.

---

# Database Schema/Relationships

`DATABASE.md` and `supabase/schema.sql`

---

# Admin Web Portal

To manage the backend remotely and bypass using directly the Supabase website, we have an admin web portal. Primarily used for Desktop/Mobile Browsers.

The stack is defined at an earlier point in this document. 
- HTML, CSS, Javascript
- React, Tailwind
- Chromium 

(Please tell me any suggestions for the admin web portal stack)

## Aesthetics (independent of the Gameplay App Aesthetics)

- Modern (doesn't *have* to follow the game aesthetic.)
- Sans Serif fonts are permissible
- Intuitive and Sensible UI/UX is preferred.
- Preferably basic, lightweight, and fast. No unnecessary bloat, like animations, fancy/advanced styling.
- Since this is a an Admin Dashboard, this may be a Single Page Animation for the most part (exceptions considered)

## Auth
- Login page for admin users
- Authentication with Supabase
- Note: The First Admin Account Credentials will be injected manually into supabase; after that, the existing admin/s can add more users by: email and temporary, to then verify the email, and then force a password reset.

## User Management
- View all users (username, email, verification status, created date)
- Search/filter users (by username or email)
- Force email re-verification (reset `is_email_verified = FALSE`)
- Force password reset (requires user to set new password on next login)
- Delete user (cascade deletes all their data)
- Create admin user (registers email to new admin database to be then verified, and password resetted)

## Session Oversight
- View recent sessions (last 100, with pagination)
- Filter by user (all sessions for a specific player)
- Filter by date range (e.g., last 7 days, last month)
- Session details popup (show full GameSession data: workout type, won/lost, reps, time, etc.)
- Delete invalid sessions (remove corrupted/test data)

## Leaderboard Maintenance
- View all 9 leaderboard boards (3 workout types × 3 metrics)
- Manual rank recalculation (trigger rank recomputation for a specific board)
- Remove invalid entries (delete entries that shouldn't be on leaderboards)
- Reset entire leaderboard (clear all entries — use sparingly)

## Achievement Integrity
- View achievement unlock counts (how many users have each achievement)
- Bulk reset achievements (for a specific user or all users)
- Manual unlock/lock (admin can grant or revoke achievements — for testing/support)

## Data Export
- Export users (CSV: username, email, created_at, verification status)
- Export sessions (CSV: all columns, optional date/user filters)
- Export leaderboards (CSV: all 9 boards with ranks and usernames)
- Export achievements (CSV: per-user achievement matrix)

## Essential Admin Actions

### Bulk Operations
- Delete all sessions for user (clean up test data)
- Export All Data (bundle up ZIP for CSVs)
- Recompute all leaderboards (maintenance after schema changes)

### System Health
- Database connection status (green/red indicator)
- Last session timestamp (system activity check)
- Storage usage (if applicable)

### Security
- Admin activity log (who did what, when)
- Session timeout (auto-logout after inactivity)# fitfusion_app
