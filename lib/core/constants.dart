// Game Rules
const int kTotalRounds = 10;
const int kStartingLives = 3;
const double kPaceThresholdSeconds = 5.0;
const int kCooldownSeconds = 15;
const int kTotalSessionReps = 91;
const double kDragonLifeStealScaleBonus = 0.20;

// round is 1-indexed (1 through 10)
int repsRequiredForRound(int round) {
  if (round <= 5) return 8;
  if (round <= 7) return 9;
  if (round == 8) return 10;
  if (round == 9) return 11;
  return 12;
}

// Camera / ML Kit Performance
const int kFrameSkipCount = 2; // process every Nth frame from the camera
const int kPoseDetectionTargetFps = 12;
const double kLandmarkLikelihoodThreshold = 0.5;

// Rep Detection Thresholds
// Squat thresholds are ratios relative to the player's standing baseline
// hip↔knee delta. 1.0 means fully upright; smaller values mean deeper squat.
const double kSquatDownThreshold =
    0.65; // Half squat (parallel-ish) or deeper is valid
const double kSquatUpThreshold =
    0.82; // Must rise back near standing to finish the rep
const double kJumpingJackWristRaiseThreshold = 0.08;
const double kJumpingJackPerLegThreshold =
    0.55; // Each leg must be > 0.55x shoulder width from center
const double kJumpingJackLegsTogetherRatio =
    0.9; // Ankle separation must be < 0.9x shoulder width
const double kMultiplayerJumpingJackWristRaiseThreshold =
    -0.06; // Very forgiving: wrists can be slightly below shoulder height
const double kMultiplayerJumpingJackArmsDownThreshold =
    0.18; // Very forgiving: arms can still be above shoulder line on return
const double kMultiplayerJumpingJackPerLegThreshold =
    0.28; // Very forgiving: even smaller per-leg extension still counts
const double kMultiplayerJumpingJackLegsTogetherRatio =
    1.40; // Very forgiving: feet do not need to fully close
const double kMultiplayerRepLandmarkLikelihoodThreshold = 0.30;
// Standing Oblique Side Crunch thresholds (all normalised by shoulder width)
// kCrunchElbowKneeCrunchThreshold    — elbow↔knee ratio must fall BELOW this to enter the crunching state
// kCrunchElbowKneeExtendedThreshold  — elbow↔knee ratio must rise ABOVE this to complete the rep (hysteresis gap prevents false counts)
// kCrunchElbowEarOnHeadThreshold     — BOTH elbows must stay close enough to their ears/head
//                                      for the form to count as "hands on head"
//
// Release-ready tuning (lenient — ideal form must consistently register):
// - crunch threshold 1.60 — player only has to bring elbow moderately close to
//   the raised knee (higher ratio = easier trigger since smaller value = closer)
// - extended threshold 1.80 — requires a clear return to standing but no longer
//   forces the elbow to travel all the way back up; hysteresis gap of 0.20
//   against the crunch threshold stays wide enough to prevent oscillation.
// - elbow↔ear threshold 1.70 — very forgiving hands-on-head validator; elbows
//   may flare wide without invalidating the rep, but freely swinging arms that
//   fully leave the head position are still rejected.
const double kCrunchElbowKneeCrunchThreshold = 1.60;
const double kCrunchElbowKneeExtendedThreshold = 1.80;
const double kCrunchElbowEarOnHeadThreshold = 1.70;

// Rolling Average Buffer
const int kLandmarkBufferWindowSize = 5;

// Supabase
const String kSupabaseUrl = 'https://rhuraplphspbtswflath.supabase.co';
const String kSupabaseAnonKey =
    'sb_publishable_RRnQl83nt607J6kh1pf_dQ_OUEHG_nc';

// Leaderboard
const int kLeaderboardSize = 10;

// Achievement Thresholds
const int kIronWillSessions = 30; // #2  — lifetime sessions to unlock
const int kBloodPumperReps = 300; // #3  — lifetime reps to unlock
const int kSurvivorRounds = 100; // #4  — lifetime rounds to unlock
const double kSpeedDemonThreshold =
    1.8; // #8  — best rep interval (seconds) must be below this
const double kBlindingSteelThreshold =
    2.3; // #9 — avg rep interval (seconds) must be below this
