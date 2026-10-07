enum CaseKind {
  fictional(
    wire: 'fictional',
    label: 'fikcyjna',
    badge: 'Sprawa fikcyjna',
  ),
  inspired(
    wire: 'inspired',
    label: 'inspirowana',
    badge: 'Inspirowana prawdziwą sprawą',
  );

  const CaseKind({required this.wire, required this.label, required this.badge});
  final String wire;
  final String label;
  final String badge;

  static CaseKind fromWire(String? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return fictional;
  }
}
