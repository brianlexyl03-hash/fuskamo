/// Position values used across filters, forms, and the feed. Kept as an enum
/// (not free text) so the compiler catches typos the way loose strings in
/// the old JS `filters: []` arrays couldn't.
enum PlayerPosition {
  striker,
  winger,
  attackingMid,
  centralMid,
  defender,
  goalkeeper,
}

extension PlayerPositionX on PlayerPosition {
  String get label {
    switch (this) {
      case PlayerPosition.striker:
        return 'Striker';
      case PlayerPosition.winger:
        return 'Winger';
      case PlayerPosition.attackingMid:
        return 'Attacking Mid';
      case PlayerPosition.centralMid:
        return 'Central Mid';
      case PlayerPosition.defender:
        return 'Defender';
      case PlayerPosition.goalkeeper:
        return 'Goalkeeper';
    }
  }

  /// Value stored in Supabase — snake/kebab case, matches the original schema.
  String get dbValue {
    switch (this) {
      case PlayerPosition.striker:
        return 'striker';
      case PlayerPosition.winger:
        return 'winger';
      case PlayerPosition.attackingMid:
        return 'attacking-mid';
      case PlayerPosition.centralMid:
        return 'central-mid';
      case PlayerPosition.defender:
        return 'defender';
      case PlayerPosition.goalkeeper:
        return 'gk';
    }
  }

  static PlayerPosition fromDbValue(String value) {
    return PlayerPosition.values.firstWhere(
      (p) => p.dbValue == value,
      orElse: () => PlayerPosition.striker,
    );
  }
}

enum FeedFilter { all, striker, midfield, defender, gk, u17, u21 }
