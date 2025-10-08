enum TagFilterMode {
  any,
  all,
}

extension TagFilterModeX on TagFilterMode {
  bool get matchesAll => this == TagFilterMode.all;
}
