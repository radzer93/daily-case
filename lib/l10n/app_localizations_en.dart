// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Case of the Day';

  @override
  String get appBarTitle => 'CASE OF THE DAY';

  @override
  String caseNumber(int number) {
    return 'no. $number';
  }

  @override
  String get archive => 'Archive';

  @override
  String get retry => 'Try again';

  @override
  String get statusErrorTitle => 'Can\'t reach the records office';

  @override
  String get statusEmptyTitle => 'The files haven\'t arrived yet';

  @override
  String statusEmptyBody(String level) {
    return 'Today\'s $level case is on its way. Check back in a moment, pick another level or browse closed cases.';
  }

  @override
  String get tabBrief => 'CASE FILE';

  @override
  String tabEvidence(int visible, int total) {
    return 'EVIDENCE $visible/$total';
  }

  @override
  String tabStatements(int count) {
    return 'STATEMENTS $count';
  }

  @override
  String tabAccusation(int attempts) {
    return 'ACCUSATION $attempts×';
  }

  @override
  String get tabVerdict => 'VERDICT';

  @override
  String get tabSolution => 'SOLUTION';

  @override
  String get tapeScene => 'Crime scene';

  @override
  String get tapeDoNotCross => 'Do not cross';

  @override
  String get tapePolice => 'Police';

  @override
  String tapeDocket(String docket) {
    return 'Ref. $docket';
  }

  @override
  String get howToTitle => 'HOW TO WORK THE CASE';

  @override
  String howToBody(int attempts) {
    return 'Read the evidence and the statements. Name the culprit, the motive and the evidence that proves it. You have $attempts attempts and after each one you will see what you got right. Lab reports reveal extra evidence but cost points. The case closes at midnight and the solution is released the next day.';
  }

  @override
  String get openEvidence => 'Open the evidence';

  @override
  String get goToStatements => 'Go to statements';

  @override
  String get seeSolution => 'See the solution';

  @override
  String get seeVerdict => 'See the verdict';

  @override
  String get makeAccusation => 'Make an accusation';

  @override
  String get accusationIncomplete =>
      'Choose the culprit, the motive and the evidence.';

  @override
  String get groupCulprit => 'Culprit';

  @override
  String get groupMotive => 'Motive';

  @override
  String get groupEvidence => 'Evidence that proves it';

  @override
  String get sending => 'Sending…';

  @override
  String get submitAccusation => 'File the charge';

  @override
  String attemptsLeft(int count, int hints) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '$count attempt',
    );
    return '$_temp0 · lab reports: $hints';
  }

  @override
  String get archiveTitle => 'ARCHIVE';

  @override
  String get archiveLoadFailed => 'Couldn\'t load the archive.';

  @override
  String get archiveEmpty =>
      'The archive is still empty. The first case will land here tomorrow, together with its solution.';

  @override
  String get archiveIntro =>
      'Cases from previous days. Their solutions are now public.';

  @override
  String get archiveClosed => 'SOLVED';

  @override
  String get archiveDismissed => 'DISMISSED';

  @override
  String get archiveLapsed => 'LAPSED';

  @override
  String get archiveUntouched => 'NOT INVESTIGATED';

  @override
  String get levelEasy => 'Easy';

  @override
  String get levelMedium => 'Medium';

  @override
  String get levelHard => 'Hard';

  @override
  String get levelEasyDescription => '3 suspects, one clear lead.';

  @override
  String get levelMediumDescription =>
      '4 suspects, the lead is hidden in the details.';

  @override
  String get levelHardDescription =>
      '4 suspects, false leads, two clues to connect.';

  @override
  String levelMultiplier(String value) {
    return '×$value pts';
  }

  @override
  String get chooseLevelTitle => 'CHOOSE A LEVEL';

  @override
  String get chooseLevelBody =>
      'Every day there are three cases, one per level. You can switch levels at any time on the case screen.';

  @override
  String get kindFictional => 'fictional';

  @override
  String get kindInspired => 'inspired';

  @override
  String get kindFictionalBadge => 'Fictional case';

  @override
  String get kindInspiredBadge => 'Inspired by a real case';

  @override
  String streakSemantics(int streak) {
    return 'Daily case streak: $streak';
  }

  @override
  String streakChip(int streak) {
    return 'STREAK $streak';
  }

  @override
  String docketLabel(String docket) {
    return 'CASE REF. $docket';
  }

  @override
  String levelBadge(String level) {
    return 'LEVEL: $level';
  }

  @override
  String get archivedCaseNote => 'Archived case. The solution is public.';

  @override
  String get dailyCase => 'Case of the day';

  @override
  String evidenceNumber(int number) {
    return 'EXHIBIT $number';
  }

  @override
  String get evidenceRestricted => 'RESTRICTED';

  @override
  String get evidenceExpertise => 'LAB REPORT';

  @override
  String requestExpertise(int cost) {
    return 'Order a lab report · −$cost pts';
  }

  @override
  String get interrogationRecord => 'INTERVIEW RECORD';

  @override
  String suspectAgeRole(int age, String role) {
    return '$age, $role';
  }

  @override
  String quoted(String text) {
    return '“$text”';
  }

  @override
  String get excludedUndo => 'Ruled out · undo';

  @override
  String get excludeSuspect => 'Rule out';

  @override
  String get cellCulprit => 'CULPRIT';

  @override
  String get cellMotive => 'MOTIVE';

  @override
  String get cellEvidence => 'EVIDENCE';

  @override
  String cellHit(String label, String value) {
    return '$label: $value, correct';
  }

  @override
  String cellMiss(String label, String value) {
    return '$label: $value, wrong';
  }

  @override
  String levelSemantics(String level) {
    return 'Level $level';
  }

  @override
  String levelSemanticsSolved(String level) {
    return 'Level $level, solved';
  }

  @override
  String get stampClosed => 'Case closed';

  @override
  String get stampDismissed => 'Case dismissed';

  @override
  String get stampLapsed => 'Case lapsed';

  @override
  String get stampOpen => 'Case open';

  @override
  String points(int score) {
    return '$score pts';
  }

  @override
  String verdictWon(String result) {
    return 'The prosecutor accepts the charge. Score: $result.';
  }

  @override
  String get verdictDismissedPending =>
      'Three wrong accusations. The solution will be released after midnight.';

  @override
  String verdictDismissed(String name) {
    return 'Three wrong accusations. The culprit was $name.';
  }

  @override
  String get verdictLapsedUntouched =>
      'This case passed without your investigation.';

  @override
  String get verdictLapsedLate => 'Midnight came before you solved it.';

  @override
  String verdictCulprit(String name) {
    return 'The culprit was $name.';
  }

  @override
  String get verdictOpen => 'Go back to the case of the day to solve it.';

  @override
  String get statPlayed => 'Played';

  @override
  String get statWinRate => 'Solved';

  @override
  String get statStreak => 'Streak';

  @override
  String get statBest => 'Best';

  @override
  String get solutionPending =>
      'The solution will be released after midnight. Come back tomorrow: the archive will show who did it and why.';

  @override
  String nextCaseIn(String time) {
    return 'Next case in $time';
  }

  @override
  String get shareResult => 'Share result';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Result copied';

  @override
  String get feedbackQuestion => 'HOW WOULD YOU RATE THIS CASE?';

  @override
  String ratingTooltip(int rating, int max) {
    return 'Rating $rating of $max';
  }

  @override
  String get feedbackThanksRating => 'Thanks for rating.';

  @override
  String get feedbackSheetTitle => 'What\'s wrong with this case?';

  @override
  String get feedbackThanksReport => 'Thank you. We\'ll look into this case.';

  @override
  String get feedbackReported => 'Report received. Thank you.';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get reasonUnfair => 'It can\'t be solved without guessing';

  @override
  String get reasonContradiction =>
      'Contradiction in the files or the solution';

  @override
  String get reasonLanguage => 'Language errors';

  @override
  String get reasonInappropriate => 'Inappropriate content';

  @override
  String get reasonOther => 'Other problem';

  @override
  String shareHeader(int day, String title) {
    return 'Case of the Day #$day · $title';
  }

  @override
  String shareHeaderLevel(int day, String level, String title) {
    return 'Case of the Day #$day · $level · $title';
  }

  @override
  String shareSummary(int hints, String result) {
    return 'Lab reports: $hints · $result';
  }

  @override
  String get shareDismissed => 'dismissed';

  @override
  String shareStreak(int streak) {
    return 'streak $streak';
  }

  @override
  String get errorNotFound => 'Case not found.';

  @override
  String get errorNoCases => 'No cases in the file.';

  @override
  String get errorCaseClosed =>
      'This case is already closed. A new one starts at midnight.';

  @override
  String get errorCaseFinished => 'This case is already finished.';

  @override
  String get errorInvalidChoice =>
      'Invalid choice. Refresh the case and try again.';

  @override
  String get errorNotFinished =>
      'You can only rate a case you have played to the end.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Restart the app.';

  @override
  String get errorAccountLink => 'Couldn\'t connect the player account.';

  @override
  String get errorOffline =>
      'No connection to the server. Check your internet and try again.';

  @override
  String get errorServer => 'Server error. Try again in a moment.';

  @override
  String get errorUnknown => 'Something went wrong. Try again.';

  @override
  String get errorOpenCase => 'Couldn\'t open the case.';

  @override
  String ageGateTitle(int age) {
    return '$age+ ONLY';
  }

  @override
  String ageGateBody(int age) {
    return 'The cases describe crimes, sometimes in a dark tone. You must be at least $age to play.';
  }

  @override
  String get ageGateAsk => 'Enter your date of birth';

  @override
  String get ageGatePrivacy =>
      'We don\'t store your date of birth, only whether you can play.';

  @override
  String get ageGatePickerHelp => 'DATE OF BIRTH';

  @override
  String get ageDeniedTitle => 'NOT YET';

  @override
  String ageDeniedBody(int age) {
    return 'Case of the Day is for people aged $age and over. Come back when you turn $age.';
  }

  @override
  String get globalTitle => 'PLAYERS';

  @override
  String globalSolved(int pct, int players) {
    return 'Solved by $pct% of $players players';
  }

  @override
  String globalAvgAttempts(String value) {
    return 'Average attempts among solvers: $value';
  }

  @override
  String globalTopCulprit(String name, int pct) {
    return 'Most common first pick: $name ($pct%)';
  }

  @override
  String globalTooFew(int min) {
    return 'Stats will appear once at least $min players have finished the case.';
  }

  @override
  String tomorrowTeaser(String title, String place, String date) {
    return 'Tomorrow: $title · $place, $date';
  }

  @override
  String get chooseLanguageTitle => 'CHOOSE A LANGUAGE';

  @override
  String get chooseLanguageBody =>
      'You can change it at any time with the icon at the top of the case screen.';

  @override
  String get languageTooltip => 'Language';

  @override
  String get untranslatedNote =>
      'Cases that haven\'t been translated yet are shown in Polish.';
}
