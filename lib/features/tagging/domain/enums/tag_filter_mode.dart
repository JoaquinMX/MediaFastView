enum TagFilterMode {
  any,
  all,
  hybrid,
}

extension TagFilterModeX on TagFilterMode {
  bool get matchesAll => this == TagFilterMode.all;

  bool get isHybrid => this == TagFilterMode.hybrid;

  String get label => switch (this) {
        TagFilterMode.any => 'Any tags',
        TagFilterMode.all => 'All tags',
        TagFilterMode.hybrid => 'Hybrid',
      };

  String get helperText => switch (this) {
        TagFilterMode.any => 'Show items matching any selected tag.',
        TagFilterMode.all => 'Show items matching every selected tag.',
        TagFilterMode.hybrid =>
          'Combine must-include and match-any tags in one query.',
      };
}
