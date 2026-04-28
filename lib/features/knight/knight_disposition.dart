/// The Fitness Knight's disposition toward the player, derived from
/// recent activity timestamps. Higher = better disposition.
enum KnightDisposition {
  praise,
  questioned,
  concerned,
  inactive;

  /// Path to the knight portrait asset for this disposition.
  String get assetPath {
    switch (this) {
      case KnightDisposition.praise:
        return 'assets/images/knight/knight-praise.png';
      case KnightDisposition.questioned:
        return 'assets/images/knight/knight-questioned.png';
      case KnightDisposition.concerned:
        return 'assets/images/knight/knight-concerned.png';
      case KnightDisposition.inactive:
        return 'assets/images/knight/knight-inactive.png';
    }
  }

  /// Pool of dialogue lines for this disposition. A line is randomly
  /// selected on each home-screen build (or at notification scheduling time).
  List<String> get lines {
    switch (this) {
      case KnightDisposition.praise:
        return const [
          'My armor is glowing from your gains! ✨🛡️',
          'Is it getting hot in here, or is that just your fire? 🥵',
          'Even the dragons are starting to look small to me. 🐉🤏',
          'A sharpened blade never rusts. Good work, squire. ⚔️',
          'Slow and steady wins the siege. Keep pushing. 🐢🏰',
          'Consistency: The secret weapon of every hero. 🛡️✅',
        ];
      case KnightDisposition.questioned:
        return const [
          'You\u2019ve opened the app a few times. My cardio is fine—how\u2019s yours? 🙄',
          'Are we here to sweat, or are we here to window shop? 💅',
          'I\u2019ve been standing by for three hours. My back hurts. 🧘‍♂️💢',
          'The gains don\'t make themselves while you scroll, friend. 🏋️‍♂️📱',
          'My grandmother swings a mace faster than you log a set. 👵💥',
        ];
      case KnightDisposition.concerned:
        return const [
          'My adventures are lonely without your spirit. 🕯️',
          'I\u2019m thinking of auditioning for a new user. One with sneakers. 👟',
          'Consistency is the truest armor. Don\'t let yours rust. 🛡️',
          'Your muscles are whispering my name. They miss me. 🥺',
          'Did a dragon get you? Blink twice if you\u2019re trapped in a cave. 🐉',
        ];
      case KnightDisposition.inactive:
        return const [
          'I am eating my own leather boots for sustenance. 👢💀',
          'Dust. So much dust. I think a spider lives in my helmet now. 🕷️',
          'Is anyone there? Or am I just a nobody to you? 🌫️📱',
          'Is this... the end of our quest? I\'ll wait by the gate. 🏚️',
          'I\u2019ve forgotten the sound of a heartbeat. 💓❓',
        ];
    }
  }
}
