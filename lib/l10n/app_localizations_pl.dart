// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Sprawa Dnia';

  @override
  String get appBarTitle => 'SPRAWA DNIA';

  @override
  String caseNumber(int number) {
    return 'nr $number';
  }

  @override
  String get archive => 'Archiwum';

  @override
  String get retry => 'Spróbuj ponownie';

  @override
  String get statusErrorTitle => 'Brak połączenia z archiwum';

  @override
  String get statusEmptyTitle => 'Akta jeszcze nie dotarły';

  @override
  String statusEmptyBody(String level) {
    return 'Dzisiejsza sprawa na poziomie $level jest w drodze. Zajrzyj za chwilę, wybierz inny poziom albo przejrzyj zamknięte sprawy.';
  }

  @override
  String get tabBrief => 'AKTA';

  @override
  String tabEvidence(int visible, int total) {
    return 'DOWODY $visible/$total';
  }

  @override
  String tabStatements(int count) {
    return 'ZEZNANIA $count';
  }

  @override
  String tabAccusation(int attempts) {
    return 'OSKARŻENIE $attempts×';
  }

  @override
  String get tabVerdict => 'WERDYKT';

  @override
  String get tabSolution => 'ROZWIĄZANIE';

  @override
  String get tapeScene => 'Miejsce zdarzenia';

  @override
  String get tapeDoNotCross => 'Nie przekraczać';

  @override
  String get tapePolice => 'Policja';

  @override
  String tapeDocket(String docket) {
    return 'Sygn. $docket';
  }

  @override
  String get howToTitle => 'JAK PROWADZIĆ SPRAWĘ';

  @override
  String howToBody(int attempts) {
    return 'Przeczytaj dowody i zeznania. Wskaż sprawcę, motyw i dowód, który go pogrąża. Masz $attempts próby, po każdej zobaczysz, co trafiłeś. Ekspertyzy odsłaniają dodatkowe dowody, ale kosztują punkty. Sprawa przepada o północy, a rozwiązanie odtajniamy następnego dnia.';
  }

  @override
  String get openEvidence => 'Otwórz dowody';

  @override
  String get goToStatements => 'Przejdź do zeznań';

  @override
  String get seeSolution => 'Zobacz rozwiązanie';

  @override
  String get seeVerdict => 'Zobacz werdykt';

  @override
  String get makeAccusation => 'Wnieś oskarżenie';

  @override
  String get accusationIncomplete => 'Wskaż sprawcę, motyw i dowód.';

  @override
  String get groupCulprit => 'Sprawca';

  @override
  String get groupMotive => 'Motyw';

  @override
  String get groupEvidence => 'Dowód, który go pogrąża';

  @override
  String get sending => 'Wysyłanie…';

  @override
  String get submitAccusation => 'Złóż akt oskarżenia';

  @override
  String attemptsLeft(int count, int hints) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count próby',
      many: '$count prób',
      few: '$count próby',
      one: '$count próba',
    );
    return '$_temp0 · ekspertyzy: $hints';
  }

  @override
  String get archiveTitle => 'ARCHIWUM';

  @override
  String get archiveLoadFailed => 'Nie udało się wczytać archiwum.';

  @override
  String get archiveEmpty =>
      'Archiwum jest jeszcze puste. Pierwsza sprawa trafi tu jutro, razem z rozwiązaniem.';

  @override
  String get archiveIntro =>
      'Sprawy z poprzednich dni. Rozwiązania są już jawne.';

  @override
  String get archiveClosed => 'ZAMKNIĘTA';

  @override
  String get archiveDismissed => 'UMORZONA';

  @override
  String get archiveLapsed => 'PRZEPADŁA';

  @override
  String get archiveUntouched => 'BEZ ŚLEDZTWA';

  @override
  String get levelEasy => 'Łatwa';

  @override
  String get levelMedium => 'Średnia';

  @override
  String get levelHard => 'Trudna';

  @override
  String get levelEasyDescription => '3 podejrzanych, jeden wyraźny trop.';

  @override
  String get levelMediumDescription =>
      '4 podejrzanych, trop ukryty w szczegółach.';

  @override
  String get levelHardDescription =>
      '4 podejrzanych, mylne poszlaki, dwa tropy do połączenia.';

  @override
  String levelMultiplier(String value) {
    return '×$value pkt';
  }

  @override
  String get chooseLevelTitle => 'WYBIERZ POZIOM';

  @override
  String get chooseLevelBody =>
      'Każdego dnia czekają trzy sprawy, po jednej na poziom. Poziom zmienisz w każdej chwili na ekranie sprawy.';

  @override
  String get kindFictional => 'fikcyjna';

  @override
  String get kindInspired => 'inspirowana';

  @override
  String get kindFictionalBadge => 'Sprawa fikcyjna';

  @override
  String get kindInspiredBadge => 'Inspirowana prawdziwą sprawą';

  @override
  String streakSemantics(int streak) {
    return 'Seria rozwiązanych spraw dnia: $streak';
  }

  @override
  String streakChip(int streak) {
    return 'SERIA $streak';
  }

  @override
  String docketLabel(String docket) {
    return 'SYGN. AKT $docket';
  }

  @override
  String levelBadge(String level) {
    return 'POZIOM: $level';
  }

  @override
  String get archivedCaseNote => 'Sprawa z archiwum. Rozwiązanie jest jawne.';

  @override
  String get dailyCase => 'Sprawa dnia';

  @override
  String evidenceNumber(int number) {
    return 'DOWÓD NR $number';
  }

  @override
  String get evidenceRestricted => 'ZASTRZEŻONE';

  @override
  String get evidenceExpertise => 'EKSPERTYZA';

  @override
  String requestExpertise(int cost) {
    return 'Zleć ekspertyzę · −$cost pkt';
  }

  @override
  String get interrogationRecord => 'PROTOKÓŁ PRZESŁUCHANIA';

  @override
  String suspectAgeRole(int age, String role) {
    return '$age l., $role';
  }

  @override
  String quoted(String text) {
    return '„$text”';
  }

  @override
  String get excludedUndo => 'Wykluczony · cofnij';

  @override
  String get excludeSuspect => 'Wyklucz z podejrzeń';

  @override
  String get cellCulprit => 'SPRAWCA';

  @override
  String get cellMotive => 'MOTYW';

  @override
  String get cellEvidence => 'DOWÓD';

  @override
  String cellHit(String label, String value) {
    return '$label: $value, trafione';
  }

  @override
  String cellMiss(String label, String value) {
    return '$label: $value, chybione';
  }

  @override
  String levelSemantics(String level) {
    return 'Poziom $level';
  }

  @override
  String levelSemanticsSolved(String level) {
    return 'Poziom $level, rozwiązana';
  }

  @override
  String get stampClosed => 'Sprawa zamknięta';

  @override
  String get stampDismissed => 'Sprawa umorzona';

  @override
  String get stampLapsed => 'Sprawa przepadła';

  @override
  String get stampOpen => 'Sprawa w toku';

  @override
  String points(int score) {
    return '$score pkt';
  }

  @override
  String verdictWon(String result) {
    return 'Prokurator przyjmuje akt oskarżenia. Wynik: $result.';
  }

  @override
  String get verdictDismissedPending =>
      'Trzy chybione oskarżenia. Rozwiązanie odtajnimy jutro po północy.';

  @override
  String verdictDismissed(String name) {
    return 'Trzy chybione oskarżenia. Sprawcą był(a) $name.';
  }

  @override
  String get verdictLapsedUntouched => 'Ta sprawa minęła bez Twojego śledztwa.';

  @override
  String get verdictLapsedLate => 'Północ minęła przed rozwiązaniem.';

  @override
  String verdictCulprit(String name) {
    return 'Sprawcą był(a) $name.';
  }

  @override
  String get verdictOpen => 'Wróć do sprawy dnia, żeby ją rozwiązać.';

  @override
  String get statPlayed => 'Spraw dnia';

  @override
  String get statWinRate => 'Rozwiązanych';

  @override
  String get statStreak => 'Seria';

  @override
  String get statBest => 'Najdłuższa';

  @override
  String get solutionPending =>
      'Akta z rozwiązaniem odtajnimy po północy. Wróć jutro: w archiwum zobaczysz, kto to zrobił i dlaczego.';

  @override
  String nextCaseIn(String time) {
    return 'Następna sprawa za $time';
  }

  @override
  String get shareResult => 'Udostępnij wynik';

  @override
  String get copy => 'Kopiuj';

  @override
  String get copied => 'Wynik skopiowany';

  @override
  String get feedbackQuestion => 'JAK OCENIASZ TĘ SPRAWĘ?';

  @override
  String ratingTooltip(int rating, int max) {
    return 'Ocena $rating z $max';
  }

  @override
  String get feedbackThanksRating => 'Dziękujemy za ocenę.';

  @override
  String get feedbackSheetTitle => 'Co jest nie tak z tą sprawą?';

  @override
  String get feedbackThanksReport => 'Dziękujemy. Sprawdzimy tę sprawę.';

  @override
  String get feedbackReported => 'Zgłoszenie przyjęte. Dziękujemy.';

  @override
  String get reportProblem => 'Zgłoś błąd w sprawie';

  @override
  String get reasonUnfair => 'Nie da się tego rozwiązać bez zgadywania';

  @override
  String get reasonContradiction => 'Sprzeczność w aktach lub rozwiązaniu';

  @override
  String get reasonLanguage => 'Błędy językowe';

  @override
  String get reasonInappropriate => 'Nieodpowiednie treści';

  @override
  String get reasonOther => 'Inny problem';

  @override
  String shareHeader(int day, String title) {
    return 'Sprawa Dnia #$day · $title';
  }

  @override
  String shareHeaderLevel(int day, String level, String title) {
    return 'Sprawa Dnia #$day · $level · $title';
  }

  @override
  String shareSummary(int hints, String result) {
    return 'Ekspertyzy: $hints · $result';
  }

  @override
  String get shareDismissed => 'umorzona';

  @override
  String shareStreak(int streak) {
    return 'seria $streak';
  }

  @override
  String get errorNotFound => 'Nie znaleziono sprawy.';

  @override
  String get errorNoCases => 'Brak spraw w pliku.';

  @override
  String get errorCaseClosed =>
      'Ta sprawa jest już zamknięta. Po północy czeka nowa.';

  @override
  String get errorCaseFinished => 'Ta sprawa jest już zakończona.';

  @override
  String get errorInvalidChoice =>
      'Nieprawidłowy wybór. Odśwież sprawę i spróbuj ponownie.';

  @override
  String get errorNotFinished =>
      'Ocenić można tylko sprawę, którą prowadziłeś do końca.';

  @override
  String get errorSessionExpired =>
      'Sesja wygasła. Uruchom aplikację ponownie.';

  @override
  String get errorAccountLink => 'Nie udało się połączyć konta gracza.';

  @override
  String get errorOffline =>
      'Brak połączenia z serwerem. Sprawdź internet i spróbuj ponownie.';

  @override
  String get errorServer => 'Błąd serwera. Spróbuj ponownie za chwilę.';

  @override
  String get errorUnknown => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get errorOpenCase => 'Nie udało się otworzyć sprawy.';

  @override
  String ageGateTitle(int age) {
    return 'TYLKO DLA OSÓB $age+';
  }

  @override
  String ageGateBody(int age) {
    return 'Sprawy opisują zbrodnie, czasem w mrocznym tonie. Aby grać, musisz mieć ukończone $age lat.';
  }

  @override
  String get ageGateAsk => 'Podaj datę urodzenia';

  @override
  String get ageGatePrivacy =>
      'Nie zapisujemy daty urodzenia, tylko informację, czy możesz grać.';

  @override
  String get ageGatePickerHelp => 'DATA URODZENIA';

  @override
  String get ageDeniedTitle => 'JESZCZE NIE TERAZ';

  @override
  String ageDeniedBody(int age) {
    return 'Sprawa Dnia jest przeznaczona dla osób, które ukończyły $age lat. Wróć do nas, gdy skończysz $age lat.';
  }
}
