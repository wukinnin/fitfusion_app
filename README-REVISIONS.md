# Revisions on top of README.md (original)

Includes but is not limited to:
1. Multiplayer
2. Difficulty Implementation (Cooldown Period Time Set)
3. Bonus Conditions
4. "Continued Use" Implementations (soon)

---

**Formal Thesis Detail**

## Scope and Limitations

### Scope of the Study

Limited multiplayer demo functionality is included.

### Limitations of the Study

Multiplayer is limited only to local sessions, and no online functionality.

---

## Context Overview

The app uses the phone's front-facing camera to detect the player's body movements in real time via Google ML Kit Pose Detection. The game renders as a 2D overlay drawn directly on top of the live camera feed, creating an augmented reality effect. The player sees themselves on screen with game elements — composited as a layer over the camera image. The body is tracked, reps are counted, and those reps drive every game mechanic.

---

# Game Design

## Loop

### Workout Selection Screen 
The player is first shown a screen with two options:
- **Singleplayer**
- **Multiplayer**

If Singleplayer, display:
- **Squats**
- **Jumping Jacks**
- **Side Crunches**


If Otherwise multiplayer, display only **Jumping Jacks**. 

Player 1 is currently logged in. Then ask for an email address of Player 2, then email OTP PIN verification  to finally proceed. This is so session data can be reflected with player 2, and can prove account exists.

Then, options for adjusting cooldown time:
- A slider range between 05-25 seconds.
- Default 15 seconds

Then game loads. Game proper background for screen is asset: `asset/images/game/background.png`

### The Rounds Progression Loop

The game is a linear sequence of 10 rounds. Each round have you face off against a dragon gets closer and closer to your screen. The game wins when all 10 rounds are finished.

1. The loop begins with successful workout select parameters.
2. Upon selection, the cooldown period begins.
3. Then the round starts. The RED DUAL HEADED dragon appears with a health pool reflecing the number of reps, and at a large size.
4. The player must perform reps within at least a set amount of seconds (reps interval) depending on the workout:
    - Squats: 4 seconds
    - Jumping Jacks: 3 seconds
    - Side Crunches: 2 seconds
5. Each completed rep deals damage and reduces the dragon's health, and shrinks it gradually.
6. When the dragon's health reaches 0, the dragon returns to normal size, and then disappears.
7. A cooldown period then ensues.
8. After cooldown, the next round starts automatically (hands-free experience)
9. This loops throughout the game until the 10th round, but is periodically interrupted by the bonus round.
    
**Bonus rounds**

1. After completing rounds 4 and 8, and before rounds 5 and 9, a bonus round appears; Cooldown period ensues as usual, but with special captions for bonus rounds.
2. The whole game logic is significantly redesigned and rehashed during this mini-game for this brief while.
3. Pace Rep Interval Timer will now serve as the fixed 15-second countdown timer for the Bonus Round session
4. HP Bar will temporarily be hidden during bonus round.
5. Entire dragon mechanic is not rendered, and performing any normal rep action (squatting, jumping jack, side crunches, is temporarily invalid during bonus round)
6. Rep Counter (reps_done/reps_needed) will be rehashed to display "[X] GEMS CAUGHT"
7. Entire lives system detection is paused and inactive, and made hidden for this time.

8. Up to 6 gems `(assets/images/game/diamond.png)` and up to 2 poisons `(assets/images/game/poison.png)` are established.
9. Gems and poisons are randomly scattered and spread on the screen, and is rendered every between a random 2-4 second value for each individual asset. Then disappears, and is replotted at a random place on the screen again.
10. The idea is that we have the player collect as many gems as possible within the alloted 15 second time limit.
11. The gems are collected by the player's right hand "touching" the gems with the right hand's palm. (no need for fancy fist/grab logic)
12. Should any gem be collected by the player's right hand, the gem disappears, and a new gem is rendered randomly somewhere else to maintain 6 gems at all time

13. The player has to avoid touching any poison at all.
14. Touching a poison at any point will immediately end the bonus round (timer = 0), and then (after Round 4 and 9) normal gameplay automatically continues to the cooldown period screen of next round.
15. If failed 1st bonus round (after round 5, before round 6) IS NOT A DEFEAT.
16. If failed 2nd bonus round (after round 10, before game over) IS NOT A DEFEAT.

17. The spread of gems/poisons should not overlap with HUD elements on screen. Otherwise, it's free game.
18. Spread and plotting of gems/poisons, should be far, distributed somewhat evenly, and within player's reach (not cutoff of screen)


18. Cooldown screen caption before bonus round:
"You currently have [X] gems collected."
19. X may be 0 (first bonus round start), or however many gems collected before going into 2nd bonus round
20. Cooldown screen captions after bonus round: "Bonus round over, [X] seconds deducted on clear time. Be sure to finish this session, warrior!"
21. X may be 0, or however many gems are collected.
22. X = gems collected carries over the entire session.

23. X = The number of gems caught = number of seconds deducted to the total clear time at the end of a session
24. After bonus round, game immediately resumes as normal to the next normal round/s.
25. This is not saved on leaderboards, purely local-session unique. Clear time final result based on deducted seconds from bonuses apply to leaderboards (for victories)
26. Enabling bonus round checkmark during workout select is respected and applied.



**REPS TO WIN; NO BONUS ROUNDS counted**

| Round     | Reps to Win |
|-----------|-------------|
| 1         | 8           |
| 2         | 8           |
| 3         | 8           |
| 4         | 8           |
| 5         | 8           |
| 6         | 9           |
| 7         | 9           |
| 8         | 10          | 
| 9         | 11          |
| 10        | 12          |
| **Total** | **91**      |  

### Bonus Splash Screen
- Before a cooldown period screen, and after bonus round.
- 3 seconds duration.
- Before bonus round: "BONUS -- Here's your chance to step up!"
- After bonus round, success: "GREAT JOB! -[XX] seconds to your clear time!"
- After bonus round, fail: "SHUCKS! Try again next time!"

## Multiplayer (Co-op)

The same general goes, but has standout differences in logic:

1. Begins multiplayer session: Player 1 is logged in, and invites Player 2 (in the same physical space) to multiplayer, and starts a session. 
2. Player 2 enters their email address and verifies it. This is crucial so that player 2 is able to keep a record of the shared session.
3. Multiplayer session requires 2 people to simultaneously perform reps to defeat the dragon, *as if they are one entity*
4. The screen is split left and right. Left is player 1 and right is player 2. Players are positioned accordingly and strictly.
5. If only 1 rep from the 2 players is detected, or both players did simultaneous reps but is done improperly, then that the rep is void.
6. Lives system is shared amongst both players.
7. At the end of the session Player 1 and Player 2 both keeps the same session data alongside each of their user ID and credentials (email, username attributed). The same stats are recorded. The same session ID is used. So really, the "gotcha" is that if any given session ID spawns multiple times in a row, and the difference is by a user ID, it's a multiplayer session.

Leaderboards:
- Separate toggle for singleplayer (default) and multiplayer above leaderboard metrics (clear time and best rep interval)
To display entries is to jointly recognize usernames, example logic as player 1 = JANE_DOE and player 2 = JOHN_DOE:  "#1 - [JANE_DOE] and [JOHN_DOE]".
(This applies for best  rep interval), lifetime metrics not distinguished for multiplayer)

Stats:
- Saves normally still as a one user. No multiplayer distinction or separation. Still calls session anyway.

Achievements:
- Achievement evaluation/detection is still working in multiplayer sessions. Still calls session anyway.

## Dragons
- Displayed at the center middle of the screen.
- RED DRAGON is for a normal (not bonus round). A spreadsheet in `assets/images/game/flying_twin_headed_dragon-red-spritesheet-144x128.png`. 144 x 128px per frame.
- GOLD DRAGON is for bonus (not normal round). A spreadsheet in `flying_dragon-gold-spritesheet-144x128px.png`. 144 x 128px per frame.
- Looping flying animation (12 frames total, 3 per frame) 
- Must preserve original PNG aspect ratio; can be resized larger, but not stretched.
- Damage is visualized by the dragon flashing as a white silhouette very quickly (like in Zelda II)
- Damage also provides sonic feedback, `assets/audio/sfx/thud.mp3`

**Enemy Sizing**

- Any given Dragon starts at a certain large size (>100% of the original size) depending on the reps needed to be slain (8, 9, 10, or 5)
- The dragon, after every rep performed, gradually shrinks all the way back to 100% when the final rep is performed.
- The table

| Reps (8)  | Scale at rep start (%)   | Scale at rep done (%) |
|-----------|--------------------------|-----------------------|
| 1         | 164%                     | 156%                  |
| 2         | 156%                     | 148%                  |
| 3         | 148%                     | 140%                  |
| 4         | 140%                     | 132%                  |
| 5         | 132%                     | 124%                  |
| 6         | 124%                     | 116%                  |
| 7         | 116%                     | 108%                  |
| 8         | 108%                     | 100%                  |


| Reps (9)  | Scale at rep start (%)   | Scale at rep done (%) |
|-----------|--------------------------|-----------------------|
| 1         | 172%                     | 164%                  |
| 2         | 164%                     | 156%                  |
| 3         | 156%                     | 148%                  |
| 4         | 148%                     | 140%                  |
| 5         | 140%                     | 132%                  |
| 6         | 132%                     | 124%                  |
| 7         | 124%                     | 116%                  |
| 8         | 116%                     | 108%                  |
| 9         | 108%                     | 100%                  |

| Reps (10) | Scale at rep start (%)   | Scale at rep done (%) |
|-----------|--------------------------|-----------------------|
| 1         | 180%                     | 172%                  |
| 2         | 172%                     | 164%                  |
| 3         | 164%                     | 156%                  |
| 4         | 156%                     | 148%                  |
| 5         | 148%                     | 140%                  |
| 6         | 140%                     | 132%                  |
| 7         | 132%                     | 124%                  |
| 8         | 124%                     | 116%                  |
| 9         | 116%                     | 108%                  |
| 10        | 108%                     | 100%                  |

| Reps (5)  | Scale at rep start (%)   | Scale at rep done (%) |
|-----------|--------------------------|-----------------------|
| 1         | 140%                     | 132%                  |
| 2         | 132%                     | 124%                  |
| 3         | 124%                     | 116%                  |
| 4         | 116%                     | 108%                  |
| 5         | 108%                     | 100%                  |


## Lives System

### Dragon Life Steal
- When a player lost a life, a penalty is added so that the Dragon "steals" that life, and the health, ergo, reps required is increased.
- When a dragon steals that life, the dragon's sized is increase +8%, and the shrinking logic still continues to apply.
- If a player loses a life at 5 out of 8 (5/8) reps, then the player will perform an extra 1 rep.
- 5/8 is initially required, then player lost a life in the process, and will now display as 6/8.
- The logic extends to overflow, so hypothetically, we can have 9/8 or 10/8 required reps. (+1 and +2 respectively)
- When the last life is lost, the game ends as is established.
- Penalty is to replenish the enemy's health, not increase the reps required.
- The health bar may not overextend if overflown. Keep it at full until it falls below whole number (example, 7/8)
- Can count towards results to reps d one (may overflow 87 similar bonus round logic), and lifetime reps.

## Cooldown Period

- Duration: 2-30 seconds
- Clear time metric, Rep detection, and pace timer is paused throughout the duration
- Triggered before each round begins, and after each successful round.
- Round 10 will not play ending cooldown period, as game is over when beaten.
- Player can use this time to rest and prepare
- Cooldown sequence initiates automatically — no player input required.


### Victory
Displays session stats:
1. Fastest Clear time
2. Rounds Complete = rounds played/rounds total (2/10)
    - If bonus rounds exceed 10 total, then example, 12/10, for example.
3. Reps finished = reps performed/reps total
    - If bonus rounds exceed 87 total, then example, 95/87, for example.
4. Best Rep interval
5. Average Rep Interval

- Subtext: "You have finally slain the Red Dragon!"


### Defeat
Displays session stats 
1. ~~Fastest Clear time~~
2. Rounds Complete = rounds played/rounds total (2/10)
    - If bonus rounds exceed 10 total, then example, 12/10, for example.
3. Reps finished = reps performed/reps total
    - If bonus rounds exceed 87 total, then example, 95/87, for example.
4. ~~Best Rep interval~~
5. ~~Average Rep Interval~~
- Shows "Retry" and 'Quit" button, each with "Are you sure you want to [X]?" confirmation screen


# Knightly Avatar (Continued Use)

In the homepage, we will have the **Fitness Knight.** A digital avatar that works very similar to Facebook Messenger Notes or Instagram Notes.

- When user last logged in
- When user last opened the app

These are the factors that will influence the Knight to display what notes. The notes will displayed will depend on disposition of player activity. Will intelligently determine based on player stats.

Which messages in particular is randomly selected for every homescreen load.

**Notifications**

Also sends out push notifications at least once within a time of day.

**Dialogue Sorted from good to bad disposition**

## THRESHOLD FOR SESSION =  AT LEAST MAKE IT TO ROUND 3. Otherwise, not counted.

### 1 - VERY ACTIVE

**Criteria:** At least 2 sessions done within 12 hours.

- "We came, We saw, we conquered. Next? ⚔️"
- "Welcome, warrior! Ready to conquer today’s quests? 🛡️”
- "Your strength grows with every battle. 💪"
- "Another victory awaits—shall we begin? 🎖️"
- "Even the dragons are starting to look small to me. 🤏"


### 2 - SOMEWHAT ACTIVE

**Criteria:** At least 1 session done within 12-24 hours.

- "Another day at the office. Let’s get to work. 💼"
- “Ah, you’ve returned. A fine day for adventure. 🏞️”
- “The kingdom is glad to see you again. 👑”
- “Let us continue where we left off. ⚔️”
- "A sharpened blade never rusts. 🗡️"

### 3 - NEUTRAL

**Criteria:** Opened app at least 1 time within 24-48 hours, but 0 sessions done.

- "Standing by… awaiting your command. 🧍"
- "I’ve been standing by for three hours. My back hurts. 🧘‍♂️"
- "The battlefield is quiet… for now. 🤫"
- "You’ve opened the app a few times. My cardio is fine. You? 🫀"
- "The gains don't make themselves while you scroll, friend. 📱"

### 4 - SOMEWHAT INACTIVE

**Criteria:** Absent. Hasn't opened app within 48-72 hours.

- "I was starting to think you got eaten by that dragon. 🐉"
- "Consistency is the truest armor. Don't let yours rust. 🛡️"
- "Your muscles are whispering my name. They miss me. 🥺"
- "“The flames of battle grow dim without you. 🕯️”
- "“Have you abandoned this quest, warrior? 💔”

### 5 - VERY INACTIVE

**Criteria:** Missing. Hasn't opened app for 72+ hours.

- “Even the strongest knights must rest… you now, in peace. 🪦”
- “Will you rise again… or shall the story end here? 📕”
- "Is anyone there? Or am I just a nobody to you? 🌫️📱"
- "Is this... the end of our quest? I'll wait by the gate. 🏚️"
- "I’ve forgotten the sound of a heartbeat. 💓"

