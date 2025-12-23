enum TagFilterMode {
  any,
  all,
  hybrid,
}

extension TagFilterModeX on TagFilterMode {
  bool get matchesAll => this == TagFilterMode.all || this == TagFilterMode.hybrid;

  bool get isHybrid => this == TagFilterMode.hybrid;
}
