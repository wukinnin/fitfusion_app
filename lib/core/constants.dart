// Game Rules
const int kTotalRounds = 10;
const int kStartingLives = 3;
const double kPaceThresholdSeconds = 5.0;
const int kCooldownSeconds = 15;

// Rep formula — repsRequired(round) = round + 1
// round is 1-indexed (1 through 10)
int repsRequiredForRound(int round) => round + 1;

// Camera / ML Kit Performance
const int kFrameSkipCount = 2; // process every Nth frame from the camera
const double kLandmarkLikelihoodThreshold = 0.5;

// Rep Detection Thresholds
// These are normalized coordinate values (0.0 to 1.0 relative to image size)
// They will require tuning via physical device testing
const double kSquatDownThreshold =
    0.15; // Hip must drop below this delta to count as DOWN
const double kSquatUpThreshold =
    0.28; // Hip must rise above this delta to count as UP (stand fully)
const double kJumpingJackWristRaiseThreshold = 0.08;
const double kJumpingJackPerLegThreshold =
    0.55; // Each leg must be > 0.55x shoulder width from center
const double kJumpingJackLegsTogetherRatio =
    0.9; // Ankle separation must be < 0.9x shoulder width
// Standing Oblique Side Crunch thresholds (all normalised by shoulder width)
// kCrunchElbowKneeCrunchThreshold    — elbow↔knee ratio must fall BELOW this to enter the crunching state
// kCrunchElbowKneeExtendedThreshold  — elbow↔knee ratio must rise ABOVE this to complete the rep (hysteresis gap prevents false counts)
// kCrunchElbowEarOnHeadThreshold     — BOTH elbows must stay close enough to their ears/head
//                                      for the form to count as "hands on head"
//
// Tuned for forgiveness:
// - Higher crunch threshold (1.35) = easier to trigger "down" than original (1.2), but tighter than 1.45
// - Lower extended threshold (1.7) = easier to trigger "up" than original (1.8), but tighter than 1.6
// - Elbow↔ear threshold (1.30) allows elbows to flare naturally, but rejects
//   obvious free-swinging elbow cheats where the arms leave the head position
const double kCrunchElbowKneeCrunchThreshold = 1.35;
const double kCrunchElbowKneeExtendedThreshold = 1.7;
const double kCrunchElbowEarOnHeadThreshold = 1.30;

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
