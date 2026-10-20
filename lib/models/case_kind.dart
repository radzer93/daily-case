enum CaseKind {
  fictional('fictional'),
  inspired('inspired');

  const CaseKind(this.wire);
  final String wire;

  static CaseKind fromWire(String? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return fictional;
  }
}
