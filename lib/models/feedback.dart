enum FeedbackReason {
  unfair('unfair', 'Nie da się tego rozwiązać bez zgadywania'),
  contradiction('contradiction', 'Sprzeczność w aktach lub rozwiązaniu'),
  language('language', 'Błędy językowe'),
  inappropriate('inappropriate', 'Nieodpowiednie treści'),
  other('other', 'Inny problem');

  const FeedbackReason(this.wire, this.label);
  final String wire;
  final String label;

  static FeedbackReason? tryFromWire(String? v) {
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }
}

const int minRating = 1;
const int maxRating = 5;
const int maxFeedbackComment = 500;
