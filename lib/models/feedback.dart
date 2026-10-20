enum FeedbackReason {
  unfair('unfair'),
  contradiction('contradiction'),
  language('language'),
  inappropriate('inappropriate'),
  other('other');

  const FeedbackReason(this.wire);
  final String wire;

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
