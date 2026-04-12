import 'package:fitfusion/core/enums.dart';
import 'package:fitfusion/core/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

class _AchievementViewModel {
  final int index;
  final String code;
  final String title;
  final String description;
  final bool unlocked;

  const _AchievementViewModel({
    required this.index,
    required this.code,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

List<_AchievementViewModel> _buildAchievementViewModels(
  Set<AchievementId> unlocked,
) {
  final sorted = List<AchievementId>.from(AchievementId.values)
    ..sort((a, b) => a.index.compareTo(b.index));

  return sorted
      .map(
        (id) => _AchievementViewModel(
          index: id.index,
          code: id.dbKey,
          title: id.displayName,
          description: id.description,
          unlocked: unlocked.contains(id),
        ),
      )
      .toList();
}

void main() {
  test('UT-APP-009 exposes complete achievement metadata for rendering', () {
    final viewModels = _buildAchievementViewModels({
      AchievementId.firstBlood,
      AchievementId.speedDemon,
    });

    expect(viewModels, hasLength(11));
    expect(viewModels.first.index, 1);
    expect(viewModels.first.code, 'first_blood');
    expect(viewModels.first.title, 'First Blood');
    expect(viewModels.first.unlocked, isTrue);

    final speedDemon =
        viewModels.firstWhere((item) => item.code == 'speed_demon');
    expect(speedDemon.description, contains('under 1.8 seconds'));
    expect(speedDemon.unlocked, isTrue);

    final lastStand =
        viewModels.firstWhere((item) => item.code == 'last_stand');
    expect(lastStand.unlocked, isFalse);
  });
}
