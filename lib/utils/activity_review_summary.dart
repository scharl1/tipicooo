class ActivityReviewSummary {
  const ActivityReviewSummary({
    required this.recommendedCount,
    required this.reviewCount,
    this.avgOverall,
    this.avg1,
    this.avg2,
    this.avg3,
    this.label1 = '',
    this.label2 = '',
    this.label3 = '',
  });

  final int recommendedCount;
  final int reviewCount;
  final double? avgOverall;
  final double? avg1;
  final double? avg2;
  final double? avg3;
  final String label1;
  final String label2;
  final String label3;

  bool get hasData =>
      recommendedCount > 0 ||
      reviewCount > 0 ||
      avgOverall != null ||
      avg1 != null ||
      avg2 != null ||
      avg3 != null;

  Map<String, dynamic>? toMapOrNull() {
    if (!hasData) return null;
    return {
      "recommendedCount": recommendedCount,
      "reviewCount": reviewCount,
      "avgOverall": avgOverall,
      "avg1": avg1,
      "avg2": avg2,
      "avg3": avg3,
      "label1": label1,
      "label2": label2,
      "label3": label3,
    };
  }

  static int _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static double? _double(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim().replaceAll(",", "."));
    }
    return null;
  }

  static String _str(dynamic v) => (v ?? "").toString().trim();

  static dynamic _pick(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) return map[k];
    }
    return null;
  }

  static ActivityReviewSummary fromAny(Map<String, dynamic> item) {
    Map<String, dynamic> source = item;
    final nestedReviewSummary = item["reviewSummary"];
    final nestedReviews = item["reviews"];
    if (nestedReviewSummary is Map) {
      source = Map<String, dynamic>.from(nestedReviewSummary);
    } else if (nestedReviews is Map) {
      source = Map<String, dynamic>.from(nestedReviews);
    }

    final recommendedCount = _int(
      _pick(source, const [
        "recommendedCount",
        "recommendCount",
        "wouldRecommendCount",
        "consigliatoCount",
        "recommendedUsersCount",
      ]),
    );

    final reviewCount = _int(
      _pick(source, const [
        "reviewCount",
        "reviewsCount",
        "totalReviews",
        "count",
      ]),
    );

    final avgOverall = _double(
      _pick(source, const [
        "avgOverall",
        "avgScore",
        "averageScore",
        "ratingAvg",
        "scoreAvg",
      ]),
    );

    final avg1 = _double(_pick(source, const ["avg1", "avgScore1", "score1Avg"]));
    final avg2 = _double(_pick(source, const ["avg2", "avgScore2", "score2Avg"]));
    final avg3 = _double(_pick(source, const ["avg3", "avgScore3", "score3Avg"]));

    final label1 = _str(_pick(source, const ["label1", "score1Label"]));
    final label2 = _str(_pick(source, const ["label2", "score2Label"]));
    final label3 = _str(_pick(source, const ["label3", "score3Label"]));

    return ActivityReviewSummary(
      recommendedCount: recommendedCount,
      reviewCount: reviewCount,
      avgOverall: avgOverall,
      avg1: avg1,
      avg2: avg2,
      avg3: avg3,
      label1: label1,
      label2: label2,
      label3: label3,
    );
  }
}

