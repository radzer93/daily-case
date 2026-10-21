import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('pl')];

  /// No description provided for @appTitle.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa Dnia'**
  String get appTitle;

  /// No description provided for @appBarTitle.
  ///
  /// In pl, this message translates to:
  /// **'SPRAWA DNIA'**
  String get appBarTitle;

  /// No description provided for @caseNumber.
  ///
  /// In pl, this message translates to:
  /// **'nr {number}'**
  String caseNumber(int number);

  /// No description provided for @archive.
  ///
  /// In pl, this message translates to:
  /// **'Archiwum'**
  String get archive;

  /// No description provided for @retry.
  ///
  /// In pl, this message translates to:
  /// **'Spróbuj ponownie'**
  String get retry;

  /// No description provided for @statusErrorTitle.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z archiwum'**
  String get statusErrorTitle;

  /// No description provided for @statusEmptyTitle.
  ///
  /// In pl, this message translates to:
  /// **'Akta jeszcze nie dotarły'**
  String get statusEmptyTitle;

  /// No description provided for @statusEmptyBody.
  ///
  /// In pl, this message translates to:
  /// **'Dzisiejsza sprawa na poziomie {level} jest w drodze. Zajrzyj za chwilę, wybierz inny poziom albo przejrzyj zamknięte sprawy.'**
  String statusEmptyBody(String level);

  /// No description provided for @tabBrief.
  ///
  /// In pl, this message translates to:
  /// **'AKTA'**
  String get tabBrief;

  /// No description provided for @tabEvidence.
  ///
  /// In pl, this message translates to:
  /// **'DOWODY {visible}/{total}'**
  String tabEvidence(int visible, int total);

  /// No description provided for @tabStatements.
  ///
  /// In pl, this message translates to:
  /// **'ZEZNANIA {count}'**
  String tabStatements(int count);

  /// No description provided for @tabAccusation.
  ///
  /// In pl, this message translates to:
  /// **'OSKARŻENIE {attempts}×'**
  String tabAccusation(int attempts);

  /// No description provided for @tabVerdict.
  ///
  /// In pl, this message translates to:
  /// **'WERDYKT'**
  String get tabVerdict;

  /// No description provided for @tabSolution.
  ///
  /// In pl, this message translates to:
  /// **'ROZWIĄZANIE'**
  String get tabSolution;

  /// No description provided for @tapeScene.
  ///
  /// In pl, this message translates to:
  /// **'Miejsce zdarzenia'**
  String get tapeScene;

  /// No description provided for @tapeDoNotCross.
  ///
  /// In pl, this message translates to:
  /// **'Nie przekraczać'**
  String get tapeDoNotCross;

  /// No description provided for @tapePolice.
  ///
  /// In pl, this message translates to:
  /// **'Policja'**
  String get tapePolice;

  /// No description provided for @tapeDocket.
  ///
  /// In pl, this message translates to:
  /// **'Sygn. {docket}'**
  String tapeDocket(String docket);

  /// No description provided for @howToTitle.
  ///
  /// In pl, this message translates to:
  /// **'JAK PROWADZIĆ SPRAWĘ'**
  String get howToTitle;

  /// No description provided for @howToBody.
  ///
  /// In pl, this message translates to:
  /// **'Przeczytaj dowody i zeznania. Wskaż sprawcę, motyw i dowód, który go pogrąża. Masz {attempts} próby, po każdej zobaczysz, co trafiłeś. Ekspertyzy odsłaniają dodatkowe dowody, ale kosztują punkty. Sprawa przepada o północy, a rozwiązanie odtajniamy następnego dnia.'**
  String howToBody(int attempts);

  /// No description provided for @openEvidence.
  ///
  /// In pl, this message translates to:
  /// **'Otwórz dowody'**
  String get openEvidence;

  /// No description provided for @goToStatements.
  ///
  /// In pl, this message translates to:
  /// **'Przejdź do zeznań'**
  String get goToStatements;

  /// No description provided for @seeSolution.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz rozwiązanie'**
  String get seeSolution;

  /// No description provided for @seeVerdict.
  ///
  /// In pl, this message translates to:
  /// **'Zobacz werdykt'**
  String get seeVerdict;

  /// No description provided for @makeAccusation.
  ///
  /// In pl, this message translates to:
  /// **'Wnieś oskarżenie'**
  String get makeAccusation;

  /// No description provided for @accusationIncomplete.
  ///
  /// In pl, this message translates to:
  /// **'Wskaż sprawcę, motyw i dowód.'**
  String get accusationIncomplete;

  /// No description provided for @groupCulprit.
  ///
  /// In pl, this message translates to:
  /// **'Sprawca'**
  String get groupCulprit;

  /// No description provided for @groupMotive.
  ///
  /// In pl, this message translates to:
  /// **'Motyw'**
  String get groupMotive;

  /// No description provided for @groupEvidence.
  ///
  /// In pl, this message translates to:
  /// **'Dowód, który go pogrąża'**
  String get groupEvidence;

  /// No description provided for @sending.
  ///
  /// In pl, this message translates to:
  /// **'Wysyłanie…'**
  String get sending;

  /// No description provided for @submitAccusation.
  ///
  /// In pl, this message translates to:
  /// **'Złóż akt oskarżenia'**
  String get submitAccusation;

  /// No description provided for @attemptsLeft.
  ///
  /// In pl, this message translates to:
  /// **'{count, plural, one{{count} próba} few{{count} próby} many{{count} prób} other{{count} próby}} · ekspertyzy: {hints}'**
  String attemptsLeft(int count, int hints);

  /// No description provided for @archiveTitle.
  ///
  /// In pl, this message translates to:
  /// **'ARCHIWUM'**
  String get archiveTitle;

  /// No description provided for @archiveLoadFailed.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się wczytać archiwum.'**
  String get archiveLoadFailed;

  /// No description provided for @archiveEmpty.
  ///
  /// In pl, this message translates to:
  /// **'Archiwum jest jeszcze puste. Pierwsza sprawa trafi tu jutro, razem z rozwiązaniem.'**
  String get archiveEmpty;

  /// No description provided for @archiveIntro.
  ///
  /// In pl, this message translates to:
  /// **'Sprawy z poprzednich dni. Rozwiązania są już jawne.'**
  String get archiveIntro;

  /// No description provided for @archiveClosed.
  ///
  /// In pl, this message translates to:
  /// **'ZAMKNIĘTA'**
  String get archiveClosed;

  /// No description provided for @archiveDismissed.
  ///
  /// In pl, this message translates to:
  /// **'UMORZONA'**
  String get archiveDismissed;

  /// No description provided for @archiveLapsed.
  ///
  /// In pl, this message translates to:
  /// **'PRZEPADŁA'**
  String get archiveLapsed;

  /// No description provided for @archiveUntouched.
  ///
  /// In pl, this message translates to:
  /// **'BEZ ŚLEDZTWA'**
  String get archiveUntouched;

  /// No description provided for @levelEasy.
  ///
  /// In pl, this message translates to:
  /// **'Łatwa'**
  String get levelEasy;

  /// No description provided for @levelMedium.
  ///
  /// In pl, this message translates to:
  /// **'Średnia'**
  String get levelMedium;

  /// No description provided for @levelHard.
  ///
  /// In pl, this message translates to:
  /// **'Trudna'**
  String get levelHard;

  /// No description provided for @levelEasyDescription.
  ///
  /// In pl, this message translates to:
  /// **'3 podejrzanych, jeden wyraźny trop.'**
  String get levelEasyDescription;

  /// No description provided for @levelMediumDescription.
  ///
  /// In pl, this message translates to:
  /// **'4 podejrzanych, trop ukryty w szczegółach.'**
  String get levelMediumDescription;

  /// No description provided for @levelHardDescription.
  ///
  /// In pl, this message translates to:
  /// **'4 podejrzanych, mylne poszlaki, dwa tropy do połączenia.'**
  String get levelHardDescription;

  /// No description provided for @levelMultiplier.
  ///
  /// In pl, this message translates to:
  /// **'×{value} pkt'**
  String levelMultiplier(String value);

  /// No description provided for @chooseLevelTitle.
  ///
  /// In pl, this message translates to:
  /// **'WYBIERZ POZIOM'**
  String get chooseLevelTitle;

  /// No description provided for @chooseLevelBody.
  ///
  /// In pl, this message translates to:
  /// **'Każdego dnia czekają trzy sprawy, po jednej na poziom. Poziom zmienisz w każdej chwili na ekranie sprawy.'**
  String get chooseLevelBody;

  /// No description provided for @kindFictional.
  ///
  /// In pl, this message translates to:
  /// **'fikcyjna'**
  String get kindFictional;

  /// No description provided for @kindInspired.
  ///
  /// In pl, this message translates to:
  /// **'inspirowana'**
  String get kindInspired;

  /// No description provided for @kindFictionalBadge.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa fikcyjna'**
  String get kindFictionalBadge;

  /// No description provided for @kindInspiredBadge.
  ///
  /// In pl, this message translates to:
  /// **'Inspirowana prawdziwą sprawą'**
  String get kindInspiredBadge;

  /// No description provided for @streakSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Seria rozwiązanych spraw dnia: {streak}'**
  String streakSemantics(int streak);

  /// No description provided for @streakChip.
  ///
  /// In pl, this message translates to:
  /// **'SERIA {streak}'**
  String streakChip(int streak);

  /// No description provided for @docketLabel.
  ///
  /// In pl, this message translates to:
  /// **'SYGN. AKT {docket}'**
  String docketLabel(String docket);

  /// No description provided for @levelBadge.
  ///
  /// In pl, this message translates to:
  /// **'POZIOM: {level}'**
  String levelBadge(String level);

  /// No description provided for @archivedCaseNote.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa z archiwum. Rozwiązanie jest jawne.'**
  String get archivedCaseNote;

  /// No description provided for @dailyCase.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa dnia'**
  String get dailyCase;

  /// No description provided for @evidenceNumber.
  ///
  /// In pl, this message translates to:
  /// **'DOWÓD NR {number}'**
  String evidenceNumber(int number);

  /// No description provided for @evidenceRestricted.
  ///
  /// In pl, this message translates to:
  /// **'ZASTRZEŻONE'**
  String get evidenceRestricted;

  /// No description provided for @evidenceExpertise.
  ///
  /// In pl, this message translates to:
  /// **'EKSPERTYZA'**
  String get evidenceExpertise;

  /// No description provided for @requestExpertise.
  ///
  /// In pl, this message translates to:
  /// **'Zleć ekspertyzę · −{cost} pkt'**
  String requestExpertise(int cost);

  /// No description provided for @interrogationRecord.
  ///
  /// In pl, this message translates to:
  /// **'PROTOKÓŁ PRZESŁUCHANIA'**
  String get interrogationRecord;

  /// No description provided for @suspectAgeRole.
  ///
  /// In pl, this message translates to:
  /// **'{age} l., {role}'**
  String suspectAgeRole(int age, String role);

  /// No description provided for @quoted.
  ///
  /// In pl, this message translates to:
  /// **'„{text}”'**
  String quoted(String text);

  /// No description provided for @excludedUndo.
  ///
  /// In pl, this message translates to:
  /// **'Wykluczony · cofnij'**
  String get excludedUndo;

  /// No description provided for @excludeSuspect.
  ///
  /// In pl, this message translates to:
  /// **'Wyklucz z podejrzeń'**
  String get excludeSuspect;

  /// No description provided for @cellCulprit.
  ///
  /// In pl, this message translates to:
  /// **'SPRAWCA'**
  String get cellCulprit;

  /// No description provided for @cellMotive.
  ///
  /// In pl, this message translates to:
  /// **'MOTYW'**
  String get cellMotive;

  /// No description provided for @cellEvidence.
  ///
  /// In pl, this message translates to:
  /// **'DOWÓD'**
  String get cellEvidence;

  /// No description provided for @cellHit.
  ///
  /// In pl, this message translates to:
  /// **'{label}: {value}, trafione'**
  String cellHit(String label, String value);

  /// No description provided for @cellMiss.
  ///
  /// In pl, this message translates to:
  /// **'{label}: {value}, chybione'**
  String cellMiss(String label, String value);

  /// No description provided for @levelSemantics.
  ///
  /// In pl, this message translates to:
  /// **'Poziom {level}'**
  String levelSemantics(String level);

  /// No description provided for @levelSemanticsSolved.
  ///
  /// In pl, this message translates to:
  /// **'Poziom {level}, rozwiązana'**
  String levelSemanticsSolved(String level);

  /// No description provided for @stampClosed.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa zamknięta'**
  String get stampClosed;

  /// No description provided for @stampDismissed.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa umorzona'**
  String get stampDismissed;

  /// No description provided for @stampLapsed.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa przepadła'**
  String get stampLapsed;

  /// No description provided for @stampOpen.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa w toku'**
  String get stampOpen;

  /// No description provided for @points.
  ///
  /// In pl, this message translates to:
  /// **'{score} pkt'**
  String points(int score);

  /// No description provided for @verdictWon.
  ///
  /// In pl, this message translates to:
  /// **'Prokurator przyjmuje akt oskarżenia. Wynik: {result}.'**
  String verdictWon(String result);

  /// No description provided for @verdictDismissedPending.
  ///
  /// In pl, this message translates to:
  /// **'Trzy chybione oskarżenia. Rozwiązanie odtajnimy jutro po północy.'**
  String get verdictDismissedPending;

  /// No description provided for @verdictDismissed.
  ///
  /// In pl, this message translates to:
  /// **'Trzy chybione oskarżenia. Sprawcą był(a) {name}.'**
  String verdictDismissed(String name);

  /// No description provided for @verdictLapsedUntouched.
  ///
  /// In pl, this message translates to:
  /// **'Ta sprawa minęła bez Twojego śledztwa.'**
  String get verdictLapsedUntouched;

  /// No description provided for @verdictLapsedLate.
  ///
  /// In pl, this message translates to:
  /// **'Północ minęła przed rozwiązaniem.'**
  String get verdictLapsedLate;

  /// No description provided for @verdictCulprit.
  ///
  /// In pl, this message translates to:
  /// **'Sprawcą był(a) {name}.'**
  String verdictCulprit(String name);

  /// No description provided for @verdictOpen.
  ///
  /// In pl, this message translates to:
  /// **'Wróć do sprawy dnia, żeby ją rozwiązać.'**
  String get verdictOpen;

  /// No description provided for @statPlayed.
  ///
  /// In pl, this message translates to:
  /// **'Spraw dnia'**
  String get statPlayed;

  /// No description provided for @statWinRate.
  ///
  /// In pl, this message translates to:
  /// **'Rozwiązanych'**
  String get statWinRate;

  /// No description provided for @statStreak.
  ///
  /// In pl, this message translates to:
  /// **'Seria'**
  String get statStreak;

  /// No description provided for @statBest.
  ///
  /// In pl, this message translates to:
  /// **'Najdłuższa'**
  String get statBest;

  /// No description provided for @solutionPending.
  ///
  /// In pl, this message translates to:
  /// **'Akta z rozwiązaniem odtajnimy po północy. Wróć jutro: w archiwum zobaczysz, kto to zrobił i dlaczego.'**
  String get solutionPending;

  /// No description provided for @nextCaseIn.
  ///
  /// In pl, this message translates to:
  /// **'Następna sprawa za {time}'**
  String nextCaseIn(String time);

  /// No description provided for @shareResult.
  ///
  /// In pl, this message translates to:
  /// **'Udostępnij wynik'**
  String get shareResult;

  /// No description provided for @copy.
  ///
  /// In pl, this message translates to:
  /// **'Kopiuj'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In pl, this message translates to:
  /// **'Wynik skopiowany'**
  String get copied;

  /// No description provided for @feedbackQuestion.
  ///
  /// In pl, this message translates to:
  /// **'JAK OCENIASZ TĘ SPRAWĘ?'**
  String get feedbackQuestion;

  /// No description provided for @ratingTooltip.
  ///
  /// In pl, this message translates to:
  /// **'Ocena {rating} z {max}'**
  String ratingTooltip(int rating, int max);

  /// No description provided for @feedbackThanksRating.
  ///
  /// In pl, this message translates to:
  /// **'Dziękujemy za ocenę.'**
  String get feedbackThanksRating;

  /// No description provided for @feedbackSheetTitle.
  ///
  /// In pl, this message translates to:
  /// **'Co jest nie tak z tą sprawą?'**
  String get feedbackSheetTitle;

  /// No description provided for @feedbackThanksReport.
  ///
  /// In pl, this message translates to:
  /// **'Dziękujemy. Sprawdzimy tę sprawę.'**
  String get feedbackThanksReport;

  /// No description provided for @feedbackReported.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoszenie przyjęte. Dziękujemy.'**
  String get feedbackReported;

  /// No description provided for @reportProblem.
  ///
  /// In pl, this message translates to:
  /// **'Zgłoś błąd w sprawie'**
  String get reportProblem;

  /// No description provided for @reasonUnfair.
  ///
  /// In pl, this message translates to:
  /// **'Nie da się tego rozwiązać bez zgadywania'**
  String get reasonUnfair;

  /// No description provided for @reasonContradiction.
  ///
  /// In pl, this message translates to:
  /// **'Sprzeczność w aktach lub rozwiązaniu'**
  String get reasonContradiction;

  /// No description provided for @reasonLanguage.
  ///
  /// In pl, this message translates to:
  /// **'Błędy językowe'**
  String get reasonLanguage;

  /// No description provided for @reasonInappropriate.
  ///
  /// In pl, this message translates to:
  /// **'Nieodpowiednie treści'**
  String get reasonInappropriate;

  /// No description provided for @reasonOther.
  ///
  /// In pl, this message translates to:
  /// **'Inny problem'**
  String get reasonOther;

  /// No description provided for @shareHeader.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa Dnia #{day} · {title}'**
  String shareHeader(int day, String title);

  /// No description provided for @shareHeaderLevel.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa Dnia #{day} · {level} · {title}'**
  String shareHeaderLevel(int day, String level, String title);

  /// No description provided for @shareSummary.
  ///
  /// In pl, this message translates to:
  /// **'Ekspertyzy: {hints} · {result}'**
  String shareSummary(int hints, String result);

  /// No description provided for @shareDismissed.
  ///
  /// In pl, this message translates to:
  /// **'umorzona'**
  String get shareDismissed;

  /// No description provided for @shareStreak.
  ///
  /// In pl, this message translates to:
  /// **'seria {streak}'**
  String shareStreak(int streak);

  /// No description provided for @errorNotFound.
  ///
  /// In pl, this message translates to:
  /// **'Nie znaleziono sprawy.'**
  String get errorNotFound;

  /// No description provided for @errorNoCases.
  ///
  /// In pl, this message translates to:
  /// **'Brak spraw w pliku.'**
  String get errorNoCases;

  /// No description provided for @errorCaseClosed.
  ///
  /// In pl, this message translates to:
  /// **'Ta sprawa jest już zamknięta. Po północy czeka nowa.'**
  String get errorCaseClosed;

  /// No description provided for @errorCaseFinished.
  ///
  /// In pl, this message translates to:
  /// **'Ta sprawa jest już zakończona.'**
  String get errorCaseFinished;

  /// No description provided for @errorInvalidChoice.
  ///
  /// In pl, this message translates to:
  /// **'Nieprawidłowy wybór. Odśwież sprawę i spróbuj ponownie.'**
  String get errorInvalidChoice;

  /// No description provided for @errorNotFinished.
  ///
  /// In pl, this message translates to:
  /// **'Ocenić można tylko sprawę, którą prowadziłeś do końca.'**
  String get errorNotFinished;

  /// No description provided for @errorSessionExpired.
  ///
  /// In pl, this message translates to:
  /// **'Sesja wygasła. Uruchom aplikację ponownie.'**
  String get errorSessionExpired;

  /// No description provided for @errorAccountLink.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się połączyć konta gracza.'**
  String get errorAccountLink;

  /// No description provided for @errorOffline.
  ///
  /// In pl, this message translates to:
  /// **'Brak połączenia z serwerem. Sprawdź internet i spróbuj ponownie.'**
  String get errorOffline;

  /// No description provided for @errorServer.
  ///
  /// In pl, this message translates to:
  /// **'Błąd serwera. Spróbuj ponownie za chwilę.'**
  String get errorServer;

  /// No description provided for @errorUnknown.
  ///
  /// In pl, this message translates to:
  /// **'Coś poszło nie tak. Spróbuj ponownie.'**
  String get errorUnknown;

  /// No description provided for @errorOpenCase.
  ///
  /// In pl, this message translates to:
  /// **'Nie udało się otworzyć sprawy.'**
  String get errorOpenCase;

  /// No description provided for @ageGateTitle.
  ///
  /// In pl, this message translates to:
  /// **'TYLKO DLA OSÓB {age}+'**
  String ageGateTitle(int age);

  /// No description provided for @ageGateBody.
  ///
  /// In pl, this message translates to:
  /// **'Sprawy opisują zbrodnie, czasem w mrocznym tonie. Aby grać, musisz mieć ukończone {age} lat.'**
  String ageGateBody(int age);

  /// No description provided for @ageGateAsk.
  ///
  /// In pl, this message translates to:
  /// **'Podaj datę urodzenia'**
  String get ageGateAsk;

  /// No description provided for @ageGatePrivacy.
  ///
  /// In pl, this message translates to:
  /// **'Nie zapisujemy daty urodzenia, tylko informację, czy możesz grać.'**
  String get ageGatePrivacy;

  /// No description provided for @ageGatePickerHelp.
  ///
  /// In pl, this message translates to:
  /// **'DATA URODZENIA'**
  String get ageGatePickerHelp;

  /// No description provided for @ageDeniedTitle.
  ///
  /// In pl, this message translates to:
  /// **'JESZCZE NIE TERAZ'**
  String get ageDeniedTitle;

  /// No description provided for @ageDeniedBody.
  ///
  /// In pl, this message translates to:
  /// **'Sprawa Dnia jest przeznaczona dla osób, które ukończyły {age} lat. Wróć do nas, gdy skończysz {age} lat.'**
  String ageDeniedBody(int age);

  /// No description provided for @globalTitle.
  ///
  /// In pl, this message translates to:
  /// **'GRACZE'**
  String get globalTitle;

  /// No description provided for @globalSolved.
  ///
  /// In pl, this message translates to:
  /// **'Rozwiązało {pct}% z {players} graczy'**
  String globalSolved(int pct, int players);

  /// No description provided for @globalAvgAttempts.
  ///
  /// In pl, this message translates to:
  /// **'Średnia liczba prób u rozwiązujących: {value}'**
  String globalAvgAttempts(String value);

  /// No description provided for @globalTopCulprit.
  ///
  /// In pl, this message translates to:
  /// **'Najczęstszy pierwszy wybór: {name} ({pct}%)'**
  String globalTopCulprit(String name, int pct);

  /// No description provided for @globalTooFew.
  ///
  /// In pl, this message translates to:
  /// **'Statystyki pojawią się, gdy sprawę zakończy co najmniej {min} graczy.'**
  String globalTooFew(int min);

  /// No description provided for @tomorrowTeaser.
  ///
  /// In pl, this message translates to:
  /// **'Jutro: {title} · {place}, {date}'**
  String tomorrowTeaser(String title, String place, String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
