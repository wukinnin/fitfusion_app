/// The Fitness Knight's disposition toward the player, derived from a
/// 12h-window session count and the recency of the last app-open.
///
/// Tiers (highest → lowest engagement):
///   1. [veryActive]        — ≥2 qualifying sessions in last 12h.
///   2. [somewhatActive]    — ≥1 qualifying session in last 24h.
///   3. [neutral]           — last app-open ≤ 48h, no qualifying session.
///   4. [somewhatInactive]  — last app-open age in (48h, 72h].
///   5. [veryInactive]      — last app-open age > 72h (or no data).
enum KnightDisposition {
  veryActive,
  somewhatActive,
  neutral,
  somewhatInactive,
  veryInactive;

  /// Path to the knight portrait asset for this disposition.
  String get assetPath {
    switch (this) {
      case KnightDisposition.veryActive:
        return 'assets/images/knight/1-very-active.png';
      case KnightDisposition.somewhatActive:
        return 'assets/images/knight/2-somewhat-active.png';
      case KnightDisposition.neutral:
        return 'assets/images/knight/3-neutral.png';
      case KnightDisposition.somewhatInactive:
        return 'assets/images/knight/4-somewhat-inactive.png';
      case KnightDisposition.veryInactive:
        return 'assets/images/knight/5-very-inactive.png';
    }
  }

  /// Human-readable label for chips / debug UI (e.g. "Very Active").
  String get displayName {
    switch (this) {
      case KnightDisposition.veryActive:
        return 'Very Active';
      case KnightDisposition.somewhatActive:
        return 'Somewhat Active';
      case KnightDisposition.neutral:
        return 'Neutral';
      case KnightDisposition.somewhatInactive:
        return 'Somewhat Inactive';
      case KnightDisposition.veryInactive:
        return 'Very Inactive';
    }
  }

  /// Pool of dialogue lines for this disposition. A line is randomly
  /// selected on each home-screen build (or at notification scheduling time).
  List<String> get lines {
    switch (this) {
      case KnightDisposition.veryActive:
        return const [
          'We came, we saw, we conquered. Next? ⚔️',
          'Welcome, warrior! Ready to conquer today\u2019s quests? 🛡️',
          'Your strength grows with every battle. 💪',
          'Another victory awaits — shall we begin? 🎖️',
          'Even the dragons are starting to look small to me. 🤏',
        ];
      case KnightDisposition.somewhatActive:
        return const [
          'Another day at the office. Let\u2019s get to work. 💼',
          'Ah, you\u2019ve returned. A fine day for adventure. 🏞️',
          'The kingdom is glad to see you again. �',
          'Let us continue where we left off. ⚔️',
          'A sharpened blade never rusts. �️',
        ];
      case KnightDisposition.neutral:
        return const [
          'Standing by\u2026 awaiting your command. 🧍',
          'I\u2019ve been standing by for three hours. My back hurts. 🧘‍♂️',
          'The battlefield is quiet\u2026 for now. 🤫',
          'You\u2019ve opened the app a few times. My cardio is fine. You? 🫀',
          'The gains don\'t make themselves while you scroll, friend. �',
        ];
      case KnightDisposition.somewhatInactive:
        return const [
          'I was starting to think you got eaten by that dragon. �',
          'Consistency is the truest armor. Don\'t let yours rust. 🛡️',
          'Your muscles are whispering my name. They miss me. 🥺',
          'The flames of battle grow dim without you. 🕯️',
          'Have you abandoned this quest, warrior? �',
        ];
      case KnightDisposition.veryInactive:
        return const [
          'Even the strongest knights must rest\u2026 you now, in peace. 🪦',
          'Will you rise again\u2026 or shall the story end here? �',
          'Is anyone there? Or am I just a nobody to you? 🌫️📱',
          'Is this\u2026 the end of our quest? I\'ll wait by the gate. 🏚️',
          'I\u2019ve forgotten the sound of a heartbeat. 💓',
        ];
    }
  }
}
