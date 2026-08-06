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

Central to the design of FitFusion is to create a unique solution utilizing smartphones, to primarily use in tandem; performance-sensitive camera-based motion detection as an input source, and visually engaging AR game design feedback to render output.

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

## Stats

**Session Stats (Applicable for Squats, Jumping Jacks, and Side Crunches; lower is better):**
1. Fastest Clear Time
    - Personal Best Session Time Elapsed
    - Per the 3 workout types
    - MM:SS.MSEC (example: 04:30.533)
2. Average Clear Time
    - Average Session Time Elapsed
    - Per the 3 workout types
    - At least more than 2 sessions required
    - MM:SS.MSEC (example: 04:30.533)
3. Best Rep Interval
    - Best Rep Interval (time before next rep) at any point of the session 
    - Per the 3 workout types
    - SS.MSEC (example: 2.123 -- 2 secs, 123 milliseconds)
4. Average Rep Interval
    - Average Rep Interval (time before next rep) across the entire session 
    - Per the 3 workout types
    - At least more than 2 sessions required
    - SS.MSEC (example: 3.744 -- 3 secs, 744 milliseconds)

**Lifetime Stats (All 3 workout types considered and aggregated; higher is better):**
5. Rounds Completed
    - Across 3 workout types
    - Lifetime total of all 3 types
6. Reps Finished
    - Across 3 workout types
    - Lifetime total of all 3 types
7. Victories
    - Per 3 workout types
    - Lifetime total across of all 3 types
8. Defeats 
    - Per 3 workout types
    - Lifetime total across of all 3 types

### Victory
1. Play `assets/audio/sfx/victory_orchestra.mp3`
2. Each time the Victory screen enters it must enter with an intutive "gaming" animation. So animate the screen sliding from the left for 1 second to enter.

- Header: "VICTORY" in green
- Displays session stats of workout:
    1. Fastest Clear time
    2. Rounds Complete = rounds played/rounds total (2/10)
    3. Reps finished = reps performed/reps total (5/65)
    4. Best Rep interval
    5. Average Rep Interval
- Subtext: "You have defeated all 10 monsters!"
- Shows "Retry" and 'Quit" button, each with "Are you sure you want to [X]?" confirmation screen

### Defeat
1. Play `assets/audio/sfx/lose_violin.mp3`
2. Each time the Defeat screen enters it must enter with an intutive "gaming" animation. So animate the screen sliding from the left for 1 second to enter.

- Header: "DEFEAT" in red
- Displays session stats of workout:
    1. Fastest Clear time
    2. Rounds Complete = rounds played/rounds total (2/10)
    3. Reps finished = reps performed/reps total (5/65)
    4. Best Rep interval
    5. Average Rep Interval
- Shows "Retry" and 'Quit" button, each with "Are you sure you want to [X]?" confirmation screen

## Achievements

| #  | Name                     | Unlock Condition                                 | 
|----|--------------------------|--------------------------------------------------|
| 1  | First Blood              | Complete your first session (win or lose)        | 
| 2  | Iron Will                | Complete 30 total sessions                       | 
| 3  | Blood Pumper             | Reach 300 lifetime reps                          |
| 4  | Survivor                 | Complete 100 total rounds                        | 
| 5  | Halfway Hero             | Reach 5 rounds in a single session               | 
| 6  | Monster Hunter           | Win a full 10-round session                      |
| 7  | Triple Crown             | Win at least one session in all 3 workout types  |
| 8  | Speed Demon              | Achieve a best rep interval under 1.8 seconds    |
| 9  | Blinding Steel           | Win with an average rep interval under 2.3 sec   |
| 10 | Untouchable              | Win with 0 lives lost                            |
| 11 | Last Stand               | Win with exactly 2 lives lost                    |

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

**App**
- Flutter (Dart)
- Flame Game Engine
- Google ML Kit Pose Detection
- Android SDK cmd-line tools
- Gradle 8
- ADB

**Website**
- HTML
- CSS
- Javascript
- Vue
- React
- Tailwind

**Backend**
- Supabase/Postgres
- Vercel

**Environment**
- Tecno Spark Go 30c
- Android 14 HiOS + 8GB RAM
- Lenovo Thinkpad T470 + 16GB RAM
- Fedora Linux 43 GNOME Workstation
- BASH
- Git + Github

### flutter dependencies

At time of writing (subject to change)
```
  app_links 6.4.1 (7.0.0 available)
  async 2.13.0 (2.13.1 available)
  camera 0.11.4 (0.12.0+1 available)
  camera_android_camerax 0.6.30 (0.7.1+2 available)
  camera_avfoundation 0.9.23+2 (0.10.1 available)
  cupertino_icons 1.0.8 (1.0.9 available)
  dart_jsonwebtoken 3.3.2 (3.4.0 available)
  flame 1.35.1 (1.36.0 available)
  flame_audio 2.11.14 (2.12.0 available)
  flutter_plugin_android_lifecycle 2.0.33 (2.0.34 available)
  google_fonts 6.3.3 (8.0.2 available)
  gotrue 2.18.0 (2.19.0 available)
  hooks 1.0.1 (1.0.2 available)
  matcher 0.12.18 (0.12.19 available)
  meta 1.17.0 (1.18.2 available)
  native_toolchain_c 0.17.4 (0.17.6 available)
  path_provider_android 2.2.22 (2.3.1 available)
  permission_handler 11.4.0 (12.0.1 available)
  permission_handler_android 12.1.0 (13.0.1 available)
  realtime_client 2.7.0 (2.7.1 available)
  shared_preferences 2.5.4 (2.5.5 available)
  shared_preferences_android 2.4.21 (2.4.23 available)
  shared_preferences_platform_interface 2.4.1 (2.4.2 available)
  storage_client 2.4.1 (2.5.1 available)
  supabase 2.10.2 (2.10.4 available)
  supabase_flutter 2.12.0 (2.12.2 available)
  test_api 0.7.9 (0.7.11 available)
  url_launcher_android 6.3.28 (6.3.29 available)
  vector_math 2.2.0 (2.3.0 available)
```

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
 ║  │  Interface data: Stats, achievements│  ║
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

# Screens Navigation Flow

## App Screens

```
APP LAUNCH 
├── Splash Screen
│   ├── [User already logged in?]
│   │     └── Yes → HomeScreen
│   └── No
│         ├── Login
│         │   ├── Forget Password
│         │   └── Success → HomeScreen; Remembers Credentials.
│         │
│         └── Sign Up
│             ├── Enter Credentials
│             ├── Check Email/Username Uniqueness and availability.
│             ├── Validate Password Rules
│             ├── Email Verification
│             └── Success → Login
│
└── HomeScreen
    ├── Play
    │   └── WorkoutSelectScreen
    │       ├── Select Workout Type
    │       ├── Game Tutorial Pop-Up (if checked)
    |       └── Game Session Proper
    |
    ├── Stats
    |
    ├── Leaderboards
    |
    ├── Achievements
    |
    └── Settings   
        ├── Volume Slider Setting
        ├── Toggle Tutorial ON/OFF at Starup 
        ├── Log Out         
        |
        └── Edit Profile
            ├── Reset Password
            ├── Change Username
            ├── Change Email
           `└── Delete Account

```

## Auth

### Log In
- Email/Username (accepts either; is tied to each other anyway)
- Password

### Sign Up
- Email (unique, no database existing)
- Username (unique, no database existing and no matching characters regardless of capitalization)
- Password (10 characters minimum, display rule status)
- Verify Email (6 digit OTP)

### Reset Password
- Send OTP to Existing Account Email (6 digit OTP)
- Create new passowrd (with rules: 10 character minimum)

## Home Screen

### Game Session

Selects between:
- Squats
- Jumping Jacks
- Side Oblique Crunches

#### Gameplay Tutorial Pop-Up Instruction

For any of each selection;
- Pop-up of tutorial a FitFusion game session.
- The tutorial is a written instruction on how the game works
- It may have pagination if needed.
- At the end of the tutorial is a button to `Play` and proceed to the game proper.
- A checkbox to check or uncheck option to run at startup. (Can be reenabled in the settings if made unchecked)

```
1. 10 rounds await each with a monster that you must defeat.
2. You must defeat all 10 monsters by doing your chosen workout properly.
3. Each rep you perform deals damage to the monster.
4. Do enough reps as needed, and keep a good pace to continuously deal damage and defeat the monster.
5. The amount of reps needed increase the more you progress per round.
6. Consistently deal damage! The monster attacks you if you fail to do at least 1 rep within 5 seconds of each other.
7. You are given only 3 lives for failing to keep pace, and cannot be replenished once lost.
8. The game ends when you defeat all 10 monsters or lose all 3 lives.
9. Before and after every round, the player is given a brief 15 second cooldown period to recover.
10. Attempting to pause or halt the game session will immediately trigger a game over. The entire game is a hands-free experience.
11. The game session ends with victory when you slay all 10 monsters, or defeat if you lose all 3 lives.

[ PLAY ]

[X] Show at startup

-> pop up if unchecked
( You can toggle this option again at settings [ OK ] -> Gameplay begin)

```

### Stats

- Displays **Session Stats** and **Lifetime Stats** of the logged in player user.
- 4 different stats pages; 3 for the different workout types, and the total across all three.

**Session Stats (Applicable for Squats, Jumping Jacks, and Side Crunches; lower is better):**
1. Fastest Clear Time
2. Average Clear Time
3. Best Rep Interval
4. Average Rep Interval

**Lifetime Stats (All 3 workout types considered and aggregated; higher is better):**
5. Rounds Completed
6. Reps Finished
7. Victories
8. Defeats 


### Leaderboards

Displays best competitive metrics across all users.

**8 Leaderboards Identified:**

*Squats, Jumping Jacks, Side Crunches - 2 each type (6 total)*
1. Fastest Clear Time
2. Best Rep Interval

*Lifetime - 2 stats (6 + 2 = 8 total)*
1. Reps Finished
2. Victories

Display each leaderboard for example:

[ SQUAT ]
FASTEST CLEAR TIME
| RANK | USERNAME | STAT |
|------|----------|------|
| 1    | JOHNDOE  | 02.110 |  
| 2    | JANEDOE  | 02.182 |  
| [...]  | [...]    | [...]

- Lists top 10 best of the entire user base
- Lower stat value is ranked higher, ascending order (1st place to 10th place)
- Table dynamically updates; refreshes upon viewing.

### Acheivements
- Show user-specific dynamically tracked lifetime game acheivements.
- Greyed/Unavailable when unacheived, and otherwise if acheived according to the conditions set by the player statistics.

### Settings

- Turn On/Off Game Tutorial at Startup
- Volume Slider for App
- Sign Out of current account

#### Edit Profile 

**Reset Password**

Can reset password in current login (confirm current password needed) [REQUIRES INPUT CURRENT PASSWORD TO PERFORM]

1. Input Current Password, then #2:
```
Enter new password: [            ]
Confirm new password: [            ]

[CHANGE PASSWORD]
```
3. Then exit to return to menu.

**Change Username**

Can change username (must be unique/not already taken for either credential) [REQUIRES INPUT CURRENT PASSWORD TO PERFORM]

1. Input Current Password, then #2:
```
Enter new username: [            ]
Confirm new username: [            ]

[CHANGE PASSWORD]
```
3. Then exit to return to menu.

**Change Email**

Can change email (must be unique/not already taken for either credential) [REQUIRES INPUT CURRENT PASSWORD TO PERFORM]

1. Input Current Password, then #2:
```
Enter new email: [            ]
Confirm new email: [            ]

[CHANGE PASSWORD]
```
3. Redirect to auth screen: Verify Email Screen.
4. Upon success, then exit to return to menu.

**Delete Account**

Can delete user profile and game data [REQUIRES INPUT CURRENT PASSWORD TO PERFORM]

1. Input Current Password, then #2:
```
ARE YOU SURE YOU WANT TO DELETE ACCOUNT? ALL DATA IS CLEARED AND DISASSOCIATES YOUR EMAIL AND USERNAME IN THE GAME. THIS CANNOT BE UNDONE

[YES] [NO]
```
3. Upon success, then exit to return to settings.
4. "No" exits and returns to settings

# Admin Web Portal

```
Admin Web Portal
│
├── Login/Welcome Screen
|   ├── Input Credentials
|   └── Success → Dashboard
| 
└── Dashboard
    ├── Overview
    │   └── Total Users
    |
    ├── Data Management
    │   ├── View Players
    │   │   ├── Search / Filter / Sort Columns
    │   │   ├── View Profile Details
    │   │   └── View Game Data and Stats 
    |   |
    │   ├── View Admins
    │   │   ├── Search / Filter / Sort Columns
    │   │   └── View Profile Details
    │   │
    │   ├── User Management (Admin and Players)
    │   |   ├── Force Password Reset
    │   |   └── Force Delete User
    │   │
    │   ├── Leaderboard Management
    │   │
    │   ├── Achievment Integrity
    |   |
    |   └── Export Data
    |
    ├── Admin Logs
    |
    └── Settings
        ├── Log Out
        ├── Reset Password
        ├── Change Username
        └── Change Email
```

To manage the backend remotely and bypass using directly the Supabase website, we have an admin web portal. Primarily used for Desktop/Mobile Browsers.

## Aesthetics (independent of the Gameplay App Aesthetics)

- Modern (doesn't *have* to follow the game aesthetic.)
- Sans Serif fonts are permissible
- Intuitive and Sensible UI/UX is preferred.
- Preferably basic, lightweight, and fast. No unnecessary bloat, like animations, fancy/advanced styling.
- Since this is a an Admin Dashboard, this may be a Single Page Animation for the most part

## Login/Welcome Screen
- Login page for admin users
- Note: Admin creation on the web portal is impossible. Has to be manually created in the database. 

## Dashboard

### Overview
- Shows total number count of users both for Admin and Players.

### Data Management

#### View Players
- Search/filter users
- View player profile details (username, email, verification status, created date, uuid)
- View player game data and stats. All Session Stats (Across 3 types) and Lifetime Stats. Also includes Achievements Status and flaggable Leaderboard Standings.

#### View Admins
- Search/filter users
- View player profile details (email, verification status, created date, uuid)

#### User Management
- Force password reset (requires user to set new password on next login)
- Delete user (cascade deletes all their data)

#### Leaderboard Management
- Renders All 8 identifiable leaderboards continuously with up-to-date column sorting fetch.
- Top 20 for each leaderboard in the portal; render only 10 for the app.

#### Achievement Integrity
- View achievement unlock counts (how many users have each achievement)

#### Export Data
- Organized export of tables and schema with current data as CSV/JSON. 
- Option to bundle as ZIP

### Admin Logs
- Significant actions made in the web portal is tracable to admins with email, uuid, timestamp, and (action). 
- Exportable as TXT

### Settings

- Log Out of Current Account

**Reset Password**

Can reset password in current login (confirm current password needed) [REQUIRES INPUT CURRENT PASSWORD TO PERFORM]

1. Input Current Password, then #2:
```
Enter new password: [            ]
Confirm new password: [            ]

[CHANGE PASSWORD]
```
3. Then exit to return to menu.

**Change Email**

Can change email (must be unique/not already taken for either credential) [REQUIRES INPUT CURRENT PASSWORD TO PERFORM]

1. Input Current Password, then #2:
```
Enter new email: [            ]
Confirm new email: [            ]

[CHANGE PASSWORD]
```
3. Redirect to auth screen: Verify Email Screen.
4. Upon success, then exit to return to menu.

**Delete Account**

Can delete user profile [REQUIRES INPUT CURRENT PASSWORD TO PERFORM]

1. Input Current Password, then #2:
```
ARE YOU SURE YOU WANT TO DELETE ACCOUNT? THIS DISASSOCIATES YOUR EMAIL. THIS CANNOT BE UNDONE

[YES] [NO]
```
3. Upon success, then exit to return to settings.
4. "No" exits and returns to settings
