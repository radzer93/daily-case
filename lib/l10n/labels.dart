import 'package:intl/intl.dart' as intl;

import '../data/game_backend.dart';
import '../models/case_file.dart';
import '../models/feedback.dart';
import 'app_localizations.dart';

extension AppLabels on AppLocalizations {
  String levelName(Difficulty d) => switch (d) {
        Difficulty.easy => levelEasy,
        Difficulty.medium => levelMedium,
        Difficulty.hard => levelHard,
      };

  String levelDescription(Difficulty d) => switch (d) {
        Difficulty.easy => levelEasyDescription,
        Difficulty.medium => levelMediumDescription,
        Difficulty.hard => levelHardDescription,
      };

  String levelPoints(Difficulty d) => levelMultiplier(intl.NumberFormat('0.#', localeName).format(d.multiplier));

  String kindName(CaseKind k) => switch (k) {
        CaseKind.fictional => kindFictional,
        CaseKind.inspired => kindInspired,
      };

  String kindBadge(CaseKind k) => switch (k) {
        CaseKind.fictional => kindFictionalBadge,
        CaseKind.inspired => kindInspiredBadge,
      };

  String reasonLabel(FeedbackReason r) => switch (r) {
        FeedbackReason.unfair => reasonUnfair,
        FeedbackReason.contradiction => reasonContradiction,
        FeedbackReason.language => reasonLanguage,
        FeedbackReason.inappropriate => reasonInappropriate,
        FeedbackReason.other => reasonOther,
      };

  String errorText(BackendError e) => switch (e) {
        BackendError.notFound => errorNotFound,
        BackendError.noCases => errorNoCases,
        BackendError.caseClosed => errorCaseClosed,
        BackendError.caseFinished => errorCaseFinished,
        BackendError.invalidChoice => errorInvalidChoice,
        BackendError.notFinished => errorNotFinished,
        BackendError.sessionExpired => errorSessionExpired,
        BackendError.accountLink => errorAccountLink,
        BackendError.offline => errorOffline,
        BackendError.server => errorServer,
        BackendError.openFailed => errorOpenCase,
        BackendError.unknown => errorUnknown,
      };
}
