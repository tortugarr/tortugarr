// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian Bokmål (`nb`).
class AppLocalizationsNb extends AppLocalizations {
  AppLocalizationsNb([String locale = 'nb']) : super(locale);

  @override
  String get appTitle => 'Tortugarr';

  @override
  String get animeMarkerFiller => 'Filler';

  @override
  String get animeMarkerMixed => 'Blandet';

  @override
  String get animeMarkerAnimeCanon => 'Anime-kanon';

  @override
  String get animeMarkerMangaCanon => 'Manga-kanon';

  @override
  String get animeMarkerSubbed => 'Tekstet';

  @override
  String get animeMarkerDubbed => 'Dubbet';

  @override
  String get animeMarkerSubbedAndDubbed => 'Tekstet/dubbet';

  @override
  String get animeMarkerPending => 'Venter';

  @override
  String get animeMarkerRecap => 'Oppsummering';

  @override
  String get interfaceLanguage => 'Grensesnittspråk';

  @override
  String get systemLanguageDefault => 'Systemstandard';

  @override
  String get signIn => 'Logg på';

  @override
  String get empty => 'Tom';

  @override
  String connectingToServer(String serverName) {
    return 'Kobler til $serverName';
  }

  @override
  String get quickConnect => 'Hurtigkobling';

  @override
  String get password => 'Passord';

  @override
  String get username => 'Brukernavn';

  @override
  String get email => 'E-post';

  @override
  String get quickConnectInstruction =>
      'Skriv inn denne koden på serverens nettdashbord:';

  @override
  String get quickConnectScanHint =>
      'Eller skann denne med en telefon som er logget inn på serveren din';

  @override
  String get quickConnectTapOrScanHint =>
      'Trykk for å godkjenne i nettleseren, eller skann denne med en annen enhet';

  @override
  String get timesUpTitle => 'Tiden er ute';

  @override
  String get timesUpMessage => 'Denne kontoen er ikke tilgjengelig akkurat nå.';

  @override
  String timesUpResumesToday(String time) {
    return 'Du kan bruke den igjen i dag kl. $time.';
  }

  @override
  String timesUpResumesTomorrow(String time) {
    return 'Du kan bruke den igjen i morgen kl. $time.';
  }

  @override
  String timesUpResumesOn(String day, String time) {
    return 'Du kan bruke den igjen $day kl. $time.';
  }

  @override
  String get waitingForAuthorization => 'Venter på autorisasjon...';

  @override
  String get back => 'Tilbake';

  @override
  String get serverUnavailable => 'Serveren er utilgjengelig';

  @override
  String get loginFailed => 'Innlogging mislyktes';

  @override
  String get loginForbidden =>
      'Denne kontoen kan ikke logge inn akkurat nå. Den kan være utenfor tillatte tider, låst eller deaktivert. Prøv igjen senere, eller spør en administrator.';

  @override
  String quickConnectUnavailable(String detail) {
    return 'Hurtigkobling er utilgjengelig: $detail';
  }

  @override
  String quickConnectUnavailableWithStatus(String status, String detail) {
    return 'Hurtigkobling er utilgjengelig ($status): $detail';
  }

  @override
  String get whosWatching => 'Hvem ser på?';

  @override
  String get addUser => 'Legg til bruker';

  @override
  String get selectServer => 'Velg Server';

  @override
  String appVersionFooter(String version) {
    return 'Tortugarr versjon $version';
  }

  @override
  String get savedServers => 'Lagrede servere';

  @override
  String get discoveredServers => 'Oppdaget servere';

  @override
  String get noneFound => 'Ingen funnet';

  @override
  String get unableToConnectToServer => 'Kan ikke koble til serveren';

  @override
  String get addServer => 'Legg til server';

  @override
  String get embyConnect => 'Emby Koble til';

  @override
  String get removeServer => 'Fjern server';

  @override
  String removeServerConfirmation(String serverName) {
    return 'Vil du fjerne «$serverName» fra serverne dine?';
  }

  @override
  String get cancel => 'Avbryt';

  @override
  String get remove => 'Fjern';

  @override
  String get connectToServer => 'Koble til server';

  @override
  String get serverAddress => 'Serveradresse';

  @override
  String get serverAddressHint => 'https://din-server.example.com';

  @override
  String get connect => 'Koble til';

  @override
  String get secureStorageUnavailable => 'Sikker lagring er ikke tilgjengelig';

  @override
  String get secureStorageUnavailableMessage =>
      'Tortugarr fikk ikke tilgang til systemets nøkkelring. Påloggingen kan fortsette, men sikker tokenlagring kan være utilgjengelig før nøkkelringen er låst opp.';

  @override
  String get ok => 'OK';

  @override
  String get settingsAppearanceTheme => 'App-tema';

  @override
  String get detailScreenStyle => 'Stil for detaljskjerm';

  @override
  String get detailScreenStyleSubtitle =>
      'Klassisk er den opprinnelige, midtstilte Tortugarr-layouten. Moderne er en responsiv, filmatisk layout.';

  @override
  String get detailScreenStyleMoonfin => 'Klassisk';

  @override
  String get detailScreenStyleModern => 'Moderne';

  @override
  String get detailScreenStyleSpotlight => 'Spotlight';

  @override
  String get spotlightMoreActions => 'Flere handlinger';

  @override
  String get spotlightCastCrewStudios => 'Skuespillere, stab og studioer';

  @override
  String get spotlightChaptersExtras => 'Kapitler og ekstra';

  @override
  String get spotlightFileDetails => 'Fildetaljer';

  @override
  String get spotlightSimilarRecommendations => 'Lignende og anbefalinger';

  @override
  String get spotlightSeasonsEpisodes => 'Sesonger og episoder';

  @override
  String get spotlightMoreEpisodes => 'Flere episoder';

  @override
  String get spotlightFilmography => 'Filmografi';

  @override
  String get spotlightCollectionsCard => 'Samlinger';

  @override
  String get spotlightPlaylistOrder => 'Spillelisterekkefølge';

  @override
  String get spotlightMoviesAndShows => 'Filmer og serier';

  @override
  String get spotlightSimilarSeerr => 'Lignende (Seerr)';

  @override
  String get spotlightRecommendationsSeerr => 'Anbefalinger (Seerr)';

  @override
  String spotlightPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String spotlightFactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fakta',
      one: '1 fakta',
    );
    return '$_temp0';
  }

  @override
  String spotlightTagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tagger',
      one: '1 tagg',
    );
    return '$_temp0';
  }

  @override
  String spotlightStudiosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count studioer',
      one: '1 studio',
    );
    return '$_temp0';
  }

  @override
  String spotlightChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kapitler',
      one: '1 kapittel',
    );
    return '$_temp0';
  }

  @override
  String spotlightExtrasCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ekstra',
      one: '1 ekstra',
    );
    return '$_temp0';
  }

  @override
  String spotlightSeasonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesonger',
      one: '1 sesong',
    );
    return '$_temp0';
  }

  @override
  String spotlightEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episoder',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String spotlightMoviesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmer',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String spotlightShowsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serier',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String spotlightTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spor',
      one: '1 spor',
    );
    return '$_temp0';
  }

  @override
  String spotlightItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementer',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String spotlightAlbumsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count album',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String spotlightCollectionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samlinger',
      one: '1 samling',
    );
    return '$_temp0';
  }

  @override
  String spotlightTitlesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titler',
      one: '1 tittel',
    );
    return '$_temp0';
  }

  @override
  String get detailScreenStyleNouveau => 'Nouveau';

  @override
  String get detailScreenStyleMinimalist => 'Minimalistisk';

  @override
  String get expandedTabs => 'Utvidede faner';

  @override
  String get expandedTabsSubtitle =>
      'Vis faneinnhold automatisk mens du blar gjennom faner. Slå av for å åpne og lukke hver fane manuelt.';

  @override
  String get showTechnicalDetails => 'Vis tekniske detaljer?';

  @override
  String get showTechnicalDetailsSubtitle =>
      'Vis informasjon om kodek, oppløsning og strøm i bannersammendraget';

  @override
  String get recommendationSystem => 'Anbefalingssystem';

  @override
  String get recommendationSystemSubtitle =>
      'Bruk den lokale bibliotekalgoritmen Tortugarr anbefaler, eller TMDb-likhetsmålinger på nett. Merk: Anbefalinger på nett krever Seerr-integrasjon.';

  @override
  String get recommendationSystemMoonfin => 'Tortugarr anbefaler';

  @override
  String get recommendationSystemJellyfin => 'Jellyfin anbefaler';

  @override
  String get recommendationSystemTmdb => 'TMDb-likhet';

  @override
  String get recommendationsApplyParentalRatingCap =>
      'Begrens etter aldersgrense?';

  @override
  String get recommendationsApplyParentalRatingCapSubtitle =>
      'Begrens forslag fra Tortugarr anbefaler etter aldersgrensen til det aktuelle innholdet';

  @override
  String get interfaceStyle => 'Grensesnittstil';

  @override
  String get interfaceStyleSubtitle =>
      'Automatisk følger enheten din. Velg Apple eller Material for å tvinge fram et bestemt utseende.';

  @override
  String get interfaceStyleAutomatic => 'Automatisk';

  @override
  String get interfaceStyleApple => 'Apple';

  @override
  String get interfaceStyleMaterial => 'Material';

  @override
  String get interfaceLayout => 'Grensesnittoppsett';

  @override
  String get interfaceLayoutSubtitle =>
      'Overstyr oppsettet dersom enheten gjenkjennes feil. Start Tortugarr på nytt for å ta i bruk endringene.';

  @override
  String get interfaceLayoutAutomatic => 'Automatisk';

  @override
  String get interfaceLayoutTv => 'TV';

  @override
  String get interfaceLayoutDesktop => 'Skrivebord';

  @override
  String get interfaceLayoutPhone => 'Telefon';

  @override
  String get glassQuality => 'Glasskvalitet';

  @override
  String get oledMode => 'OLED modus';

  @override
  String get oledModeSubtitle =>
      'Forsterk sortnivå og farger. Best egnet for OLED skjermer.';

  @override
  String get oledModeSubtle => 'Dempet';

  @override
  String get oledModeVivid => 'Livlig';

  @override
  String get glassQualitySubtitle =>
      'Auto velger den beste glasseffekten for denne enheten. Full tvinger fram ekte uskarphet, mens Redusert bruker et lett glass som sparer GPU-strøm.';

  @override
  String get glassQualityAuto => 'Auto';

  @override
  String get glassQualityFull => 'Full';

  @override
  String get glassQualityReduced => 'Redusert';

  @override
  String get performanceMode => 'Ytelse';

  @override
  String get performanceModeSubtitle =>
      'Justerer seg automatisk etter enhetens minne. Færre bilder lagres i minnet, og trailere vises som stillbilder. Trer i kraft ved neste oppstart.';

  @override
  String get performanceModeAuto => 'Auto';

  @override
  String get performanceModeStandard => 'Standard';

  @override
  String get performanceModeReduced => 'Redusert';

  @override
  String get rendererMode => 'Renderer';

  @override
  String get rendererModeSubtitle =>
      'Auto bruker Impeller på bokser som kjører den jevnt, og Skia ellers. Velg Skia hvis animasjoner eller video ser feil ut. Trer i kraft ved neste oppstart.';

  @override
  String get rendererModeAuto => 'Auto';

  @override
  String get rendererModeSkia => 'Skia';

  @override
  String get trailerPreviewHeldBack =>
      'Av fordi Ytelse er satt til Redusert for denne enheten';

  @override
  String get settingsAppearanceThemeSubtitle =>
      'Bruk et fullstendig tilpasset tema, og bytt mellom et Apple- eller Material-inspirert brukergrensesnitt.';

  @override
  String get customThemeTitle => 'Egendefinert tema';

  @override
  String get customThemeSubtitle =>
      'Egendefinerte temaer endrer visuelle elementer i hele Tortugarr. Velg et av disse alternativene som passer din stil.';

  @override
  String get keyboardPreferSystemIme => 'Foretrekk systemtastatur';

  @override
  String get keyboardPreferSystemImeDescription =>
      'Bruk enhetens inndatametode som standard for tekstinnskriving';

  @override
  String get controller => 'Kontroller';

  @override
  String get gamepadNavigation => 'Navigasjon med spillkontroll';

  @override
  String get gamepadNavigationDescription =>
      'La tilkoblet spillkontroll flytte markør og velge elementer';

  @override
  String get themeMoonfin => 'Tortugarr';

  @override
  String get themeMoonfinSubtitle =>
      'Det originale og stilrene Tortugarr-standarden.';

  @override
  String get themeNeonPulse => 'Neon Pulse';

  @override
  String get themeNeonPulseSubtitle =>
      'Synthwave-styling med magenta glød, cyan tekst og sterkere kromkontrast';

  @override
  String get themeGlass => 'Glass';

  @override
  String get themeGlassSubtitle =>
      'Flytende glass-styling med drivende gradientbakgrunn, frostede flater og Apple-blå aksentfarge';

  @override
  String get theme8BitHero => '8-bit Hero';

  @override
  String get theme8BitHeroSubtitle =>
      'Retro pikselkunst-styling med grov palett, blokkete kanter, harde slagskygger og pikselfont';

  @override
  String get embyConnectSignInSubtitle =>
      'Logg på med Emby Connect-kontoen din';

  @override
  String get emailOrUsername => 'E-post eller brukernavn';

  @override
  String get selectAServer => 'Velg en server';

  @override
  String get tryAgain => 'Prøv igjen';

  @override
  String get noLinkedServers =>
      'Ingen servere knyttet til denne Emby Connect-kontoen';

  @override
  String get invalidEmbyConnectCredentials =>
      'Ugyldig Emby Connect-legitimasjon';

  @override
  String get invalidEmbyConnectLogin =>
      'Ugyldig Emby Connect brukernavn eller passord';

  @override
  String get embyConnectExchangeNotSupported =>
      'Serveren støtter ikke Emby Connect-utveksling';

  @override
  String get embyConnectNetworkError =>
      'Nettverksfeil under kontakt med Emby Connect eller den valgte serveren';

  @override
  String get loadingLinkedServers => 'Laster tilknyttede servere...';

  @override
  String get connectingToServerEllipsis => 'Kobler til server...';

  @override
  String get noReachableAddress => 'Ingen tilgjengelig adresse oppgitt';

  @override
  String get invalidServerExchangeResponse =>
      'Ugyldig svar fra serverutvekslingsendepunkt';

  @override
  String unableToConnectTo(String target) {
    return 'Kan ikke koble til $target';
  }

  @override
  String get exitApp => 'Vil du avslutte Tortugarr?';

  @override
  String get exitAppConfirmation => 'Er du sikker på at du vil avslutte?';

  @override
  String get exit => 'Avslutt';

  @override
  String get gameMenu => 'Meny';

  @override
  String get gamePaused => 'Satt på pause';

  @override
  String get gameSaveState => 'Lagre tilstand';

  @override
  String get games => 'Spill';

  @override
  String get gameLoadState => 'Last inn tilstand';

  @override
  String get gameFastForward => 'Spol framover';

  @override
  String get gameOrientation => 'Spillretning';

  @override
  String get gameOrientationSubtitle => 'Skjermretning når du spiller';

  @override
  String get landscape => 'Liggende';

  @override
  String get portrait => 'Stående';

  @override
  String get gameEmulatorSettings => 'Emulatorinnstillinger';

  @override
  String get gameNoCoreOptions =>
      'Denne kjernen har ingen justerbare alternativer.';

  @override
  String get gameHoldToOpenMenu => 'Hold inne for å åpne menyen';

  @override
  String get gameKeepPlaying => 'Fortsett å spille';

  @override
  String get gameSaveAndExit => 'Lagre og avslutt';

  @override
  String get gameExitGame => 'Avslutt spill';

  @override
  String get gameSavingBeforeExit => 'Lagrer …';

  @override
  String get gameSaveFailedStillPlaying =>
      'Kunne ikke lagre tilstanden. Spillet fortsetter.';

  @override
  String get gamePlaybackUnsupported =>
      'Spillavspilling støttes ikke på denne enheten ennå.';

  @override
  String get noHomeRowsLoaded => 'Ingen hjemmerader kunne lastes';

  @override
  String get noHomeRowsHint =>
      'Prøv å oppdatere eller redusere aktive hjemmeseksjoner.';

  @override
  String get retryHomeRows => 'Prøv Hjemrader på nytt';

  @override
  String get guide => 'TV-Guide';

  @override
  String get recordings => 'Opptak';

  @override
  String get schedule => 'Sendeskjema';

  @override
  String get series => 'Serier';

  @override
  String get noItemsFound => 'Ingen elementer funnet';

  @override
  String get home => 'Hjem';

  @override
  String get browseAll => 'Bla gjennom alle';

  @override
  String get genres => 'Sjangere';

  @override
  String get collectionPlaceholder => 'Samlingsartikler vil vises her';

  @override
  String get browseByLetter => 'Bla etter bokstav';

  @override
  String get alphabeticalBrowsePlaceholder => 'Alfabetisk bla vil vises her';

  @override
  String get suggestions => 'Forslag';

  @override
  String get suggestionsPlaceholder => 'Foreslåtte elementer vises her';

  @override
  String get failedToLoadLibraries => 'Kunne ikke laste inn bibliotekene';

  @override
  String get noLibrariesFound => 'Ingen biblioteker funnet';

  @override
  String get library => 'Bibliotek';

  @override
  String get displaySettings => 'Skjerminnstillinger';

  @override
  String get allGenres => 'Alle sjangere';

  @override
  String get noGenresFound => 'Ingen sjangere funnet';

  @override
  String failedToLoadFolderError(String error) {
    return 'Kunne ikke laste inn mappen: $error';
  }

  @override
  String get thisFolderIsEmpty => 'Denne mappen er tom';

  @override
  String itemCountLabel(int count) {
    return '$count elementer';
  }

  @override
  String get failedToLoadFavorites => 'Kunne ikke laste inn favoritter';

  @override
  String get retry => 'Prøv på nytt';

  @override
  String get noFavoritesYet => 'Ingen favoritter ennå';

  @override
  String get favorites => 'Favoritter';

  @override
  String totalCountItems(int count) {
    return '$count elementer';
  }

  @override
  String get continuing => 'Fortsetter';

  @override
  String get ended => 'Avsluttet';

  @override
  String get sortAndFilter => 'Sorter og filtrer';

  @override
  String get type => 'Type';

  @override
  String get sortBy => 'Sorter etter';

  @override
  String get display => 'Skjerm';

  @override
  String get imageType => 'Bildetype';

  @override
  String get posterSize => 'Plakatstørrelse';

  @override
  String get small => 'Liten';

  @override
  String get medium => 'Middels';

  @override
  String get large => 'Stor';

  @override
  String get extraLarge => 'Ekstra stor';

  @override
  String get uiScaleGrandparents => 'Besteforeldre';

  @override
  String get uiScaleGreatGrandparents => 'Oldeforeldre';

  @override
  String get scrollDirection => 'Rulleretning';

  @override
  String get scrollDirectionVertical => 'Vertikal';

  @override
  String get scrollDirectionHorizontal => 'Horisontal';

  @override
  String libraryGenresTitle(String name) {
    return '$name — Sjangere';
  }

  @override
  String get views => 'Visninger';

  @override
  String get albums => 'Album';

  @override
  String get albumArtists => 'Albumartister';

  @override
  String get artists => 'Artister';

  @override
  String get bookmarks => 'Bokmerker';

  @override
  String get noSavedBookmarks =>
      'Ingen lagrede bokmerker for denne tittelen ennå.';

  @override
  String get openBook => 'Åpne bok';

  @override
  String get chapter => 'Kapittel';

  @override
  String get page => 'Side';

  @override
  String get bookmark => 'Bokmerke';

  @override
  String get justNow => 'Akkurat nå';

  @override
  String minutesAgo(int count) {
    return '$count min siden';
  }

  @override
  String hoursAgo(int count) {
    return '$count t siden';
  }

  @override
  String daysAgo(int count) {
    return '$count d siden';
  }

  @override
  String get discoverySubjects => 'Oppdagelsesemner';

  @override
  String get pickDiscoverySubjects =>
      'Velg hvilke emnestrømmer som skal vises i Discover.';

  @override
  String get apply => 'Bruk';

  @override
  String get openLink => 'Åpne Link';

  @override
  String get scanWithYourPhone => 'Skann med telefonen';

  @override
  String get audiobookGenres => 'Lydbok sjangere';

  @override
  String get pickAudiobookGenres =>
      'Velg hvilke sjangre som skal vises i Audiobook Discover.';

  @override
  String get discoverAudiobooks => 'Oppdag lydbøker';

  @override
  String get librivoxDescription =>
      'Populære public domain-titler fra LibriVox.';

  @override
  String titlesCount(int count) {
    return '$count titler';
  }

  @override
  String get scrollLeft => 'Rull til venstre';

  @override
  String get scrollRight => 'Rull til høyre';

  @override
  String get scrollToTop => 'Gå til toppen';

  @override
  String get couldNotLoadGenre =>
      'Kunne ikke laste inn denne sjangeren akkurat nå.';

  @override
  String get continueReading => 'Fortsett å lese';

  @override
  String get savedHighlights => 'Lagrede høydepunkter';

  @override
  String get continueListening => 'Fortsett å lytte';

  @override
  String get listen => 'Lytte';

  @override
  String get resume => 'Fortsett';

  @override
  String get failedToLoadLibrary => 'Kunne ikke laste inn biblioteket';

  @override
  String get popularNow => 'Populær nå';

  @override
  String get savedForLater => 'Lagret til senere';

  @override
  String get topListens => 'Topplytter';

  @override
  String get unreadDiscoveries => 'Uleste oppdagelser';

  @override
  String get pickUpAgain => 'Plukk opp igjen';

  @override
  String get bookHighlightsDescription =>
      'Bøkene dine med høydepunkter, favoritter eller lesefremgang.';

  @override
  String get handPickedFromLibrary => 'Håndplukket fra biblioteket ditt.';

  @override
  String get handPickedFromListeningQueue => 'Håndplukket fra lyttekøen din.';

  @override
  String get booksWithHighlights =>
      'Bøker med høydepunkter, favoritter eller lesefremgang.';

  @override
  String get jumpBackNarration =>
      'Hopp tilbake til fortellingen uten å lete etter plassen din.';

  @override
  String get unreadBooksReady => 'Uleste bøker klare for neste stille time.';

  @override
  String get quickAccessFavorites =>
      'Rask tilgang til bøkene du stadig vender tilbake til.';

  @override
  String get searchAudiobooks => 'Søk etter lydbøker';

  @override
  String get searchYourLibrary => 'Søk i biblioteket ditt';

  @override
  String get pickUpStory => 'Fortsett historien der du slapp';

  @override
  String get savedPlacesChapters => 'Dine lagrede steder og uferdige kapitler';

  @override
  String authorsCount(int count) {
    return '$count forfattere';
  }

  @override
  String genresCount(int count) {
    return '$count sjangere';
  }

  @override
  String percentCompleted(int percent) {
    return '$percent % fullført';
  }

  @override
  String get readyWhenYouAre => 'Klar når du er';

  @override
  String get details => 'Detaljer';

  @override
  String get listeningRoom => 'Lytterom';

  @override
  String get bookmarksAndProgress => 'Bokmerker og fremgang';

  @override
  String titlesArrangedForBrowsing(int count) {
    return '$count titler organisert for lesing først.';
  }

  @override
  String get titles => 'Titler';

  @override
  String get allTitles => 'Alle titler';

  @override
  String get authors => 'Forfattere';

  @override
  String get browseByAuthor => 'Bla etter forfatter';

  @override
  String get browseByGenre => 'Bla etter sjanger';

  @override
  String get discover => 'Oppdage';

  @override
  String get trendingTitlesOpenLibrary =>
      'Populære titler etter emne fra Open Library.';

  @override
  String get noBookmarkedItems => 'Ingen bokmerkede elementer ennå';

  @override
  String get nothingMatchesSection =>
      'Ingenting samsvarer med denne delen ennå. Prøv en annen fane eller kom tilbake etter at biblioteksynkroniseringen er ferdig.';

  @override
  String get audiobooks => 'Lydbøker';

  @override
  String noLabelFound(String label) {
    return 'Fant ingen $label';
  }

  @override
  String get folder => 'Mappe';

  @override
  String get filters => 'Filtre';

  @override
  String get readingStatus => 'Lesestatus';

  @override
  String get playedStatus => 'Spillt status';

  @override
  String get readStatus => 'Lese';

  @override
  String get watched => 'Sett';

  @override
  String get unread => 'Ulest';

  @override
  String get unwatched => 'Usett';

  @override
  String get seriesStatus => 'Seriestatus';

  @override
  String get allLibraries => 'Alle biblioteker';

  @override
  String get books => 'Bøker';

  @override
  String get latestBooks => 'Nyeste bøker';

  @override
  String get latestAudiobooks => 'Nyeste lydbøker';

  @override
  String get latestComics => 'Siste Tegneserier';

  @override
  String get comics => 'Tegneserier';

  @override
  String bookSeriesItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bøker',
      one: '1 bok',
    );
    return '$_temp0';
  }

  @override
  String get bookFormatBook => 'Bok';

  @override
  String get bookFormatAudiobook => 'Lydbok';

  @override
  String get bookFormatComic => 'Tegneserie';

  @override
  String get noBooksFound => 'Fant ingen bøker for denne forfatteren.';

  @override
  String get noBooksFoundDescription =>
      'Dette biblioteket inneholder ingen bøker, lydbøker eller tegneserier.';

  @override
  String bookPercentRead(int percent) {
    return '$percent % lest';
  }

  @override
  String bookTimeLeft(String time) {
    return '$time igjen';
  }

  @override
  String get bookHeroRead => 'Les';

  @override
  String get bookHeroListen => 'Lytt';

  @override
  String get author => 'Forfatter';

  @override
  String get unknownAuthor => 'Ukjent forfatter';

  @override
  String get uncategorized => 'Ukategorisert';

  @override
  String get overview => 'Oversikt';

  @override
  String get noLibrivoxDescription =>
      'Ingen beskrivelse gitt av LibriVox for denne tittelen ennå.';

  @override
  String get readers => 'Lesere';

  @override
  String get openLinks => 'Åpne lenker';

  @override
  String get librivoxPage => 'LibriVox-side';

  @override
  String get internetArchive => 'Internett-arkiv';

  @override
  String get rssFeed => 'RSS-feed';

  @override
  String get downloadZip => 'Last ned zip';

  @override
  String sectionCountLabel(int count) {
    return '$count deler';
  }

  @override
  String firstPublished(int year) {
    return 'Først utgitt $year';
  }

  @override
  String get noOpenLibraryOverview =>
      'Ingen oversikt tilgjengelig fra Open Library for denne tittelen ennå.';

  @override
  String get subjects => 'Emner';

  @override
  String get all => 'Alle';

  @override
  String booksCount(int count) {
    return '$count bøker';
  }

  @override
  String get couldNotLoadSubject =>
      'Kunne ikke laste inn dette emnet akkurat nå.';

  @override
  String get audiobookDetails => 'Lydbokdetaljer';

  @override
  String authorsCountTitle(int count) {
    return '$count forfattere';
  }

  @override
  String audiobookCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lydbøker',
      one: '1 lydbok',
    );
    return '$_temp0';
  }

  @override
  String get trackList => 'Sporliste';

  @override
  String get itemListPlaceholder => 'Vareliste vil vises her';

  @override
  String get failedToLoad => 'Kunne ikke laste inn';

  @override
  String get delete => 'Slett';

  @override
  String get save => 'Lagre';

  @override
  String get moreLikeThis => 'Mer som dette';

  @override
  String get castAndCrew => 'Skuespillere og team';

  @override
  String get collection => 'Samling';

  @override
  String get episodes => 'Episoder';

  @override
  String get nextUp => 'Neste opp';

  @override
  String get seasons => 'Sesonger';

  @override
  String get chapters => 'Kapitler';

  @override
  String get features => 'Funksjoner';

  @override
  String get movies => 'Filmer';

  @override
  String get musicVideos => 'Musikkvideoer';

  @override
  String get other => 'Annen';

  @override
  String get discography => 'Diskografi';

  @override
  String get similarArtists => 'Lignende artister';

  @override
  String get tableOfContents => 'Innholdsfortegnelse';

  @override
  String get tracklist => 'Sporliste';

  @override
  String discNumber(int number) {
    return 'Plate $number';
  }

  @override
  String get biography => 'Biografi';

  @override
  String get authorDetails => 'Forfatterdetaljer';

  @override
  String get noOverviewAvailable =>
      'Ingen oversikt tilgjengelig for denne tittelen ennå.';

  @override
  String get noBiographyAvailable =>
      'Ingen biografi tilgjengelig for denne forfatteren.';

  @override
  String get unableToLoadAuthorDetails =>
      'Kan ikke laste inn forfatterdetaljer akkurat nå.';

  @override
  String published(int year) {
    return 'Utgitt $year';
  }

  @override
  String get publicationDateUnknown => 'Utgivelsesdato ukjent';

  @override
  String seasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesonger',
      one: '1 sesong',
    );
    return '$_temp0';
  }

  @override
  String endsAt(String time) {
    return 'Slutter kl. $time';
  }

  @override
  String get items => 'Elementer';

  @override
  String get extras => 'Ekstra';

  @override
  String get additionalParts => 'Flere deler';

  @override
  String get behindTheScenes => 'Bak kulissene';

  @override
  String get deletedScenes => 'Slettede scener';

  @override
  String get featurettes => 'Featuretter';

  @override
  String get interviews => 'Intervjuer';

  @override
  String get scenes => 'Scener';

  @override
  String get shorts => 'Kortfilmer';

  @override
  String get trailers => 'Trailere';

  @override
  String timeRemaining(String time) {
    return '$time igjen';
  }

  @override
  String endsIn(String time) {
    return 'Slutter om $time';
  }

  @override
  String get view => 'Utsikt';

  @override
  String get resumeReading => 'Fortsett lesing';

  @override
  String get read => 'Lese';

  @override
  String resumeFrom(String position) {
    return 'Fortsett fra $position';
  }

  @override
  String get play => 'Spill av';

  @override
  String get startOver => 'Start på nytt';

  @override
  String get restart => 'Start på nytt';

  @override
  String get readOffline => 'Les frakoblet';

  @override
  String get playOffline => 'Spill frakoblet';

  @override
  String get audio => 'Lyd';

  @override
  String get subtitles => 'Undertekster';

  @override
  String get version => 'Versjon';

  @override
  String get cast => 'Cast';

  @override
  String get castMembers => 'Medvirkende';

  @override
  String get trailer => 'Trailer';

  @override
  String get finished => 'Ferdig';

  @override
  String get favorited => 'Favoritt';

  @override
  String get favorite => 'Favoritt';

  @override
  String get playlist => 'Spilleliste';

  @override
  String get downloaded => 'Lastet ned';

  @override
  String get finalizingDownload => 'Fullfører…';

  @override
  String get queuedDownload => 'I Kø';

  @override
  String queuedMoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count til i kø',
      one: '1 til i kø',
    );
    return '$_temp0';
  }

  @override
  String get downloadAll => 'Last ned alle';

  @override
  String get download => 'Last ned';

  @override
  String get deleteDownloaded => 'Slett nedlastede';

  @override
  String get goToSeries => 'Gå til serien';

  @override
  String get editMetadata => 'Rediger metadata';

  @override
  String get less => 'Mindre';

  @override
  String get more => 'Flere';

  @override
  String get deleteItem => 'Slett element';

  @override
  String get deletePlaylist => 'Slett spilleliste';

  @override
  String get deletePlaylistMessage =>
      'Vil du slette denne spillelisten fra serveren?';

  @override
  String get deleteItemMessage => 'Vil du slette dette elementet fra serveren?';

  @override
  String get failedToDeletePlaylist => 'Kunne ikke slette spillelisten';

  @override
  String get failedToDeleteItem => 'Kunne ikke slette elementet';

  @override
  String failedToDeleteItemWithError(String error) {
    return 'Slettingen mislyktes med følgende feil: $error';
  }

  @override
  String get renamePlaylist => 'Gi nytt navn til spilleliste';

  @override
  String get playlistName => 'Spillelistenavn';

  @override
  String get deleteDownloadedAlbum => 'Slett nedlastet album';

  @override
  String deleteDownloadedTracksMessage(String title) {
    return 'Vil du slette nedlastede spor for «$title»?';
  }

  @override
  String get downloadedTracksDeleted => 'Nedlastede spor slettet';

  @override
  String get downloadedTracksDeleteFailed =>
      'Noen nedlastede spor kunne ikke slettes';

  @override
  String get noTracksLoaded => 'Ingen spor lastet';

  @override
  String noItemsLoaded(String itemLabel) {
    return 'Ingen $itemLabel lastet inn';
  }

  @override
  String downloadingTitle(String title, int count) {
    return 'Laster ned $title ($count elementer)...';
  }

  @override
  String deleteConfirmMessage(String name) {
    return 'Er du sikker på at du vil slette «$name» fra serveren? Denne handlingen kan ikke angres.';
  }

  @override
  String get itemDeleted => 'Element slettet';

  @override
  String get noPlayableTrailerFound => 'Fant ingen spillbar trailer.';

  @override
  String unsupportedBookFormat(String extension) {
    return 'Bokformatet støttes ikke: .$extension';
  }

  @override
  String get audioTrack => 'Lydspor';

  @override
  String get subtitleTrack => 'Undertekstspor';

  @override
  String get none => 'Ingen';

  @override
  String get downloadSubtitlesLabel => 'Last ned undertekster...';

  @override
  String get searchOpenSubtitlesPlugin => 'Søk med OpenSubtitles-plugin';

  @override
  String get downloadSubtitles => 'Last ned undertekster';

  @override
  String get searchingSubtitles => 'Søkker etter undertekster…';

  @override
  String get fetchingSubtitles => 'Henter undertekster';

  @override
  String get downloadingSubtitle => 'Laster ned undertekst …';

  @override
  String get selectedSubtitleInvalid => 'Den valgte underteksten er ugyldig.';

  @override
  String subtitleDownloadedSelected(String name) {
    return 'Undertekst lastet ned og valgt: $name';
  }

  @override
  String get subtitleDownloadedPending =>
      'Undertekst lastet ned. Det kan ta et øyeblikk å vises mens Jellyfin oppdaterer elementet.';

  @override
  String noRemoteSubtitlesFound(String language) {
    return 'Fant ingen eksterne undertekster for $language.';
  }

  @override
  String get selectVersion => 'Velg Versjon';

  @override
  String versionNumber(int number) {
    return 'Versjon $number';
  }

  @override
  String get downloadAllQuality => 'Last ned alle — kvalitet';

  @override
  String get downloadQuality => 'Last ned kvalitet';

  @override
  String get originalFileNoReencoding => 'Originalfil, ingen omkoding';

  @override
  String get originalFilesNoReencoding => 'Originalfiler, ingen omkoding';

  @override
  String get noEpisodesLoaded => 'Ingen episoder er lastet inn';

  @override
  String get downloadScopeTitle => 'Hva skal lastes ned';

  @override
  String get downloadAllEpisodes => 'Alle episoder';

  @override
  String get downloadUnwatchedEpisodes => 'Alle usette episoder';

  @override
  String get downloadAllMovies => 'Alle filmer';

  @override
  String get downloadUnwatchedMovies => 'Alle usette filmer';

  @override
  String get downloadScopeLoading => 'Laster inn elementer …';

  @override
  String get downloadScopeLoadFailed =>
      'Kunne ikke laste inn elementer for nedlasting';

  @override
  String downloadEstimateTotal(String size) {
    return '~$size totalt';
  }

  @override
  String downloadBytesOfTotal(String received, String total) {
    return '$received av $total';
  }

  @override
  String downloadSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String downloadSizeTotal(String size) {
    return '$size totalt';
  }

  @override
  String downloadEstimateUnknownCount(int count) {
    return '$count ukjent';
  }

  @override
  String downloadingItem(String name, String quality) {
    return 'Laster ned $name ($quality)...';
  }

  @override
  String get deleteDownloadedFiles => 'Slett nedlastede filer';

  @override
  String deleteLocalFilesMessage(String typeLabel) {
    return 'Vil du slette lokale filer for $typeLabel?\n\nDette frigjør lagringsplass. Du kan laste dem ned igjen senere.';
  }

  @override
  String get downloadedFilesDeleted => 'Nedlastede filer slettet';

  @override
  String get failedToDeleteFiles => 'Kunne ikke slette filer';

  @override
  String get deleteFiles => 'Slett filer';

  @override
  String get director => 'DIREKTØR';

  @override
  String get starring => 'MEDVIRKENDE';

  @override
  String get directors => 'REGISSØRER';

  @override
  String get writer => 'MANUSFORFATTER';

  @override
  String get writers => 'MANUSFORFATTERE';

  @override
  String get studio => 'STUDIO';

  @override
  String studioMoreCount(int count) {
    return '+$count til';
  }

  @override
  String totalEpisodes(int count) {
    return '$count episoder';
  }

  @override
  String episodeProgress(int watched, int total) {
    return '$watched / $total';
  }

  @override
  String episodeLabel(int number) {
    return 'Episode $number';
  }

  @override
  String chapterNumber(int number) {
    return 'Kapittel $number';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spor',
      one: '1 spor',
    );
    return '$_temp0';
  }

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kapitler',
      one: '1 kapittel',
    );
    return '$_temp0';
  }

  @override
  String born(String date) {
    return 'Født $date';
  }

  @override
  String died(String date) {
    return 'Død $date';
  }

  @override
  String age(int age) {
    return 'Alder $age';
  }

  @override
  String get showLess => 'Vis mindre';

  @override
  String get readMore => 'Les mer';

  @override
  String get shuffle => 'Tilfeldig';

  @override
  String get shuffleAll => 'Bland alle';

  @override
  String get shuffleAllMusic => 'Spill all musikk i tilfeldig rekkefølge';

  @override
  String get carSignInPrompt => 'Logg på Tortugarr på telefonen';

  @override
  String get carServerUnreachable => 'Får ikke kontakt med serveren';

  @override
  String downloadsCount(int count) {
    return '$count nedlastinger';
  }

  @override
  String get perfectMatch => 'Perfekt match';

  @override
  String get aiTranslated => 'KI-oversatt';

  @override
  String get machineTranslated => 'Maskinoversatt';

  @override
  String get hearingImpaired => 'SDH';

  @override
  String framerateFps(String rate) {
    return '$rate fps';
  }

  @override
  String channelsCount(int count) {
    return '$count kan.';
  }

  @override
  String get mono => 'Mono';

  @override
  String get stereo => 'Stereo';

  @override
  String remoteSubtitlePermissionError(String action) {
    return 'Ekstern undertekst $action krever Jellyfin-tillatelsen for undertekstadministrasjon for denne brukeren.';
  }

  @override
  String remoteSubtitleNotFoundError(String action) {
    return 'Dette elementet ble ikke funnet på serveren for ekstern undertekst $action.';
  }

  @override
  String remoteSubtitleDetailError(String action, String detail) {
    return 'Ekstern undertekst $action mislyktes: $detail';
  }

  @override
  String remoteSubtitleHttpError(String action, int status) {
    return 'Ekstern undertekst $action mislyktes (HTTP $status).';
  }

  @override
  String remoteSubtitleGenericError(String action) {
    return 'Kunne ikke $action eksterne undertekster.';
  }

  @override
  String deleteSeriesFiles(String name) {
    return 'alle nedlastede episoder for «$name»';
  }

  @override
  String get deleteSeasonFiles => 'alle nedlastede episoder i denne sesongen';

  @override
  String get stillWatching => 'Ser du fortsatt?';

  @override
  String get unableToLoadTrailerStream => 'Kan ikke laste trailerstrømmen.';

  @override
  String get trailerTimedOut => 'Traileren ble tidsavbrutt under lasting.';

  @override
  String get playbackFailedForTrailer =>
      'Avspilling mislyktes for denne traileren.';

  @override
  String photoCountOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get castingUnavailableOffline =>
      'Casting er utilgjengelig under avspilling uten nett.';

  @override
  String castActionFailed(String label, String error) {
    return '$label-handlingen mislyktes: $error';
  }

  @override
  String failedToSetCastVolume(String error) {
    return 'Kunne ikke angi cast-volum: $error';
  }

  @override
  String castControlsTitle(String label) {
    return '$label-kontroller';
  }

  @override
  String get deviceVolume => 'Enhetsvolum';

  @override
  String get unavailable => 'Utilgjengelig';

  @override
  String get pause => 'Pause';

  @override
  String get syncPosition => 'Synkroniseringsposisjon';

  @override
  String stopCast(String label) {
    return 'Stopp $label';
  }

  @override
  String get queueIsEmpty => 'Køen er tom';

  @override
  String trackNumber(int number) {
    return 'Spor $number';
  }

  @override
  String get remotePlayback => 'Fjernavspilling';

  @override
  String get castingToGoogleCast => 'Caster til Google Cast';

  @override
  String get castingViaAirPlay => 'Caster via AirPlay';

  @override
  String get castingViaDlna => 'Caster via DLNA';

  @override
  String secondsCount(int seconds) {
    return '$seconds sekunder';
  }

  @override
  String get longPressToUnlock => 'Langt trykk for å låse opp';

  @override
  String get off => 'Av';

  @override
  String streamTypeFallback(String streamType, int number) {
    return '$streamType $number';
  }

  @override
  String get auto => 'Auto';

  @override
  String bitrateValueMbps(int mbps) {
    return '$mbps Mbps';
  }

  @override
  String get bitrateOverride => 'Bitrate-overstyring';

  @override
  String get audioDelay => 'Lydforsinkelse';

  @override
  String delayMinusMs(int value) {
    return '-$value ms';
  }

  @override
  String delayPlusMs(int value) {
    return '+$value ms';
  }

  @override
  String get subtitleDelay => 'Undertekstforsinkelse';

  @override
  String get reset => 'Tilbakestill';

  @override
  String get unknown => 'Ukjent';

  @override
  String get playbackInformation => 'Avspillingsinformasjon';

  @override
  String get showMpvStats => 'Vis mpv-statistikk (Shift+I)';

  @override
  String get hideMpvStats => 'Skjul mpv-statistikk (Shift+I)';

  @override
  String get keyboardShortcutsTitle => 'Hurtigtaster';

  @override
  String get keyboardShortcutsSubtitle =>
      'Taster for appen, videospilleren og leseren';

  @override
  String get keyboardShortcutsPlayerHint =>
      'Trykk ? eller F1 mens en video spilles for å se denne listen uten å forlate spilleren.';

  @override
  String get keyboardShortcutsSectionApp => 'Overalt';

  @override
  String get keyboardShortcutsSectionAppScope => 'På alle skjermbilder';

  @override
  String get keyboardShortcutsSectionPlayer => 'Videospiller';

  @override
  String get keyboardShortcutsSectionPlayerScope =>
      'Når en video er åpen, spilles eller er satt på pause';

  @override
  String get keyboardShortcutsSectionReader => 'Bok- og tegneserieleser';

  @override
  String get keyboardShortcutsSectionReaderScope =>
      'Når du leser en bok eller tegneserie';

  @override
  String get keyNameArrowKeys => 'Piltaster';

  @override
  String get keyNameSpace => 'Mellomrom';

  @override
  String get keyNameEnter => 'Enter';

  @override
  String get keyNameEsc => 'Esc';

  @override
  String get keyNameBackspace => 'Backspace';

  @override
  String get keyNameDelete => 'Delete';

  @override
  String get keyNamePageUp => 'Page Up';

  @override
  String get keyNamePageDown => 'Page Down';

  @override
  String get keyNameHome => 'Home';

  @override
  String get keyNameEnd => 'End';

  @override
  String get keyNameShift => 'Shift';

  @override
  String get keyNameCtrl => 'Ctrl';

  @override
  String get keyNameAlt => 'Alt';

  @override
  String get keyNameScrollWheel => 'Rullehjul';

  @override
  String get shortcutMoveFocus => 'Flytt mellom elementer';

  @override
  String get shortcutActivate => 'Åpne valgt element';

  @override
  String get shortcutGoBack => 'Gå tilbake';

  @override
  String get shortcutToggleFullscreen => 'Fullskjerm av eller på';

  @override
  String get shortcutQuit => 'Avslutt Tortugarr';

  @override
  String get shortcutPlayPause => 'Spill av eller pause';

  @override
  String get shortcutShowControlsOrPlayPause =>
      'Vis kontroller, eller spill av/pause hvis de vises';

  @override
  String get shortcutSeekBack => 'Spol tilbake (hold for større hopp)';

  @override
  String get shortcutSeekForward => 'Spol fremover (hold for større hopp)';

  @override
  String get shortcutVolumeUp => 'Volum opp';

  @override
  String get shortcutVolumeDown => 'Volum ned';

  @override
  String get shortcutMute => 'Lyd av eller på';

  @override
  String get shortcutToggleSubtitles => 'Undertekster av eller på';

  @override
  String get shortcutSlower => 'Saktere';

  @override
  String get shortcutFaster => 'Raskere';

  @override
  String get shortcutPlaybackInfo => 'Vis avspillingsinformasjon';

  @override
  String get shortcutMpvStats => 'mpv-statistikk av eller på';

  @override
  String get shortcutRecropBlackBars => 'Beskjær svarte felt på nytt';

  @override
  String get shortcutLeaveFullscreenOrStop =>
      'Avslutt fullskjerm, eller stopp hvis ikke i fullskjerm';

  @override
  String get shortcutHideControls => 'Skjul kontroller';

  @override
  String get shortcutStopPlayback => 'Stopp avspilling';

  @override
  String get shortcutNextItem => 'Neste element';

  @override
  String get shortcutPreviousItem => 'Forrige element';

  @override
  String get shortcutSkipSegment =>
      'Hopp over intro eller rulletekst når det tilbys';

  @override
  String get shortcutShowShortcuts => 'Vis denne listen';

  @override
  String get shortcutNextPage => 'Neste side';

  @override
  String get shortcutPreviousPage => 'Forrige side';

  @override
  String get shortcutScrollPage => 'Rull siden (e-bøker)';

  @override
  String get shortcutFirstPage => 'Første side, eller start av kapittel';

  @override
  String get shortcutLastPage => 'Siste side, eller slutt på kapittel';

  @override
  String get shortcutZoom => 'Zoom inn eller ut (tegneserier)';

  @override
  String get shortcutResetZoom => 'Tilbakestill zoom (tegneserier)';

  @override
  String get playback => 'Avspilling';

  @override
  String get playMethod => 'Spillemetode';

  @override
  String get directPlay => 'Direkteavspilling';

  @override
  String get directStream => 'Direktestrøm';

  @override
  String get transcoding => 'Omkoding';

  @override
  String get transcodeReasons => 'Årsaker til omkoding';

  @override
  String get player => 'Avspiller';

  @override
  String get container => 'Container';

  @override
  String get bitrate => 'Bithastighet';

  @override
  String get video => 'Video';

  @override
  String get resolution => 'Oppløsning';

  @override
  String get hdr => 'HDR';

  @override
  String get hdrOutput => 'HDR-utgang';

  @override
  String hdrOutputActive(String format) {
    return 'Aktiv – $format';
  }

  @override
  String get hdrOutputActiveTonemapped =>
      'Aktiv – tonemappet til SDR for denne skjermen';

  @override
  String get hdrOutputContentSdr => 'Inaktiv – innholdet er SDR';

  @override
  String get hdrOutputDisabled => 'Inaktiv – slått av i innstillingene';

  @override
  String get hdrOutputFailed =>
      'Inaktiv – kunne ikke starte, bruker standardveien';

  @override
  String get videoRenderer => 'Videorenderer';

  @override
  String get videoRendererDescription =>
      'Eget vindu gir jevnest bevegelse og sender HDR urørt til skjermen. Prøv et annet valg hvis videoen oppfører seg rart.';

  @override
  String get videoRendererNativeWindow => 'Eget vindu (anbefalt)';

  @override
  String get videoRendererNativeHdrOnly => 'Eget vindu kun for HDR';

  @override
  String get videoRendererInApp => 'I appen (eldre)';

  @override
  String get codec => 'Kodek';

  @override
  String get videoBitrate => 'Video bitrate';

  @override
  String get track => 'Spor';

  @override
  String get channels => 'Kanaler';

  @override
  String get audioBitrate => 'Lydbithastighet';

  @override
  String get sampleRate => 'Samplingsfrekvens';

  @override
  String get format => 'Format';

  @override
  String get external => 'Utvendig';

  @override
  String get embedded => 'Innebygd';

  @override
  String castSessionError(String protocol) {
    return 'Øktfeil for $protocol';
  }

  @override
  String failedToLoadBookDetails(String error) {
    return 'Kunne ikke laste inn bokdetaljer: $error';
  }

  @override
  String get epubUnavailableOnPlatform =>
      'EPUB-gjengivelse i appen er ikke tilgjengelig på denne plattformen ennå.';

  @override
  String formatCannotRenderInApp(String extension) {
    return 'Dette formatet (.$extension) kan ikke vises i appen ennå.';
  }

  @override
  String get embeddedRenderingUnavailable =>
      'Innebygd dokumentgjengivelse er utilgjengelig på denne plattformen.';

  @override
  String get couldNotOpenExternalViewer => 'Kunne ikke åpne ekstern viewer.';

  @override
  String failedToOpenInAppReader(String error) {
    return 'Kunne ikke åpne leseren i appen: $error';
  }

  @override
  String bookmarkAlreadySaved(String label) {
    return 'Bokmerket er allerede lagret ved $label.';
  }

  @override
  String bookmarkAdded(String label) {
    return 'Bokmerke lagt til: $label';
  }

  @override
  String get noBookmarksYet =>
      'Ingen bokmerker ennå.\nTrykk på bokmerkeikonet mens du leser for å lagre posisjonen din.';

  @override
  String get noTableOfContentsAvailable =>
      'Ingen innholdsfortegnelse tilgjengelig';

  @override
  String pageLabel(int number) {
    return 'Side $number';
  }

  @override
  String get position => 'Posisjon';

  @override
  String get bookReader => 'Bokleser';

  @override
  String formatExtension(String extension) {
    return 'Format: .$extension';
  }

  @override
  String percentRead(String percent) {
    return '$percent % lest';
  }

  @override
  String get updating => 'Oppdaterer...';

  @override
  String get markUnread => 'Merk som ulest';

  @override
  String get markAsRead => 'Merk som lest';

  @override
  String get reloadReader => 'Last inn leseren på nytt';

  @override
  String get noPagesFound => 'Ingen sider funnet.';

  @override
  String get failedToDecodePageImage => 'Kunne ikke dekode sidebildet.';

  @override
  String resetZoom(String zoom) {
    return 'Tilbakestill zoom (${zoom}x)';
  }

  @override
  String get singlePage => 'Enkeltside';

  @override
  String get twoPageSpread => 'Oppslag på to sider';

  @override
  String get addBookmark => 'Legg til bokmerke';

  @override
  String get bookmarksEllipsis => 'Bokmerker...';

  @override
  String get markedAsRead => 'Merket som lest';

  @override
  String get markedAsUnread => 'Merket som ulest';

  @override
  String failedToUpdateReadState(String error) {
    return 'Kunne ikke oppdatere lesestatus: $error';
  }

  @override
  String get themeSystem => 'Tema: System';

  @override
  String get themeLight => 'Tema: Lys';

  @override
  String get themeDark => 'Tema: Mørkt';

  @override
  String get themeSepia => 'Tema: Sepia';

  @override
  String get invertColorsFixedLayout => 'Inverter farger (fast layout)';

  @override
  String get invertColorsPdf => 'Inverter farger (PDF)';

  @override
  String get preparingInAppReader => 'Forbereder leser i appen ...';

  @override
  String get pdfDataNotAvailable => 'PDF-data ikke tilgjengelig.';

  @override
  String get readerFallbackModeActive => 'Leser-reservemodus er aktiv';

  @override
  String platformCannotHostDocumentEngine(String extension) {
    return 'Denne plattformen kan ikke kjøre den innebygde dokumentmotoren for $extension-filer.';
  }

  @override
  String get reloadReaderPlatformHint =>
      'Bruk Reload Reader etter at du har byttet til et støttet plattformmål (Android, iOS, macOS).';

  @override
  String get openExternally => 'Åpne eksternt';

  @override
  String get noEpubChaptersFound => 'Ingen EPUB-kapitler funnet.';

  @override
  String get readerNotReady => 'Leseren er ikke klar.';

  @override
  String get seriesRecordings => 'Serieopptak';

  @override
  String get now => 'Nå';

  @override
  String get sports => 'Sport';

  @override
  String get news => 'Nyheter';

  @override
  String get kids => 'Barn';

  @override
  String get premiere => 'Premiere';

  @override
  String get guideRepeatBadge => 'Reprise';

  @override
  String get guideTimeline => 'Guide Tidslinje';

  @override
  String failedToLoadGuide(String error) {
    return 'Kunne ikke laste inn guiden: $error';
  }

  @override
  String get noChannelsFound => 'Ingen kanaler funnet';

  @override
  String get noProgramData => 'Ingen programdata';

  @override
  String get liveBadge => 'BO';

  @override
  String get liveTvJumpToLive => 'Gå til direkte';

  @override
  String guideNextProgram(String time, String title) {
    return 'Neste: $time  $title';
  }

  @override
  String guideMinutesLeft(int minutes) {
    return '$minutes min igjen';
  }

  @override
  String guideHoursLeft(int hours) {
    return '$hours t igjen';
  }

  @override
  String guideHoursMinutesLeft(int hours, int minutes) {
    return '$hours t $minutes min igjen';
  }

  @override
  String get movie => 'Film';

  @override
  String get removedFromFavoriteChannels => 'Fjernet fra favorittkanaler';

  @override
  String get addedToFavoriteChannels => 'Lagt til favorittkanaler';

  @override
  String get failedToUpdateFavoriteChannel =>
      'Kunne ikke oppdatere favorittkanalen';

  @override
  String get unfavoriteChannel => 'Kanal som ikke er favoritt';

  @override
  String get favoriteChannel => 'Favoritt kanal';

  @override
  String get record => 'Ta opp';

  @override
  String nextSeriesRecording(String dateTime) {
    return 'Neste serieopptak: $dateTime';
  }

  @override
  String get noUpcomingSeriesRecording =>
      'Serieopptak er planlagt, men guiden har ingen kommende episoder';

  @override
  String get recordCurrentEpisode => 'Ta opp denne episoden';

  @override
  String get recordCurrentProgram => 'Ta opp dette programmet';

  @override
  String get cancelCurrentRecording => 'Avbryt dette opptaket';

  @override
  String get cancelRecordingAction => 'Avbryt opptak';

  @override
  String get programSetToRecord => 'Programmet er satt opp for opptak';

  @override
  String get recordingCancelled => 'Opptaket er avbrutt';

  @override
  String get unableToCreateRecording => 'Kan ikke opprette opptak';

  @override
  String get recordSeries => 'Ta opp serie';

  @override
  String get seriesSetToRecord => 'Serien blir tatt opp';

  @override
  String get seriesRecordingCancelled => 'Serieopptak avbrutt';

  @override
  String get unableToCreateSeriesRecording => 'Kunne ikke opprette serieopptak';

  @override
  String get watch => 'Se på';

  @override
  String get watchChannelLive => 'Se kanalen direkte';

  @override
  String get close => 'Lukk';

  @override
  String failedToPlayChannel(String name) {
    return 'Kunne ikke spille av $name';
  }

  @override
  String get playbackStreamLost =>
      'Avspillingen stoppet og kunne ikke gjenopprettes.';

  @override
  String get playbackVideoUnsupported =>
      'Denne enheten kan ikke spille av videoformatet. Prøv en ekstern spiller.';

  @override
  String liveReconnecting(int attempt, int total) {
    return 'Kobler til på nytt … ($attempt av $total)';
  }

  @override
  String get failedToLoadRecordings => 'Kunne ikke laste inn opptak';

  @override
  String get scheduledInNext24Hours => 'Planlagt i neste 24 timer';

  @override
  String get recentRecordings => 'Nylige opptak';

  @override
  String get tvSeries => 'TV-serier';

  @override
  String get failedToLoadSchedule => 'Kunne ikke laste inn tidsplanen';

  @override
  String get noScheduledRecordings => 'Ingen planlagte opptak';

  @override
  String get cancelRecording => 'Vil du avbryte opptaket?';

  @override
  String cancelScheduledRecordingOf(String name) {
    return 'Vil du avbryte det planlagte opptaket av «$name»?';
  }

  @override
  String get no => 'Nei';

  @override
  String get yesCancel => 'Ja, avbryt';

  @override
  String get failedToCancelRecording => 'Kunne ikke avbryte opptaket';

  @override
  String get failedToLoadSeriesRecordings => 'Kunne ikke laste inn serieopptak';

  @override
  String get noSeriesRecordings => 'Ingen serieopptak';

  @override
  String get cancelSeriesRecording => 'Avbryt serieopptak';

  @override
  String get cancelSeriesRecordingQuestion => 'Vil du avbryte serieopptak?';

  @override
  String stopRecordingName(String name) {
    return 'Vil du stoppe opptaket av «$name»?';
  }

  @override
  String get failedToCancelSeriesRecording => 'Kunne ikke avbryte serieopptak';

  @override
  String get searchThisLibrary => 'Søk i dette biblioteket...';

  @override
  String get searchEllipsis => 'Søk...';

  @override
  String noResultsForQuery(String query) {
    return 'Ingen resultater for «$query»';
  }

  @override
  String searchFailedError(String error) {
    return 'Søket mislyktes: $error';
  }

  @override
  String get seerr => 'Seerr';

  @override
  String get seerrAccountType => 'Seerr-kontotype';

  @override
  String get jellyfinAccount => 'Jellyfin';

  @override
  String get localAccount => 'Lokalt';

  @override
  String get savedMedia => 'Lagrede medier';

  @override
  String get tvShows => 'TV-programmer';

  @override
  String get music => 'Musikk';

  @override
  String get musicAlbums => 'Musikkalbum';

  @override
  String get noMediaInFilter => 'Ingen media i dette filteret';

  @override
  String get noDownloadedMediaYet => 'Ingen nedlastede medier ennå';

  @override
  String get browseLibrary => 'Bla gjennom biblioteket';

  @override
  String get deleteDownload => 'Slett nedlasting';

  @override
  String removeItemAndFiles(String name) {
    return 'Vil du fjerne «$name» og filene?';
  }

  @override
  String tracksCount(int count) {
    return '$count spor';
  }

  @override
  String get album => 'Album';

  @override
  String get playAlbum => 'Spill album';

  @override
  String failedToLoadAlbum(String error) {
    return 'Kunne ikke laste inn albumet: $error';
  }

  @override
  String noDownloadedTracksForAlbum(String name) {
    return 'Fant ingen nedlastede spor for $name.';
  }

  @override
  String get season => 'Sesong';

  @override
  String get errorLoadingEpisodes => 'Feil ved innlasting av episoder';

  @override
  String get noDownloadedEpisodes => 'Ingen nedlastede episoder';

  @override
  String get deleteEpisode => 'Slett episode';

  @override
  String removeName(String name) {
    return 'Vil du fjerne «$name»?';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String seasonEpisodeLabel(int season, int episode) {
    return 'S$season E$episode';
  }

  @override
  String episodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String get seriesNotFound => 'Finner ikke serien';

  @override
  String get errorLoadingSeries => 'Feil ved innlasting av serien';

  @override
  String get downloadedEpisodes => 'Nedlastede episoder';

  @override
  String seasonNumber(int number) {
    return 'Sesong $number';
  }

  @override
  String seasonChip(int number) {
    return 'S$number';
  }

  @override
  String get specials => 'Spesialtilbud';

  @override
  String get deleteSeason => 'Slett sesong';

  @override
  String deleteAllEpisodesInSeason(String season) {
    return 'Vil du slette alle nedlastede episoder i $season?';
  }

  @override
  String episodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episoder',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String get storageManagement => 'Lagringshåndtering';

  @override
  String get storageBreakdown => 'Lagringssammenbrudd';

  @override
  String get downloadedItems => 'Nedlastede elementer';

  @override
  String get activeDownloads => 'Aktive nedlastinger';

  @override
  String savedMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementer',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String savedMediaOfLimit(String used, String limit) {
    return '$used av $limit';
  }

  @override
  String get savedMediaSelectItems => 'Velg elementer';

  @override
  String get savedMediaNoDownloads => 'Ingenting lagret ennå';

  @override
  String get savedMediaNoDownloadsDetail =>
      'Nedlastinger du starter vises her og kan spilles uten tilkobling.';

  @override
  String get savedMediaNoActiveDownloads => 'Ingenting lastes ned akkurat nå';

  @override
  String get savedMediaNoResults => 'Ingen nedlastinger samsvarer med søket';

  @override
  String get savedMediaPlayFromStart => 'Spill fra start';

  @override
  String get savedMediaGoToDetails => 'Gå til detaljer';

  @override
  String get savedMediaDeleteDownload => 'Slett nedlasting';

  @override
  String savedMediaDeleteSeason(String season) {
    return 'Slett $season';
  }

  @override
  String savedMediaDeleteEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slett $count episoder',
      one: 'Slett 1 episode',
    );
    return '$_temp0';
  }

  @override
  String get savedMediaOpenShow => 'Åpne serie';

  @override
  String get savedMediaPlayNextUnwatched => 'Spill neste usette';

  @override
  String get savedMediaRead => 'Les';

  @override
  String get savedMediaCancelDownload => 'Avbryt nedlasting';

  @override
  String get sortBySize => 'Størrelse';

  @override
  String get sortByName => 'Navn';

  @override
  String get sortByDateAdded => 'Dato lagt til';

  @override
  String get storageLimit => 'Lagringsgrense';

  @override
  String get noLimit => 'Ingen grense';

  @override
  String get deleteAllDownloads => 'Slett alle nedlastinger';

  @override
  String get deleteAllDownloadsWarning =>
      'Dette vil fjerne alle nedlastede mediefiler og kan ikke angres.';

  @override
  String get deleteAll => 'Slett alle';

  @override
  String get deleteSelected => 'Slett valgte';

  @override
  String deleteSelectedCount(int count) {
    return 'Vil du slette $count nedlastede elementer?';
  }

  @override
  String get musicAndAudiobooks => 'Musikk og lydbøker';

  @override
  String get images => 'Bilder';

  @override
  String get database => 'Database';

  @override
  String ofStorageLimit(String limit) {
    return 'av grensen på $limit';
  }

  @override
  String get settings => 'Innstillinger';

  @override
  String get settingsSearchHint => 'Søk i innstillinger';

  @override
  String get authentication => 'Autentisering';

  @override
  String get autoLoginServerManagement =>
      'Automatisk pålogging, serveradministrasjon';

  @override
  String get pinCode => 'PIN-kode';

  @override
  String get setUpPinCodeProtection => 'Sett opp PIN-kodebeskyttelse';

  @override
  String get parentalControls => 'Foreldrekontroll';

  @override
  String get contentRatingRestrictions => 'Begrensninger for innholdsvurdering';

  @override
  String get bitRateResolutionBehavior => 'Bitrate, oppløsning, oppførsel';

  @override
  String get languageSizeAppearance => 'Språk, størrelse, utseende';

  @override
  String get qualityStorage => 'Kvalitet, lagring';

  @override
  String get mediaRequestIntegration => 'Integrasjon av mediaforespørsel';

  @override
  String get switchServer => 'Bytt server';

  @override
  String get signOut => 'Logg ut';

  @override
  String get versionLicenses => 'Versjon, lisenser';

  @override
  String get account => 'Konto';

  @override
  String get signInAndSecurity => 'Innlogging og sikkerhet';

  @override
  String get administration => 'Administrasjon';

  @override
  String get serverSettingsUsersLibraries =>
      'Serverinnstillinger, brukere, biblioteker';

  @override
  String get customization => 'Tilpasning';

  @override
  String get themeAndLayout => 'Tema og layout';

  @override
  String get videoAndSubtitles => 'Video og undertekster';

  @override
  String get pluginAndRequests => 'Plugin og forespørsler';

  @override
  String get customizeAccountPlaybackInterface =>
      'Tilpass konto, avspilling og grensesnittadferd';

  @override
  String optionsCount(int count) {
    return '$count alternativer';
  }

  @override
  String get themeAndAppearance => 'Tema og utseende';

  @override
  String get focusBorderColor => 'Fokuser kantfarge';

  @override
  String get watchedIndicators => 'Sette indikatorer';

  @override
  String get always => 'Alltid';

  @override
  String get mixedRowsOnly => 'Bare blandede rader';

  @override
  String get hideUnwatched => 'Skjul uovervåket';

  @override
  String get episodesOnly => 'Kun episoder';

  @override
  String get never => 'Aldri';

  @override
  String get focusExpansionAnimation => 'Fokus utvidelsesanimasjon';

  @override
  String get desktopUiScale => 'Skalering av grensesnitt';

  @override
  String get scaleFocusedCards =>
      'Skaler fokuserte eller svevende kort og fliser';

  @override
  String get backgroundBackdrops => 'Bakgrunn Bakgrunner';

  @override
  String get showBackdropImages => 'Vis bakteppebilder bak innhold';

  @override
  String get seriesThumbnails => 'Serieminiatyrbilder';

  @override
  String get seriesThumbnailsDescription =>
      'Bare episoder: bruk seriegrafikk som samsvarer med hver radbildetype.';

  @override
  String get homeRowInfoOverlay => 'Hjem Rad Info Overlay';

  @override
  String get showTitleMetadataOnHomeRows =>
      'Vis tittel og metadata når du blar gjennom hjemmerader';

  @override
  String get clockDisplay => 'Klokkevisning';

  @override
  String get inMenus => 'I Menyer';

  @override
  String get inVideo => 'I video';

  @override
  String get seasonalEffects => 'Sesongeffekter';

  @override
  String get seasonalEffectsDescription =>
      'Visuelle effekter og sesongmessige dekorasjoner';

  @override
  String get loadingAnimation => 'Lasteanimasjon';

  @override
  String get loadingAnimationDescription =>
      'Tilpass lasteanimasjonene som brukes i Tortugarr';

  @override
  String get loadingAnimationConfiguration => 'Oppsett av lasteanimasjon';

  @override
  String get loadingAnimationImage => 'Bilde';

  @override
  String get loadingAnimationImageMoonfinLogo => 'Tortugarr-logo';

  @override
  String get loadingAnimationImageSpinner => 'Spinner';

  @override
  String get loadingAnimationImageRunner => 'Løper';

  @override
  String get loadingAnimationImageMoonPhases => 'Månefaser';

  @override
  String get loadingAnimationImageMoonfinPhases => 'Tortugarr-faser';

  @override
  String get loadingAnimationImageNeonfinPhases => 'Neonfaser';

  @override
  String get loadingAnimationSize => 'Animasjonsstørrelse';

  @override
  String get loadingAnimationSizeThumbnail => 'Miniatyr';

  @override
  String get loadingAnimationSizeSmall => 'Liten';

  @override
  String get loadingAnimationSizeMedium => 'Middels';

  @override
  String get loadingAnimationSizeLarge => 'Stor';

  @override
  String get loadingAnimationPosition => 'Animasjonsplassering';

  @override
  String get loadingAnimationPositionTopLeft => 'Øverst til venstre';

  @override
  String get loadingAnimationPositionTopCenter => 'Øverst i midten';

  @override
  String get loadingAnimationPositionTopRight => 'Øverst til høyre';

  @override
  String get loadingAnimationPositionMiddleLeft => 'Midt til venstre';

  @override
  String get loadingAnimationPositionMiddle => 'Midten';

  @override
  String get loadingAnimationPositionMiddleRight => 'Midt til høyre';

  @override
  String get loadingAnimationPositionBottomLeft => 'Nederst til venstre';

  @override
  String get loadingAnimationPositionBottomCenter => 'Nederst i midten';

  @override
  String get loadingAnimationPositionBottomRight => 'Nederst til høyre';

  @override
  String get loadingAnimationPositionBouncing => 'Sprettende';

  @override
  String get loadingAnimationSpeed => 'Animasjonshastighet';

  @override
  String get loadingAnimationSpeedSlow => 'Sakte';

  @override
  String get loadingAnimationSpeedModerate => 'Moderat';

  @override
  String get loadingAnimationSpeedFast => 'Rask';

  @override
  String get loadingAnimationSpeedUltra => 'Ultra';

  @override
  String get showLoadingAnimationText => 'Vis tekst';

  @override
  String get loadingAnimationPreview => 'Forhåndsvisning';

  @override
  String get snow => 'Snø';

  @override
  String get fireworks => 'Fyrverkeri';

  @override
  String get confetti => 'Konfetti';

  @override
  String get fallingLeaves => 'Fallende blader';

  @override
  String get seasonalChristmas => 'Jul';

  @override
  String get seasonalPetals => 'Vårblader';

  @override
  String get seasonalFireflies => 'Ildfluer';

  @override
  String get seasonalHalloween => 'Halloween';

  @override
  String get seasonalDensity => 'Tetthet';

  @override
  String get seasonalDensityLight => 'Lett';

  @override
  String get seasonalDensityNormal => 'Normal';

  @override
  String get seasonalDensityHeavy => 'Tett';

  @override
  String get seasonalRow => 'Sesongrad';

  @override
  String get seasonalRowDescription =>
      'Vis en rad med høytidsfilmer fra biblioteket ditt, med forslag fra Seerr når det er tilgjengelig.';

  @override
  String get seasonalRowSubtitle => 'Sesong';

  @override
  String get seasonalRowCountry => 'Land';

  @override
  String get seasonalRowCountryAuto => 'Automatisk';

  @override
  String get countryUnitedStates => 'USA';

  @override
  String get countryCanada => 'Canada';

  @override
  String get seasonalRowCountryOther => 'Annet';

  @override
  String get seasonalRowHolidays => 'Høytider';

  @override
  String get seasonalRowHolidaysHint =>
      'Fjern haken for en høytid for å skjule raden.';

  @override
  String get holidayNewYear => 'Nyttår';

  @override
  String get holidayValentines => 'Valentinsdagen';

  @override
  String get holidayEaster => 'Påske';

  @override
  String get holidayPride => 'Pride';

  @override
  String get holidayHalloween => 'Halloween';

  @override
  String get holidayThanksgiving => 'Thanksgiving';

  @override
  String get holidayChristmas => 'Julefilmer';

  @override
  String get holidayLunarNewYear => 'Kinesisk nyttår';

  @override
  String get holidayDiwali => 'Diwali';

  @override
  String get themeMusic => 'Temamusikk';

  @override
  String get playThemeMusicOnDetailPages =>
      'Spill av temamusikk på detaljsidene';

  @override
  String get themeMusicVolume => 'Temamusikkvolum';

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get themeMusicOnHomeRows => 'Temamusikk på Home Rows';

  @override
  String get playWhenBrowsingHomeScreen =>
      'Spill når du surfer på startskjermen';

  @override
  String get loopThemeMusic => 'Gjenta temamusikk';

  @override
  String get loopThemeMusicSubtitle =>
      'Gjenta sporet i stedet for å spille det én gang';

  @override
  String get detailsBackgroundBlur => 'Detaljer Bakgrunnsuskarphet';

  @override
  String get detailsBackgroundOpacity => 'Gjennomsiktighet for detaljbakgrunn';

  @override
  String pixelValue(int value) {
    return '$value px';
  }

  @override
  String get browsingBackgroundBlur => 'Bla gjennom bakgrunnsuskarphet';

  @override
  String get maxStreamingBitrate => 'Maks streaming bitrate';

  @override
  String get maxResolution => 'Maks oppløsning';

  @override
  String get playerZoomMode => 'Spillerzoommodus';

  @override
  String get settingsScrollWheelAction => 'Musehjul';

  @override
  String get settingsScrollWheelActionDescription =>
      'Velg hva rulling med musehjulet over videoen gjør under avspilling.';

  @override
  String get scrollWheelActionOff => 'Av';

  @override
  String get scrollWheelActionSeek => 'Spol (fram / tilbake)';

  @override
  String get scrollWheelActionVolume => 'Volum';

  @override
  String get playerTooltipVolume => 'Volum';

  @override
  String get fit => 'Passe';

  @override
  String get autoCrop => 'Automatisk beskjæring';

  @override
  String get cropBlackBars => 'Beskjær svarte felt';

  @override
  String get settingsCropBlackBarsDescription =>
      'Finn innkodede svarte felt etter at avspillingen starter, beskjær dem og fyll skjermen. Beskjær på nytt fra zoomknappen i spilleren.';

  @override
  String get cropBlackBarsRecropInterval => 'Intervall for ny beskjæring';

  @override
  String get cropBlackBarsOnce => 'Én gang ved start';

  @override
  String get cropBlackBarsEverySecond => 'Hvert sekund';

  @override
  String get settingsCropBlackBarsIntervalDescription =>
      'Følg endringer i bildeforholdet under avspilling.';

  @override
  String get playerRecroppingBlackBars => 'Beskjærer svarte felt på nytt';

  @override
  String get stretch => 'Strekke';

  @override
  String get refreshRateSwitching => 'Bytte av oppdateringsfrekvens';

  @override
  String get disabled => 'Deaktivert';

  @override
  String get manual => 'Manuell';

  @override
  String get autoDetect => 'Finn automatisk';

  @override
  String get scaleOnTv => 'Skala på TV';

  @override
  String get scaleOnDevice => 'Skala på enheten';

  @override
  String get trickPlay => 'Forhåndsbilder ved spoling';

  @override
  String get showPreviewThumbnailsWhenSeeking =>
      'Vis forhåndsvisningsminiatyrer når du søker';

  @override
  String get trickplayDisplayStyleSingle => 'Enkelt miniatyrbilde';

  @override
  String get trickplayDisplayStyleStrip => 'Filmstripe';

  @override
  String get trickplayModeFull => 'Fullskjerm';

  @override
  String get trickplaySettingsPreviewHint =>
      'Dra glidebryteren for å forhåndsvise spoling';

  @override
  String get trickplayPreviewScale => 'Størrelse på forhåndsvisning';

  @override
  String get trickplayVerticalOffset => 'Avstand fra tidslinjen';

  @override
  String get trickplayFollowScrubPosition => 'Følg spoleposisjonen';

  @override
  String get trickplayFollowScrubPositionSubtitle =>
      'Forhåndsvisningen glir langs tidslinjen mens du spoler, i stedet for å bli stående midt på';

  @override
  String get trickplayPauseWhileScrubbing => 'Pause under spoling';

  @override
  String get trickplayPauseWhileScrubbingSubtitle =>
      'Avspillingen settes på pause mens du spoler og fortsetter når du trykker spill av. Slå av for å fortsette avspillingen og hoppe rett til det nye stedet';

  @override
  String get showDescriptionOnPause => 'Vis beskrivelse på pause';

  @override
  String get dimVideoShowOverview =>
      'Demp video og vis oversiktstekst mens den er satt på pause';

  @override
  String get showChapterMarkers => 'Kapittelmerker';

  @override
  String get showChapterMarkersDescription =>
      'Merk hvor hvert kapittel starter på tidslinjen';

  @override
  String get osdLockButton => 'OSD-låseknapp';

  @override
  String get osdLockButtonDescription =>
      'Vis en låseknapp som blokkerer berøringsinndata inntil den trykkes lenge';

  @override
  String get playerSwipeGestures => 'Sveip for volum og lysstyrke';

  @override
  String get playerSwipeGesturesDescription =>
      'Sveip opp eller ned i spilleren for å endre lysstyrke til venstre og volum til høyre';

  @override
  String get osdButtons => 'Spillerknapper';

  @override
  String get osdButtonsDescription => 'Velg hvilke knapper avspilleren viser';

  @override
  String get osdButtonsSectionDescription =>
      'Avspillingskontrollene vises alltid. Resten bestemmer du selv, og hver type enhet har sin egen liste.';

  @override
  String get detailButtons => 'Handlingsknapper';

  @override
  String get detailButtonsDescription =>
      'Velg hvilke knapper detaljsiden viser';

  @override
  String get detailButtonsSectionDescription =>
      'Spill av er alltid først, og de låste knappene vises alltid. Resten bestemmer du selv, og hver type enhet har sin egen liste.';

  @override
  String get actionButtonsOnScreen => 'Handlingsknapper på skjermen';

  @override
  String get actionButtonsOnScreenDescription =>
      'Velg hvor mange handlingsknapper som vises før resten legges i menyen Flere handlinger.';

  @override
  String get actionButtonsOnScreenAuto => 'Auto (temastandard)';

  @override
  String get actionButtonsOnScreenPlayOnly => '1 (bare Spill av)';

  @override
  String get actionButtonsOnScreenAll => 'Alle (vannrett rulling)';

  @override
  String get detailMetadata => 'Metadatarad';

  @override
  String get detailMetadataDescription =>
      'Velg og sorter hvilke metadata detaljskjermen viser';

  @override
  String get detailMetadataSectionDescription =>
      'Slå metadataelementer av eller på, og bestem rekkefølgen de vises i på detaljskjermen. Hver type enhet har sin egen liste.';

  @override
  String get detailMetadataYear => 'Utgivelsesår';

  @override
  String get detailMetadataParentalRating => 'Aldersgrense';

  @override
  String get detailMetadataRuntimeAndSeasons => 'Spilletid og sesonger';

  @override
  String get detailMetadataStatus => 'Seriestatus';

  @override
  String get detailMetadataStatusSubtitle =>
      'Viser om serien fortsetter, er avsluttet eller kommer tilbake';

  @override
  String get detailMetadataGenres => 'Sjangre';

  @override
  String get detailMetadataSeerrAvailability => 'Seerr-tilgjengelighet';

  @override
  String get detailMetadataSeerrAvailabilitySubtitle =>
      'Viser forespørsels- og tilgjengelighetsstatus fra Seerr';

  @override
  String get detailMetadataUpcomingEpisodeDate => 'Kommende episoder';

  @override
  String get detailMetadataUpcomingEpisodeDateSubtitle =>
      'Bruker Sonarr og TMDB til å vise kommende utgivelsesdatoer';

  @override
  String get detailSections => 'Seksjoner';

  @override
  String get detailSectionsDescription =>
      'Velg hvilke deler av detaljskjermen som skal vises';

  @override
  String get detailSectionsScreenDescription =>
      'Bare seksjonene den valgte detaljstilen kan vise, er listet opp. Skjuler du en, skjules den i alle stiler som har den.';

  @override
  String get detailSectionGroupHeader => 'Topptekst';

  @override
  String get detailSectionGroupSections => 'Seksjoner';

  @override
  String get detailSectionGroupPerson => 'Personsider';

  @override
  String get detailSectionGroupCollection => 'Samlingssider';

  @override
  String get detailSectionGroupOther => 'Annet';

  @override
  String get detailSectionLogo => 'Logo';

  @override
  String get detailSectionLogoSubtitle => 'Viser tittelen som tekst når av';

  @override
  String get detailSectionTagline => 'Slagord';

  @override
  String get detailSectionPoster => 'Plakat';

  @override
  String get detailSectionVersionBadge => 'Versjonsmerke';

  @override
  String get detailSectionUpNext => 'Neste';

  @override
  String get detailSectionLyrics => 'Sangtekst';

  @override
  String get detailSectionCast => 'Skuespillere';

  @override
  String get detailSectionCastSubtitle => 'Også på samlingssider';

  @override
  String get detailSectionCrew => 'Regissører og manusforfattere';

  @override
  String get detailSectionStudios => 'Studioer';

  @override
  String get detailSectionChapters => 'Kapitler';

  @override
  String get detailSectionExtras => 'Ekstra';

  @override
  String get detailSectionCollections => 'Samlinger';

  @override
  String get detailSectionMoreLikeThis => 'Mer som dette';

  @override
  String get detailSectionMoreLikeThisSubtitle =>
      'Også lignende album og artister';

  @override
  String get detailSectionMoreEpisodes => 'Flere episoder';

  @override
  String get detailSectionMoreEpisodesSubtitle => 'På episodesider';

  @override
  String get detailSectionMediaInfo => 'Medieinfo';

  @override
  String get detailSectionMediaInfoSubtitle =>
      'Fil, strømmer og sjekk for direkteavspilling';

  @override
  String get detailSectionSeerrGenresTags => 'Sjangre og tagger';

  @override
  String get detailSectionSeerrStats => 'Statistikk';

  @override
  String get detailSectionSeerrRecommendations => 'Anbefalinger';

  @override
  String get detailSectionSeerrSimilar => 'Lignende titler';

  @override
  String get detailSectionSeerrCollection => 'Samlingsbanner';

  @override
  String get detailSectionSeerrPersonAppearances => 'Opptredener';

  @override
  String get detailSectionSeerrPersonCrew => 'Stabskreditter';

  @override
  String get detailSectionPersonPagesSubtitle => 'På personsider';

  @override
  String get detailSectionBiography => 'Biografi';

  @override
  String get detailSectionBirthplace => 'Fødested';

  @override
  String get detailSectionGuestAppearances => 'Gjesteopptredener';

  @override
  String get detailSectionMusicVideos => 'Musikkvideoer';

  @override
  String get detailSectionPlaylistOrder => 'Spillelisterekkefølge';

  @override
  String get detailSectionBookGenres => 'Boksjangre';

  @override
  String get detailSectionPhotoExif => 'Bildedetaljer';

  @override
  String upcomingEpisodeNext(String date, int season, int episode) {
    return 'Neste: $date (S$season:E$episode)';
  }

  @override
  String get upcomingEpisodeToday => 'I dag';

  @override
  String get upcomingEpisodeTomorrow => 'I morgen';

  @override
  String get moveUp => 'Flytt opp';

  @override
  String get moveDown => 'Flytt ned';

  @override
  String get buttonOrderHint =>
      'Bruk pilene til å endre rekkefølgen. På en fjernkontroll flytter venstre og høyre den markerte knappen. Slår du av en knapp, havner den under resten.';

  @override
  String get buttonShownInSyncPlayGroup =>
      'Vises bare når du er i en SyncPlay-gruppe';

  @override
  String get orientationLock => 'Lås skjermretning';

  @override
  String get fullscreen => 'Fullskjerm';

  @override
  String get audioBehavior => 'Lydoppførsel';

  @override
  String get downmixToStereo => 'Nedmiks til stereo';

  @override
  String get defaultAudioLanguage => 'Standard lydspråk';

  @override
  String get fallbackAudioLanguage => 'Reservespråk for lyd';

  @override
  String get preferDefaultAudioTrack => 'Foretrekk standard lydspor';

  @override
  String get preferDefaultAudioTrackDescription =>
      'Foretrekk originalt lydspor framfor lokalisert dubbing.';

  @override
  String get preferAudioDescription => 'Foretrekk synstolkingsspor';

  @override
  String get preferAudioDescriptionDescription =>
      'Foretrekk synstolkingsspor framfor vanlige spor.';

  @override
  String get transcodingAudio => 'Omkoding (lyd)';

  @override
  String get directStreamRemux => 'Direktestrøm (remux)';

  @override
  String get transcodingBitrateOrResolution =>
      'Omkoding (bitrate eller oppløsning)';

  @override
  String get transcodingVideoAndAudio => 'Omkoding (video og lyd)';

  @override
  String get transcodingVideo => 'Omkoding (video)';

  @override
  String get autoServerDefault => 'Auto (serverstandard)';

  @override
  String get english => 'engelsk';

  @override
  String get spanish => 'spansk';

  @override
  String get french => 'fransk';

  @override
  String get german => 'tysk';

  @override
  String get italian => 'italiensk';

  @override
  String get portuguese => 'portugisisk';

  @override
  String get japanese => 'japansk';

  @override
  String get korean => 'koreansk';

  @override
  String get chinese => 'kinesisk';

  @override
  String get russian => 'russisk';

  @override
  String get arabic => 'arabisk';

  @override
  String get hindi => 'Hindi';

  @override
  String get dutch => 'nederlandsk';

  @override
  String get swedish => 'svensk';

  @override
  String get norwegian => 'norsk';

  @override
  String get danish => 'dansk';

  @override
  String get finnish => 'finsk';

  @override
  String get polish => 'Pusse';

  @override
  String get ac3Passthrough => 'AC3-gjennomgang';

  @override
  String get dtsPassthrough => 'DTS-gjennomgang';

  @override
  String get trueHdSupport => 'TrueHD-støtte';

  @override
  String get enableDtsPassthrough =>
      'Bitstream DTS-lyd kun til AVR; krever mottakerstøtte og DTS-kildespor';

  @override
  String get settingsAudioFallbackCodec => 'Reservekodek for lyd';

  @override
  String get settingsAudioFallbackCodecDescription =>
      'Velg målformatet for omkoding av flerkanalslyd når kildestrømmen ikke kan spilles direkte eller sendes gjennom.';

  @override
  String get settingsAudioFallbackCodecAuto => 'Oppdag automatisk\n(anbefalt)';

  @override
  String get settingsAudioFallbackCodecAac => 'AAC\n(standard)';

  @override
  String get settingsAudioFallbackCodecAc3 => 'AC3\n(Dolby Digital)';

  @override
  String get settingsAudioFallbackCodecEac3 => 'EAC3\n(Dolby Digital Plus)';

  @override
  String get settingsAudioFallbackCodecMp3 => 'MP3\n(kun stereo)';

  @override
  String get settingsAudioFallbackCodecOpus => 'Opus\n(effektiv)';

  @override
  String get settingsAudioFallbackCodecFlac => 'FLAC\n(tapsfri)';

  @override
  String get settingsMaxAudioChannels => 'Maks antall lydkanaler';

  @override
  String get settingsMaxAudioChannelsDescription =>
      'Angi maksimalt antall kanaler i lydoppsettet ditt. Flerkanalsstrømmer som overskrider denne grensen, blir nedmikset eller omkodet.';

  @override
  String get settingsMaxAudioChannelsAuto =>
      'Oppdag automatisk\n(maskinvarestandard)';

  @override
  String get settingsMaxAudioChannelsMono => '1.0 Mono';

  @override
  String get settingsMaxAudioChannelsStereo => '2.0 Stereo';

  @override
  String get settingsMaxAudioChannels3_0 => '3.0 / 2.1 Surround';

  @override
  String get settingsMaxAudioChannels4_0 => '4.0 / 3.1 Kvadrofonisk';

  @override
  String get settingsMaxAudioChannels5_0 => '5.0 / 4.1 Surround';

  @override
  String get settingsMaxAudioChannels5_1 => '5.1 Surround';

  @override
  String get settingsMaxAudioChannels6_1 => '6.1 Surround';

  @override
  String get settingsMaxAudioChannels7_1 => '7.1 Surround';

  @override
  String get settingsAudioPassthroughAdvanced => 'Passthrough (avansert)';

  @override
  String get settingsAudioCodecPassthrough => 'Kodek-passthrough';

  @override
  String get settingsAudioCodecPassthroughDescription =>
      'Aktiver bare formater som AVR-en eller HDMI-mottakeren din støtter.';

  @override
  String get settingsAudioEac3Passthrough => 'EAC3-passthrough';

  @override
  String get settingsAudioDtsCorePassthrough => 'DTS Core-passthrough';

  @override
  String get settingsAudioDtsHdPassthrough => 'DTS-HD MA-passthrough';

  @override
  String get settingsAudioPassthroughMode => 'Passthrough';

  @override
  String get settingsAudioPassthroughModeDescription =>
      'Hvordan komprimert surroundlyd kommer frem til TV-en eller forsterkeren.';

  @override
  String get settingsAudioPassthroughModeDisabled =>
      'Av (dekod alltid på denne enheten)';

  @override
  String get settingsAudioPassthroughModeAuto =>
      'Auto (etter hva enheten støtter)';

  @override
  String get settingsAudioPassthroughModeManual =>
      'Manuell (velg formater nedenfor)';

  @override
  String get settingsAudioPassthroughOutput => 'Passthrough-utgang';

  @override
  String get settingsAudioPassthroughOutputDescription =>
      'Hvem som pakker bitstrømmer for HDMI-koblingen. Prøv app-pakkeren hvis passthrough er stille eller hakker på denne enheten.';

  @override
  String get settingsAudioPassthroughOutputPlatform =>
      'Automatisk, systemets pakker (AudioTrack RAW)';

  @override
  String get settingsAudioPassthroughOutputIec => 'App-pakker (AudioTrack IEC)';

  @override
  String get settingsAudioPassthroughOutputIecLabel => 'App (IEC)';

  @override
  String get settingsDownmixToStereoDescription =>
      'Miks all dekodet lyd ned til to kanaler.';

  @override
  String get settingsAudioEac3IncludesAtmos =>
      'Bitstream E-AC-3, inkludert Dolby Atmos (JOC).';

  @override
  String get settingsAudioDtsHdIncludesDtsX =>
      'Bitstream DTS-HD, inkludert DTS:X.';

  @override
  String get settingsAudioTrueHdIncludesAtmos =>
      'Bitstream TrueHD, inkludert Dolby Atmos.';

  @override
  String get settingsAudioTrueHdPassthrough => 'TrueHD-passthrough';

  @override
  String get settingsDetectedAudioCapabilities => 'Oppdagede lydfunksjoner';

  @override
  String get settingsDetectedAudioCapabilitiesUnavailable =>
      'Ingen øyeblikksbilde av kjøretidsfunksjoner er tilgjengelig ennå.';

  @override
  String get settingsAudioRouteLabel => 'Rute';

  @override
  String get settingsAudioDecodeLabel => 'Dekoding';

  @override
  String get settingsAudioPassthroughLabel => 'Passthrough';

  @override
  String get settingsAudioHdRoute => 'HD-lydrute';

  @override
  String get settingsAudioRouteHdmi => 'HDMI';

  @override
  String get settingsAudioRouteArc => 'ARC';

  @override
  String get settingsAudioRouteEarc => 'eARC';

  @override
  String get settingsAudioRouteBluetooth => 'Bluetooth';

  @override
  String get settingsAudioRouteSpeaker => 'Høyttaler';

  @override
  String get settingsAudioRouteHeadphones => 'Hodetelefoner';

  @override
  String settingsAudioPcmChannels(int count) {
    return '$count kan. PCM';
  }

  @override
  String get settingsAudioDiagnostics => 'Diagnostikk';

  @override
  String get settingsAudioDiagnosticsVideoLevel => 'Videonivå';

  @override
  String get settingsAudioDiagnosticsVideoRange => 'Videoområde';

  @override
  String get settingsAudioDiagnosticsSubtitleCodec => 'Undertekstkodek';

  @override
  String get settingsAudioDiagnosticsAllowedAudioCodecs =>
      'Tillatte lydkodeker';

  @override
  String get settingsAudioDiagnosticsHlsMpegTsAudioCodecs =>
      'HLS MPEG-TS-lydkodeker';

  @override
  String get settingsAudioDiagnosticsHlsFmp4AudioCodecs =>
      'HLS fMP4-lydkodeker';

  @override
  String get settingsAudioDiagnosticsAudioSpdifPassthrough =>
      'audio-spdif-passthrough';

  @override
  String get settingsAudioDiagnosticsActiveAudioRoute => 'Aktiv lydrute';

  @override
  String get settingsAudioDiagnosticsRouteHdAudioSupport =>
      'HD-lydstøtte for ruten';

  @override
  String get nightMode => 'Nattmodus';

  @override
  String get compressDynamicRange => 'Komprimer dynamisk område';

  @override
  String get advancedMpv => 'Avansert mpv';

  @override
  String get enableCustomMpvConf => 'Aktiver tilpasset mpv.conf';

  @override
  String get applyMpvConfBeforePlayback =>
      'Bruk en brukerspesifisert mpv.conf før avspillingen starter';

  @override
  String get unsafeAdvancedMpvOptions => 'Usikre avanserte mpv-alternativer';

  @override
  String get unsafeMpvOptionsDescription =>
      'Tillat et bredere sett med mpv-alternativer. Kan bryte avspillingsadferd.';

  @override
  String get hardwareDecoding => 'Maskinvaredekoding';

  @override
  String get hardwareDecodingSubtitle =>
      'Lar videobrikken i enheten pakke ut bildet. La den stå på, med mindre avspillingen feiler.';

  @override
  String get nextUpAndQueuing => 'Neste opp og kø';

  @override
  String get nextUpDisplay => 'Visning av Neste opp';

  @override
  String get extended => 'Utvidet';

  @override
  String get minimal => 'Minimal';

  @override
  String get nextUpTimeout => 'Neste Tidsavbrudd';

  @override
  String secondsValue(int value) {
    return '$value s';
  }

  @override
  String get mediaQueuing => 'Mediakø';

  @override
  String get autoQueueNextEpisodes => 'Auto-kø neste episoder';

  @override
  String get stillWatchingPrompt => '«Ser du fortsatt?»-spørsmål';

  @override
  String afterEpisodesAndHours(int episodes, double hours) {
    return 'Etter $episodes episoder / $hours t';
  }

  @override
  String get resumeAndSkip => 'Fortsett og hopp over';

  @override
  String get resumeRewind => 'Fortsett tilbakespoling';

  @override
  String get unpauseRewind => 'Slå på pause';

  @override
  String get fiveSeconds => '5 sekunder';

  @override
  String get tenSeconds => '10 sekunder';

  @override
  String get fifteenSeconds => '15 sekunder';

  @override
  String get thirtySeconds => '30 sekunder';

  @override
  String get skipBackLength => 'Hopp tilbake Lengde';

  @override
  String get skipForwardLength => 'Hopp fremover lengde';

  @override
  String get customMpvConfPath => 'Egendefinert mpv.conf-bane';

  @override
  String get notSetMpvConf =>
      'Ikke satt. Tortugarr vil prøve en standard mpv.conf i app/data-mapper.';

  @override
  String get selectMpvConf => 'Velg mpv.conf';

  @override
  String get pathToMpvConf => '/bane/til/mpv.conf';

  @override
  String get subtitleStyleDescription =>
      'Stilinnstillinger (størrelse, farge, offset) gjelder for tekstbaserte undertekster (SRT, VTT, TTML). ASS/SSA-undertekster bruker sin egen innebygde stil med mindre \"ASS/SSA Direct Play\" er slått av. Bitmap-undertekster (PGS, DVB, VobSub) kan ikke endres.';

  @override
  String get defaultSubtitleLanguage => 'Standard undertekstspråk';

  @override
  String get subtitleDownloadLanguages =>
      'Språk for nedlasting av undertekster';

  @override
  String get subtitleDownloadLanguagesDescription =>
      'Språk det søkes i når undertekster lastes ned, opptil 5. Auto søker i ett språk valgt ut fra standard undertekstspråk eller videoen.';

  @override
  String get preferredSecondarySubtitleLanguage =>
      'Foretrukket språk for sekundære undertekster';

  @override
  String get defaultToNoSubtitles => 'Standard til Ingen undertekster';

  @override
  String get turnOffSubtitlesByDefault => 'Slå av undertekster som standard';

  @override
  String get subtitleSize => 'Undertekststørrelse';

  @override
  String get primarySubtitleSlot => 'Primær';

  @override
  String get secondarySubtitleSlot => 'Sekundær';

  @override
  String get secondarySubtitleTrack => 'Sekundært underteksspor';

  @override
  String decreaseValue(String setting) {
    return 'Senk $setting';
  }

  @override
  String increaseValue(String setting) {
    return 'Øk $setting';
  }

  @override
  String get textFillColor => 'Tekstfyllfarge';

  @override
  String get backgroundColor => 'Bakgrunnsfarge';

  @override
  String get textStrokeColor => 'Tekst Strekfarge';

  @override
  String get subtitleCustomization => 'Tilpasning av undertekster';

  @override
  String get subtitleCustomizationDescription =>
      'Tilpass undertekstens utseende';

  @override
  String get subtitleMode => 'Undertekstmodus';

  @override
  String get subtitleModeFlagged => 'Flagget';

  @override
  String get subtitleModeAlways => 'Alltid';

  @override
  String get subtitleModeForeign => 'Fremmedspråk';

  @override
  String get subtitleModeForced => 'Tvunget';

  @override
  String get subtitleModeFlaggedDescription =>
      'Spiller spor som internt er merket som «default» eller «forced» i mediefilens metadata.';

  @override
  String get subtitleModeAlwaysDescription =>
      'Laster inn og viser undertekster automatisk hver gang en video starter.';

  @override
  String get subtitleModeForeignDescription =>
      'Slår automatisk på undertekster hvis standard lydspor er på et fremmed språk.';

  @override
  String get subtitleModeForcedDescription =>
      'Laster bare inn undertekster som er eksplisitt merket med forced-flagget.';

  @override
  String get subtitleModeNoneDescription =>
      'Deaktiverer automatisk innlasting av undertekster helt.';

  @override
  String get fallbackSubtitleLanguage => 'Reservespråk for undertekster';

  @override
  String get subtitleStream => 'Undertekststrøm';

  @override
  String get subtitlePreviewText =>
      'Den raske brunreven hopper over den late hunden';

  @override
  String get verticalOffset => 'Vertikal offset';

  @override
  String get pgsDirectPlay => 'PGS direktespill';

  @override
  String get directPlayPgsSubtitles => 'Direkteavspilling av PGS-undertekster';

  @override
  String get assSsaDirectPlay => 'ASS/SSA-direkteavspilling';

  @override
  String get directPlayAssSsaSubtitles =>
      'Direkteavspilling av ASS/SSA-undertekster';

  @override
  String get white => 'Hvit';

  @override
  String get black => 'Svart';

  @override
  String get yellow => 'Gul';

  @override
  String get green => 'Grønn';

  @override
  String get cyan => 'Cyan';

  @override
  String get red => 'Rød';

  @override
  String get transparent => 'Gjennomsiktig';

  @override
  String get semiTransparentBlack => 'Semi-transparent svart';

  @override
  String get semiTransparentWhite => 'Halvgjennomsiktig hvit';

  @override
  String get lightGray => 'Lysegrå';

  @override
  String get darkGray => 'Mørkegrå';

  @override
  String get blue => 'Blå';

  @override
  String get magenta => 'Magenta';

  @override
  String get global => 'Global';

  @override
  String get desktop => 'Skrivebord';

  @override
  String get mobile => 'Mobil';

  @override
  String get tv => 'TV';

  @override
  String loadedProfileSettings(String profile) {
    return 'Lastet inn profilinnstillinger for $profile.';
  }

  @override
  String failedToLoadProfileSettings(String profile) {
    return 'Kunne ikke laste inn profilinnstillinger for $profile.';
  }

  @override
  String syncedSettingsToProfile(String profile) {
    return 'Synkroniserte lokale innstillinger til $profile-profilen.';
  }

  @override
  String get syncing => 'Synkroniserer...';

  @override
  String resetProfileTitle(String profile) {
    return 'Tilbakestille $profile?';
  }

  @override
  String resetProfileDescription(String profile) {
    return 'Dette sletter profilen $profile fra serveren og setter alle synkroniserte innstillinger på denne enheten tilbake til standard.';
  }

  @override
  String get resetGlobalProfileDescription =>
      'Dette sletter alle lagrede profiler fra serveren og setter alle synkroniserte innstillinger på denne enheten tilbake til standard.';

  @override
  String profileReset(String profile) {
    return 'Profilen $profile er tilbakestilt til standard.';
  }

  @override
  String get resetRatingsTitle => 'Tilbakestille vurderinger?';

  @override
  String get resetRatingsDescription =>
      'Dette setter alle innstillinger for vurderinger tilbake til standard, også hvilke kilder som vises og rekkefølgen de vises i.';

  @override
  String get ratingsReset => 'Vurderingene er tilbakestilt til standard.';

  @override
  String failedToResetProfile(String profile) {
    return 'Kunne ikke tilbakestille profilen $profile.';
  }

  @override
  String get profileSyncHidden => 'Profilsynkronisering skjult';

  @override
  String get enablePluginSyncDescription =>
      'Aktiver Server Plugin Sync i Plugin-innstillingene for å vise profilkontroller her.';

  @override
  String get quality => 'Kvalitet';

  @override
  String get defaultDownloadQuality => 'Standard nedlastingskvalitet';

  @override
  String get network => 'Nettverk';

  @override
  String get wifiOnlyDownloads => 'Kun WiFi-nedlastinger';

  @override
  String get tvOfflineDownloads => 'Slå på frakoblede nedlastinger';

  @override
  String get tvOfflineDownloadsSubtitle =>
      'Vis nedlastingshandlinger på elementsider';

  @override
  String get reportDownloadsActivity => 'Vis nedlastinger på serveren';

  @override
  String get reportDownloadsActivitySubtitle =>
      'La serveradministratoren se dine omkodede nedlastinger i dashbordet';

  @override
  String get onlyDownloadOnWifi => 'Last ned kun når du er koblet til WiFi';

  @override
  String get storage => 'Lagring';

  @override
  String get storageUsed => 'Lagring brukt';

  @override
  String get manage => 'Administrer';

  @override
  String get calculating => 'Beregner...';

  @override
  String get downloadLocation => 'Last ned plassering';

  @override
  String get defaultLabel => 'Misligholde';

  @override
  String get sdCard => 'SD-kort';

  @override
  String get downloadLocationLimitedByAndroid =>
      'Android lar bare Tortugarr skrive til egne mapper, og denne enheten har ingen flyttbar lagring. Slå på Lagre i Nedlastinger-mappen over for å legge nedlastinger et sted andre apper når dem.';

  @override
  String get saveToDownloadsFolder => 'Lagre i nedlastingsmappen';

  @override
  String get downloadsVisibleToOtherApps =>
      'Nedlastinger/Tortugarr — synlig for andre apper';

  @override
  String get dangerZone => 'Faresone';

  @override
  String get clearAllDownloads => 'Fjern alle nedlastinger';

  @override
  String get original => 'Opprinnelig';

  @override
  String get changeDownloadLocation => 'Endre nedlastingssted';

  @override
  String get changeDownloadLocationDescription =>
      'Nye nedlastinger vil bli lagret i den valgte mappen. Eksisterende nedlastinger forblir på gjeldende plassering og kan administreres fra lagringsinnstillingene.';

  @override
  String get confirm => 'Bekrefte';

  @override
  String get cannotWriteToFolder =>
      'Kan ikke skrive til valgt mappe. Velg et annet sted eller gi lagringstillatelser.';

  @override
  String get saveToDownloadsFolderQuestion => 'Lagre i nedlastingsmappen?';

  @override
  String get saveToDownloadsFolderDescription =>
      'Nedlastede medier vil bli lagret i Nedlastinger/Tortugarr på enheten din. Disse filene vil være synlige for andre apper som galleriet eller musikkspilleren.\n\nEksisterende nedlastinger forblir på deres nåværende plassering.';

  @override
  String get transcodingTimeRemainingUnavailable =>
      'Omkoding: Gjenstående tid er utilgjengelig';

  @override
  String get enable => 'Aktiver';

  @override
  String get clearAllDownloadsWarning =>
      'Dette vil slette alle nedlastede medier og kan ikke angres.';

  @override
  String get clearAll => 'Fjern alle';

  @override
  String get navigationStyle => 'Navigasjonsstil';

  @override
  String get topBar => 'Toppbar';

  @override
  String get leftSidebar => 'Venstre sidefelt';

  @override
  String get showShuffleButton => 'Vis Shuffle-knappen';

  @override
  String get showGenresButton => 'Vis sjangre-knapp';

  @override
  String get showFavoritesButton => 'Vis favoritter-knappen';

  @override
  String get showLiveTvButton => 'Vis Direkte-TV-knapp';

  @override
  String get showDownloadsButton => 'Vis knappen Lagret på enheten';

  @override
  String get showLibrariesInToolbar => 'Vis biblioteker i verktøylinjen';

  @override
  String get navbarAlwaysExpanded => 'Vis alltid etiketter i navigasjonslinjen';

  @override
  String get showSeerrButton => 'Vis Seerr-knapp';

  @override
  String get navbarOpacity => 'Navbar opasitet';

  @override
  String get navbarColor => 'Navbar farge';

  @override
  String get gray => 'Grå';

  @override
  String get darkBlue => 'Mørkeblått';

  @override
  String get purple => 'Lilla';

  @override
  String get teal => 'Blågrønn';

  @override
  String get navy => 'Marine';

  @override
  String get charcoal => 'Kull';

  @override
  String get brown => 'Brun';

  @override
  String get darkRed => 'Mørk rød';

  @override
  String get darkGreen => 'Mørkegrønn';

  @override
  String get slate => 'Skifer';

  @override
  String get indigo => 'Indigo';

  @override
  String get libraryDisplay => 'Bibliotekvisning';

  @override
  String get posterLabel => 'Plakat';

  @override
  String get thumbnailLabel => 'Miniatyrbilde';

  @override
  String get bannerLabel => 'Banner';

  @override
  String get overridePerLibrarySettings =>
      'Overstyr innstillinger per bibliotek';

  @override
  String get applyImageTypeToAllLibraries =>
      'Bruk bildetype på alle biblioteker';

  @override
  String get multiServerLibraries => 'Multi-server biblioteker';

  @override
  String get showLibrariesFromAllServers =>
      'Vis biblioteker fra alle tilkoblede servere';

  @override
  String get mergeRecentRowsByType => 'Slå sammen nylige rader etter type';

  @override
  String get mergeRecentRowsByTypeDescription =>
      'Slå sammen separate biblioteker av samme type for radene Nylig lagt til og Nylig utgitt på startskjermen.';

  @override
  String get libraryView => 'Bibliotekvisning';

  @override
  String get libraryStyle => 'Stil for videobibliotek';

  @override
  String get libraryStyleDescription =>
      'Klassisk er den opprinnelige toppen med ikonknapper. Moderne samler søk og knapper for sortering, gruppering og filter med tekst i én linje. Dokket flytter kontrollene og bokstavene til et sidepanel.';

  @override
  String get libraryStyleDescriptionPhone =>
      'Klassisk er den opprinnelige toppen med ikonknapper. Moderne legger til brikker for sortering, gruppering og filter med tekst under søket. Dokket holder kontrollene i en linje nederst på skjermen.';

  @override
  String get libraryStyleClassic => 'Klassisk';

  @override
  String get libraryStyleModern => 'Moderne';

  @override
  String get libraryStyleDocked => 'Dokket';

  @override
  String get bookLibraryStyle => 'Stil for bokbibliotek';

  @override
  String get bookLibraryStyleDescription =>
      'Klassisk er de opprinnelige hyllene under en fremhevet tittel. Lesesal starter med det du leser, på store kort. Bokhandel blar gjennom hele biblioteket i et rutenett.';

  @override
  String get bookLibraryStyleClassic => 'Klassisk';

  @override
  String get bookLibraryStyleReadingRoom => 'Lesesal';

  @override
  String get bookLibraryStyleBookstore => 'Bokhandel';

  @override
  String get musicLibraryStyle => 'Stil for musikkbibliotek';

  @override
  String get musicLibraryStyleDescription =>
      'Klassisk er de opprinnelige radene under et Hopp inn igjen-kort. Hurtigtilgang starter med et rutenett av nylige album og spillelister. Oppslukende starter med albumet du hører på.';

  @override
  String get musicLibraryStyleClassic => 'Klassisk';

  @override
  String get musicLibraryStyleQuickAccess => 'Hurtigtilgang';

  @override
  String get musicLibraryStyleImmersive => 'Oppslukende';

  @override
  String get jumpBackIn => 'Hopp inn igjen';

  @override
  String get yourPlaylists => 'Dine spillelister';

  @override
  String get fromThisAlbum => 'Fra dette albumet';

  @override
  String get searchMusic => 'Søk i musikk';

  @override
  String bookSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serier',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String bookInProgressCount(int count) {
    return '$count påbegynt';
  }

  @override
  String bookBrowseAllTitles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bla gjennom alle $count titler',
      one: 'Bla gjennom 1 tittel',
    );
    return '$_temp0';
  }

  @override
  String get searchBooks => 'Søk i bøker';

  @override
  String get libraryShowLabel => 'Vis';

  @override
  String get libraryAToZ => 'A til Å';

  @override
  String get libraryJumpToLetter => 'Gå til bokstav';

  @override
  String get enableFolderView => 'Aktiver mappevisning';

  @override
  String get showFolderBrowsingOption => 'Vis alternativ for mappelesing';

  @override
  String get groupItemsIntoCollections => 'Grupper elementer i samlinger';

  @override
  String get hideCollectionAssociatedItems =>
      'Skjul bibliotekelementer som tilhører en samling, når du blar i bibliotekene';

  @override
  String get groupItemsIntoCollectionsDialogTitle =>
      'Merknad om bibliotekgruppering';

  @override
  String get groupItemsIntoCollectionsDialogMessage =>
      'For å bruke denne innstillingen må du sørge for at bibliotekinnstillingene «Group movies into collections» og/eller «Group shows into collections» er aktivert under bibliotekets visningsinnstillinger på Jellyfin- eller Emby-serveren.';

  @override
  String get libraryVisibility => 'Bibliotekets synlighet';

  @override
  String get libraryVisibilityDescription =>
      'Slå av og på hjemmesidens synlighet per bibliotek. Start Tortugarr på nytt for at endringer skal tre i kraft.';

  @override
  String get showInNavigation => 'Vis i navigasjon';

  @override
  String get showInLatestMedia => 'Vis under nylig lagt til/utgitt media';

  @override
  String get libraryOrder => 'Bibliotekrekkefølge';

  @override
  String get libraryOrderSubtitle => 'Velg rekkefølgen på bibliotekene dine';

  @override
  String get libraryOrderDescription =>
      'Bibliotekene dine vises i denne rekkefølgen på Mine medier, radene for nylig lagt til og navigasjonslinjen. Rekkefølgen lagres på serverkontoen din, så andre apper du logger inn i bruker den også.';

  @override
  String get libraryOrderTvHint =>
      'Trykk venstre eller høyre for å flytte det markerte biblioteket.';

  @override
  String get libraryOrderSaveFailed => 'Kunne ikke lagre bibliotekrekkefølgen';

  @override
  String get sourceLibraries => 'Kildebiblioteker';

  @override
  String get sourceCollections => 'Kildesamlinger';

  @override
  String get excludedGenres => 'Ekskluderte sjangere';

  @override
  String get selectAll => 'Velg alle';

  @override
  String itemsSelected(int count) {
    return '$count valgt';
  }

  @override
  String get mediaBar => 'Mediefelt';

  @override
  String get mediaSources => 'Mediekilder';

  @override
  String get behavior => 'Oppførsel';

  @override
  String get seconds => 'sekunder';

  @override
  String get mediaBarMode => 'Media Bar stil';

  @override
  String get mediaBarModeDescription =>
      'Velg mellom ulike mediefeltstiler, eller slå av mediefeltet';

  @override
  String get mediaBarModeMoonfin => 'Tortugarr';

  @override
  String get mediaBarModeMakd => 'MakD';

  @override
  String get mediaBarModeOff => 'Av';

  @override
  String get mediaBarModeBookshelf => 'Bokhylle';

  @override
  String get mediaBarModeGallery => 'Galleri';

  @override
  String get mediaBarModeBanner => 'Banner';

  @override
  String get mediaBarModeAya => 'Aya';

  @override
  String get enableMediaBar => 'Aktiver Media Bar';

  @override
  String get showFeaturedContentSlideshow =>
      'Vis lysbildefremvisning av fremhevet innhold hjemme';

  @override
  String get contentType => 'Innholdstype';

  @override
  String get mediaBarSourceType => 'Kilde';

  @override
  String get mediaBarSourceRandom => 'Tilfeldig';

  @override
  String get moviesAndTvShows => 'Filmer og TV-serier';

  @override
  String get moviesOnly => 'Kun filmer';

  @override
  String get tvShowsOnly => 'Kun TV-serier';

  @override
  String get itemCount => 'Vareantall';

  @override
  String get noneSelected => 'Ingen valgt';

  @override
  String get noneExcluded => 'Ingen ekskludert';

  @override
  String get autoAdvance => 'Automatisk fremføring';

  @override
  String get autoAdvanceSlides => 'Gå automatisk videre til neste lysbilde';

  @override
  String get autoAdvanceInterval => 'Automatisk fremføringsintervall';

  @override
  String get trailerPreview => 'Forhåndsvisning av trailer';

  @override
  String get autoPlayTrailers =>
      'Spill av trailere automatisk i mediefeltet etter 3 sekunder';

  @override
  String get trailerAudio => 'Trailerlyd';

  @override
  String get enableTrailerAudio => 'Aktiver lyd for trailere i Media Bar';

  @override
  String get trailerCaptions => 'Undertekster for trailere';

  @override
  String get trailerCaptionsDescription =>
      'Vis undertekster på YouTube-trailere i mediefeltet';

  @override
  String get episodePreview => 'Forhåndsvisning av episode';

  @override
  String get mediaPreview => 'Medieforhåndsvisning';

  @override
  String get episodePreviewDescription =>
      'Spill en 30-sekunders innebygd forhåndsvisning på fokuserte, svevende eller lenge trykket kort';

  @override
  String get mediaPreviewDescription =>
      'Spill en 30-sekunders innebygd forhåndsvisning på fokuserte, svevende eller lenge trykket kort';

  @override
  String get previewAudio => 'Forhåndsvis lyd';

  @override
  String get enablePreviewAudio => 'Aktiver lyd for medieforhåndsvisninger';

  @override
  String get latestMedia => 'Nylig lagt til';

  @override
  String get recentlyReleased => 'Nylig utgitt';

  @override
  String get recentlyReleasedSeriesType => 'Sorter Nylig utgitte serier etter';

  @override
  String get recentlyReleasedSeriesTypeDescription =>
      'Sorter radene Nylig utgitte serier på startskjermen etter serie, nyeste sesong eller sendedato for nyeste episode';

  @override
  String get myMedia => 'Mine medier';

  @override
  String get myMediaSmall => 'Mine medier (liten)';

  @override
  String get continueWatching => 'Fortsett å se';

  @override
  String get resumeAudio => 'Gjenoppta lyd';

  @override
  String get resumeBooks => 'Gjenoppta bøker';

  @override
  String get activeRecordings => 'Aktive opptak';

  @override
  String get playlists => 'Spillelister';

  @override
  String get liveTV => 'Direktesendt TV';

  @override
  String get favoriteChannels => 'Favorittkanaler';

  @override
  String get resetToDefaults => 'Tilbakestill til standard';

  @override
  String get homeRowPosterSize => 'Hjemmerads plakatstørrelse';

  @override
  String get configureImageTypeForEachRow =>
      'Konfigurer bildetype for hver aktiverte startrad';

  @override
  String get mergeContinueWatchingAndNextUp =>
      'Slå sammen Fortsett å se og neste opp';

  @override
  String get combineBothRows =>
      'Kombiner begge radene til en enkelt hjemmeseksjon';

  @override
  String get nextUpMaxDays => 'Maks dager i Neste opp';

  @override
  String get nextUpMaxDaysDescription =>
      'Hvor lenge en serie blir liggende i Neste opp etter at du sist så den';

  @override
  String daysValue(int days) {
    return '$days dager';
  }

  @override
  String get fullScreenRows => 'Utvidede hjem-rader';

  @override
  String get fullScreenRowsDescription =>
      'Begrens hjem-rader til én rad per skjerm';

  @override
  String get homeRowsPadding => 'Vertikal avstand mellom rader på startsiden';

  @override
  String get homeRowsPaddingDescription =>
      'Tilpass den vertikale avstanden mellom radene på startsiden';

  @override
  String get homeRowsGenresAndStudios => 'Sjangre og studioer';

  @override
  String get homeRowsExternalLists => 'Eksterne lister';

  @override
  String get perRowSettings => 'Innstillinger per rad';

  @override
  String get autoLogin => 'Automatisk pålogging';

  @override
  String get lastUser => 'Siste bruker';

  @override
  String get currentUser => 'Gjeldende bruker';

  @override
  String get alwaysAuthenticate => 'Autentiser alltid';

  @override
  String get requirePasswordWithToken => 'Krev passord selv med lagret token';

  @override
  String get confirmExit => 'Bekreft Avslutt';

  @override
  String get showConfirmationBeforeExiting => 'Vis bekreftelse før du går ut';

  @override
  String get blockContentWithRatings =>
      'Blokker innhold med følgende vurderinger:';

  @override
  String get noContentRatingsFound =>
      'Ingen innholdsvurderinger ble funnet på denne serveren ennå.';

  @override
  String get couldNotLoadServerRatings =>
      'Kunne ikke laste inn servervurderinger. Viser kun lagrede vurderinger.';

  @override
  String get couldNotRefreshRatings =>
      'Kunne ikke oppdatere vurderinger fra serveren. Viser lagrede vurderinger.';

  @override
  String get enablePinCode => 'Aktiver PIN-kode';

  @override
  String get requirePinToAccess =>
      'Krev en PIN-kode for å få tilgang til kontoen din';

  @override
  String get changePin => 'Endre PIN';

  @override
  String get setNewPinCode => 'Angi en ny PIN-kode';

  @override
  String get removePin => 'Fjern PIN-koden';

  @override
  String get removePinProtection => 'Fjern PIN-kodebeskyttelsen';

  @override
  String get screensaver => 'Skjermsparer';

  @override
  String get inAppScreensaver => 'Skjermsparer i appen';

  @override
  String get enableBuiltInScreensaver => 'Aktiver den innebygde skjermspareren';

  @override
  String get mode => 'Modus';

  @override
  String get libraryArt => 'Bibliotekskunst';

  @override
  String get logo => 'Logo';

  @override
  String get clock => 'Klokke';

  @override
  String get timeout => 'Tidsavbrudd';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get dimmingLevel => 'Dimmenivå';

  @override
  String get maxAgeRating => 'Maks aldersvurdering';

  @override
  String get any => 'Noen';

  @override
  String agePlusValue(int age) {
    return '$age+';
  }

  @override
  String get requireAgeRating => 'Krev aldersgrense';

  @override
  String get onlyShowRatedContent => 'Vis kun vurdert innhold';

  @override
  String get displayClockDuringScreensaver => 'Vis klokke under skjermsparer';

  @override
  String get clockModeStatic => 'Statisk';

  @override
  String get clockModeBouncing => 'Sprettende';

  @override
  String get screensaverGeneralSettings => 'Generelle innstillinger';

  @override
  String get screensaverVisualComponents => 'Visuelle elementer';

  @override
  String get screensaverLibraryContent => 'Bibliotekinnhold';

  @override
  String get screensaverBackdrop => 'Bakgrunn';

  @override
  String get screensaverBackdropBlack => 'Svart';

  @override
  String get screensaverBackdropMoonfin => 'Tortugarr';

  @override
  String get screensaverBackdropCalm => 'Rolig';

  @override
  String get screensaverBackdropNeonPulse => 'Neon Pulse';

  @override
  String get screensaverBackdropAurora => 'Nordlys';

  @override
  String get screensaverAdditionalComponent => 'Ekstra element';

  @override
  String get screensaverComponentMoonfinLogo => 'Tortugarr-logo';

  @override
  String get screensaverComponentRunner => 'Løper';

  @override
  String get screensaverComponentMovement => 'Bevegelse for element';

  @override
  String get screensaverComponentPosition => 'Plassering av element';

  @override
  String get screensaverComponentSize => 'Størrelse på element';

  @override
  String get screensaverSourceLibrariesDefault => 'Alle (standard)';

  @override
  String get rottenTomatoesCritics => 'Råtne tomater (kritikere)';

  @override
  String get rottenTomatoesAudience => 'Rotten Tomatoes (publikum)';

  @override
  String get imdb => 'IMDb';

  @override
  String get tmdb => 'TMDB';

  @override
  String get metacritic => 'Metakritisk';

  @override
  String get metacriticUser => 'Metacritic (bruker)';

  @override
  String get trakt => 'Trakt';

  @override
  String get letterboxd => 'Letterboxd';

  @override
  String get myAnimeList => 'MyAnimeList';

  @override
  String get aniList => 'AniList';

  @override
  String get communityRating => 'Fellesskapsvurdering';

  @override
  String get ratings => 'Vurderinger';

  @override
  String get additionalRatings => 'Ytterligere vurderinger';

  @override
  String get showMdbListAndTmdbRatings => 'Vis MDBList- og TMDB-vurderinger';

  @override
  String get ratingLabels => 'Vurderingsetiketter';

  @override
  String get showLabelsNextToIcons =>
      'Vis etiketter ved siden av rangeringsikoner';

  @override
  String get ratingBadges => 'Vurderingsmerker';

  @override
  String get showDecorativeBadges => 'Vis dekorative merker bak vurderinger';

  @override
  String get episodeRatings => 'Episodevurderinger';

  @override
  String get showRatingsOnEpisodes =>
      'Vis vurderinger på individuelle episoder';

  @override
  String get ratingSources => 'Rangeringskilder';

  @override
  String get ratingSourcesDescription =>
      'Aktiver og omorganiser vurderingskildene som vises i hele appen';

  @override
  String get pluginDetected => 'Plugin oppdaget';

  @override
  String get pluginNotDetected => 'Plugin ikke oppdaget';

  @override
  String get pluginNotDetectedDescription =>
      'Serverplugin er for øyeblikket ikke oppdaget. Lokale innstillinger bruker fortsatt de lagrede verdiene eller innebygde standardinnstillingene.';

  @override
  String get pluginConnected => 'Tilkoblet';

  @override
  String pluginConnectedVersion(String version) {
    return 'Tilkoblet, versjon $version';
  }

  @override
  String get pluginSyncOn => 'Synkronisering på';

  @override
  String get pluginSyncOff => 'Synkronisering av';

  @override
  String get syncProfileDescription =>
      'Denne enheten synkroniserer med profilen du velger, til du velger en annen.';

  @override
  String get profileAppliesEverywhere => 'Gjelder overalt';

  @override
  String get profileOverridesGlobal => 'Overstyrer Global';

  @override
  String get profileThisDevice => 'Denne enheten';

  @override
  String get profileLoad => 'Last inn';

  @override
  String get profileLoadSubtitle => 'Server til denne enheten';

  @override
  String get profileSaveSubtitle => 'Denne enheten til server';

  @override
  String resetNamedProfile(String profile) {
    return 'Tilbakestill $profile-profil';
  }

  @override
  String get recentRequests => 'Nylige forespørsler';

  @override
  String get recentlyAdded => 'Nylig lagt til';

  @override
  String get trending => 'På vei opp';

  @override
  String get popularMovies => 'Populære filmer';

  @override
  String get movieGenres => 'Filmsjangre';

  @override
  String get upcomingMovies => 'Kommende filmer';

  @override
  String get studios => 'Studioer';

  @override
  String get popularSeries => 'Populær serie';

  @override
  String get seriesGenres => 'Seriesjangre';

  @override
  String get upcomingSeries => 'Kommende serie';

  @override
  String get networks => 'Nettverk';

  @override
  String get tags => 'Tagger';

  @override
  String get genresAndTags => 'Sjangre og tagger';

  @override
  String get seerrDiscoveryRows => 'Seerr-oppdagelsesrader';

  @override
  String get seerrDiscoverSliders => 'Seerr-oppdagelsesrader';

  @override
  String get yourWatchlist => 'Din visningsliste';

  @override
  String get resetRowsToDefaults => 'Tilbakestill rader til standardverdier';

  @override
  String get enableSeerr => 'Aktiver Seerr';

  @override
  String get showSeerrInNavigation =>
      'Vis Seerr i navigasjon (krever serverplugin)';

  @override
  String get seerrUnavailable =>
      'Utilgjengelig fordi serverplugin Seerr-støtte er deaktivert.';

  @override
  String get nsfwFilter => 'NSFW-filter';

  @override
  String get hideAdultContent => 'Skjul voksent innhold i resultater';

  @override
  String get showMissingCollectionItems =>
      'Vis manglende elementer i samlinger';

  @override
  String get showMissingCollectionItemsDesc =>
      'Ta med manglende elementer på samlingssider';

  @override
  String get showSeerrAvailabilityBadges => 'Vis Seerr-tilgjengelighetsmerker';

  @override
  String get showSeerrAvailabilityBadgesDescription =>
      'Vis merker for sesongtilgjengelighet på detaljsider';

  @override
  String get seerrNotificationsSection => 'Varsler';

  @override
  String get seerrNotifyNewRequestsTitle => 'Varsler om nye forespørsler';

  @override
  String get seerrNotifyNewRequestsSubtitle =>
      'Varsle meg når noen sender inn en forespørsel';

  @override
  String get seerrNotifyLibraryAddedTitle => 'Oppdateringer om forespørsler';

  @override
  String get seerrNotifyLibraryAddedSubtitle =>
      'Godkjent, avslått og lagt til i biblioteket ditt';

  @override
  String get seerrNotifyIssuesTitle => 'Oppdateringer om saker';

  @override
  String get seerrNotifyIssuesSubtitle => 'Nye saker, svar og løsninger';

  @override
  String get seerrNotifyNewMediaTitle => 'Nytt innhold lagt til';

  @override
  String get seerrNotifyNewMediaSubtitle =>
      'Alt nytt som legges til i serverbiblioteket';

  @override
  String loggedInAs(String username) {
    return 'Logget inn som: $username';
  }

  @override
  String get discoverRows => 'Seerr-oppdagelsesside';

  @override
  String get discoverRowsDescriptionPlugin =>
      'Aktiver radene du vil se på Seerr-hovedsiden. Dra for å endre rekkefølge. Egendefinert rekkefølge synkroniseres med Moonbase.';

  @override
  String get discoverRowsDescription =>
      'Aktiver radene du vil se på Seerr-hovedsiden. Dra for å endre rekkefølge. Egendefinert rekkefølge synkroniseres med Moonbase.';

  @override
  String get enabled => 'Aktivert';

  @override
  String get hidden => 'Skjult';

  @override
  String get aboutTitle => 'Om';

  @override
  String versionValue(String version) {
    return 'Versjon $version';
  }

  @override
  String get openSourceLicenses => 'Åpen kildekode-lisenser';

  @override
  String get sourceCode => 'Kildekode';

  @override
  String get sourceCodeUrl => 'https://github.com/tortugarr/tortugarr';

  @override
  String get checkForUpdatesNow => 'Se etter oppdateringer nå';

  @override
  String get checksLatestDesktopRelease =>
      'Sjekker siste desktop-utgivelse for denne plattformen';

  @override
  String get youAreUpToDate => 'Du er oppdatert.';

  @override
  String get couldNotCheckForUpdates =>
      'Kunne ikke se etter oppdateringer akkurat nå.';

  @override
  String get noCompatibleUpdate =>
      'Finner ingen kompatibel oppdateringspakke for denne plattformen.';

  @override
  String get updateChecksNotSupported =>
      'Oppdateringssjekker støttes ikke på denne plattformen.';

  @override
  String get updateNotificationsDisabled =>
      'Oppdateringsvarsler er deaktivert.';

  @override
  String get pleaseWaitBeforeChecking => 'Vent før du sjekker igjen.';

  @override
  String get latestUpdateAlreadyShown => 'Siste oppdatering ble allerede vist.';

  @override
  String get updateAvailable => 'Oppdatering tilgjengelig.';

  @override
  String updateAvailableVersion(String version) {
    return 'Oppdatering tilgjengelig: v$version';
  }

  @override
  String get updateNotifications => 'Oppdater varsler';

  @override
  String get showWhenUpdatesAvailable =>
      'Vis når oppdateringer er tilgjengelige';

  @override
  String updateAvailableTitle(String version) {
    return 'v$version er tilgjengelig';
  }

  @override
  String get readReleaseNotes => 'Les versjonsmerknader';

  @override
  String get downloadingUpdate => 'Laster ned oppdatering...';

  @override
  String get updateDownloadFailed =>
      'Nedlasting av oppdatering mislyktes. Vennligst prøv igjen.';

  @override
  String get openReleasesPage => 'Åpne utgivelsessiden';

  @override
  String get navigation => 'Navigasjon';

  @override
  String get watchedIndicatorsBackdrops => 'Sette indikatorer, bakgrunner';

  @override
  String get focusColorWatchedIndicatorsBackdrops =>
      'Fokusfarge, overvåkede indikatorer, bakgrunner';

  @override
  String get navbarStyleToolbarAppearance =>
      'Navbar stil, verktøylinjeknapper, utseende';

  @override
  String get featuredContentAppearance => 'Fremhevet innhold, utseende';

  @override
  String get posterSizeImageTypeFolderView =>
      'Plakatstørrelse, bildetype, mappevisning';

  @override
  String gbValue(String value) {
    return '$value GB';
  }

  @override
  String mbValue(int value) {
    return '$value MB';
  }

  @override
  String get imageCacheLimit => 'Grense for bildebuffer';

  @override
  String get clearImageCache => 'Tøm bildebuffer';

  @override
  String get imageCacheCleared => 'Bildebufferen er tømt';

  @override
  String get clear => 'Tøm';

  @override
  String get browse => 'Bla gjennom';

  @override
  String get noResults => 'Ingen resultater';

  @override
  String get seerrAvailableStatus => 'Tilgjengelig';

  @override
  String get seerrRequestedStatus => 'Forespurt';

  @override
  String get seerrDownloading => 'Laster ned';

  @override
  String seerrDownloadingSize(String done, String total) {
    return 'Laster ned · $done / $total';
  }

  @override
  String seerrDownloadedOfTotal(String done, String total) {
    return '$done / $total';
  }

  @override
  String seerrPercentValue(int percent) {
    return '$percent %';
  }

  @override
  String seerrDownloadingPercent(int percent) {
    return 'Laster ned · $percent %';
  }

  @override
  String get seerrImportingStatus => 'Importerer';

  @override
  String itemsCount(int count) {
    return '$count elementer';
  }

  @override
  String get seerrSettings => 'Seerr-innstillinger';

  @override
  String get requestMore => 'Be om mer';

  @override
  String get requestMore4k => 'Be om mer i 4K';

  @override
  String get request => 'Forespør';

  @override
  String get request4k => 'Be om 4K';

  @override
  String get requested4k => '4K forespurt';

  @override
  String get cancelRequest => 'Avbryt forespørsel';

  @override
  String get cancelRequest4k => 'Avbryt 4K-forespørsel';

  @override
  String get playInMoonfin => 'Spill i Tortugarr';

  @override
  String get requestedByLabel => 'Forespurt av';

  @override
  String requestedByName(String name) {
    return 'Forespurt av $name';
  }

  @override
  String get manageRequests => 'Administrer Forespørsler';

  @override
  String get watchlist => 'Se senere';

  @override
  String get onWatchlist => 'På Skal Sjå lista';

  @override
  String get approve => 'Vedta';

  @override
  String get declineAction => 'Avslå';

  @override
  String get similar => 'Lignende';

  @override
  String get recommendations => 'Anbefalinger';

  @override
  String cancelRequestForTitle(String title) {
    return 'Vil du avbryte forespørselen for «$title»?';
  }

  @override
  String cancelCountRequestsForTitle(int count, String title) {
    return 'Vil du avbryte $count forespørsler for «$title»?';
  }

  @override
  String get keep => 'Beholde';

  @override
  String get itemNotFoundInLibrary =>
      'Elementet ble ikke funnet i Tortugarr-biblioteket';

  @override
  String get errorSearchingLibrary => 'Feil ved søk i bibliotek';

  @override
  String budgetAmount(String amount) {
    return 'Budsjett: \$$amount';
  }

  @override
  String revenueAmount(String amount) {
    return 'Inntekter: \$$amount';
  }

  @override
  String seasonsCount(int count, String label) {
    return '$count $label';
  }

  @override
  String requestSeriesOrMovie(String type) {
    return 'Be om $type';
  }

  @override
  String requestSeriesOrMovie4k(String type) {
    return 'Be om $type i 4K';
  }

  @override
  String get submitRequest => 'Send inn forespørsel';

  @override
  String get allSeasons => 'Alle sesonger';

  @override
  String get seerrSeriesContinuing =>
      'Serien fortsetter · Kommende sesonger kan bli forespurt';

  @override
  String get advancedOptions => 'Avanserte alternativer';

  @override
  String get noServiceServersConfigured =>
      'Ingen tjenesteservere er konfigurert';

  @override
  String get server => 'Server';

  @override
  String get qualityProfile => 'Kvalitetsprofil';

  @override
  String get rootFolder => 'Rotmappe';

  @override
  String get showMore => 'Vis mer';

  @override
  String get appearances => 'Opptredener';

  @override
  String get crewSection => 'Mannskap';

  @override
  String ageValue(int age) {
    return 'alder $age';
  }

  @override
  String get noRequests => 'Ingen forespørsler';

  @override
  String get pendingStatus => 'I påvente av';

  @override
  String get declinedStatus => 'Avslått';

  @override
  String get partiallyAvailable => 'Delvis tilgjengelig';

  @override
  String get downloadingStatus => 'Laster ned';

  @override
  String get approvedStatus => 'Godkjent';

  @override
  String get notRequestedStatus => 'Ikke forespurt';

  @override
  String get blocklistedStatus => 'Blokklistet';

  @override
  String get deletedStatus => 'Slettet';

  @override
  String get failedStatus => 'Mislyktes';

  @override
  String get processingStatus => 'Behandles';

  @override
  String modifiedByName(String name) {
    return 'Endret av $name';
  }

  @override
  String get completedStatus => 'Fullført';

  @override
  String get requestErrorDuplicate => 'Denne tittelen er allerede forespurt';

  @override
  String get requestErrorQuota => 'Forespørselsgrensen er nådd';

  @override
  String get requestErrorBlocklisted => 'Denne tittelen er blokkert';

  @override
  String get requestErrorNoSeasons => 'Ingen sesonger igjen å be om';

  @override
  String get requestErrorPermission =>
      'Du har ikke tillatelse til å sende denne forespørselen';

  @override
  String get seerrRequestsTitle => 'Forespørsler';

  @override
  String get seerrIssuesTitle => 'Saker';

  @override
  String get sortNewest => 'Nyeste';

  @override
  String get sortLastModified => 'Sist endret';

  @override
  String get noIssues => 'Ingen saker';

  @override
  String movieQuotaRemaining(int remaining, int limit) {
    return '$remaining av $limit filmforespørsler igjen';
  }

  @override
  String seasonQuotaRemaining(int remaining, int limit) {
    return '$remaining av $limit sesongforespørsler igjen';
  }

  @override
  String partOfCollectionName(String name) {
    return 'Del av $name';
  }

  @override
  String get viewCollection => 'Vis samling';

  @override
  String get requestCollection => 'Be om samling';

  @override
  String collectionMoviesSummary(int total, int available) {
    return '$total filmer · $available tilgjengelige';
  }

  @override
  String requestMoviesCount(int count) {
    return 'Be om $count filmer';
  }

  @override
  String requestingProgress(int current, int total) {
    return 'Ber om $current av $total...';
  }

  @override
  String requestedMoviesCount(int count) {
    return '$count filmer forespurt';
  }

  @override
  String requestedMoviesPartial(int ok, int total) {
    return '$ok av $total filmer forespurt';
  }

  @override
  String get collectionAllRequested =>
      'Alle filmer er allerede tilgjengelige eller forespurt';

  @override
  String get reportIssue => 'Rapporter sak';

  @override
  String get issueTypeVideo => 'Video';

  @override
  String get issueTypeAudio => 'Lyd';

  @override
  String get whatsWrong => 'Hva er galt?';

  @override
  String get allEpisodes => 'Alle episoder';

  @override
  String get episode => 'Episode';

  @override
  String get openStatus => 'Åpen';

  @override
  String get resolvedStatus => 'Løst';

  @override
  String get resolveAction => 'Løs';

  @override
  String get reopenAction => 'Gjenåpne';

  @override
  String reportedByName(String name) {
    return 'Rapportert av $name';
  }

  @override
  String commentsCount(int count) {
    return '$count kommentarer';
  }

  @override
  String get addComment => 'Legg til en kommentar';

  @override
  String get deleteIssueConfirm => 'Vil du slette denne saken?';

  @override
  String get submitReport => 'Send inn rapport';

  @override
  String get tmdbScore => 'TMDB-poengsum';

  @override
  String get releaseDateLabel => 'Utgivelsesdato';

  @override
  String get firstAirDateLabel => 'Første luftdato';

  @override
  String get revenueLabel => 'Inntekter';

  @override
  String get runtimeLabel => 'Kjøretid';

  @override
  String get budgetLabel => 'Budsjett';

  @override
  String get originalLanguageLabel => 'Originalspråk';

  @override
  String get seasonsLabel => 'Sesonger';

  @override
  String get episodesLabel => 'Episoder';

  @override
  String get access => 'Adgang';

  @override
  String get add => 'Legg til';

  @override
  String get address => 'Adresse';

  @override
  String get analytics => 'Analyse';

  @override
  String get catalog => 'Katalog';

  @override
  String get content => 'Innhold';

  @override
  String get copy => 'Kopiere';

  @override
  String get create => 'Skape';

  @override
  String get disable => 'Deaktiver';

  @override
  String get done => 'Ferdig';

  @override
  String get edit => 'Rediger';

  @override
  String get encoding => 'Koding';

  @override
  String get error => 'Feil';

  @override
  String get forward => 'Fremover';

  @override
  String get general => 'Generelt';

  @override
  String get go => 'Gå';

  @override
  String get install => 'Installer';

  @override
  String get installed => 'Installert';

  @override
  String get interval => 'Intervall';

  @override
  String get name => 'Navn';

  @override
  String get networking => 'Nettverk';

  @override
  String get next => 'Neste';

  @override
  String get path => 'Sti';

  @override
  String get paused => 'Pause';

  @override
  String get permissions => 'Tillatelser';

  @override
  String get processing => 'Behandling';

  @override
  String get profile => 'Profil';

  @override
  String get provider => 'Leverandør';

  @override
  String get refresh => 'Forfriske';

  @override
  String get remote => 'Fjernkontroll';

  @override
  String get rename => 'Gi nytt navn';

  @override
  String get revoke => 'Oppheve';

  @override
  String get role => 'Rolle';

  @override
  String get root => 'Rot';

  @override
  String get run => 'Løp';

  @override
  String get search => 'Søk';

  @override
  String get select => 'Velge';

  @override
  String get send => 'Sende';

  @override
  String get sessions => 'Økter';

  @override
  String get set => 'Sett';

  @override
  String get status => 'Status';

  @override
  String get stop => 'Stopp';

  @override
  String get streaming => 'Strømming';

  @override
  String get time => 'Tid';

  @override
  String get trickplay => 'Miniatyrbilder ved spoling';

  @override
  String get uninstall => 'Avinstaller';

  @override
  String get up => 'Opp';

  @override
  String get update => 'Oppdater';

  @override
  String get upload => 'Last opp';

  @override
  String get unmute => 'Slå på lyden';

  @override
  String get mute => 'Demp';

  @override
  String get branding => 'Merkevarebygging';

  @override
  String get adminDrawerDashboard => 'Dashbord';

  @override
  String get adminDrawerAnalytics => 'Analyse';

  @override
  String get adminDrawerSettings => 'Innstillinger';

  @override
  String get adminDrawerBranding => 'Merkevarebygging';

  @override
  String get adminDrawerUsers => 'Brukere';

  @override
  String get adminDrawerLibraries => 'Biblioteker';

  @override
  String get adminDrawerDisplay => 'Visning';

  @override
  String get adminDrawerMetadata => 'Metadata';

  @override
  String get adminDrawerNfo => 'NFO-innstillinger';

  @override
  String get adminDrawerTranscoding => 'Omkoding';

  @override
  String get adminDrawerResume => 'Fortsett';

  @override
  String get adminDrawerStreaming => 'Strømming';

  @override
  String get adminDrawerTrickplay => 'Miniatyrbilder ved spoling';

  @override
  String get adminDrawerDevices => 'Enheter';

  @override
  String get adminDrawerActivity => 'Aktivitet';

  @override
  String get adminDrawerNetworking => 'Nettverk';

  @override
  String get adminDrawerApiKeys => 'API-nøkler';

  @override
  String get adminDrawerBackups => 'Sikkerhetskopier';

  @override
  String get adminDrawerLogs => 'Logger';

  @override
  String get adminDrawerScheduledTasks => 'Planlagte oppgaver';

  @override
  String get adminDrawerPlugins => 'Tillegg';

  @override
  String get adminDrawerRepositories => 'Lagre';

  @override
  String get adminDrawerLiveTv => 'Direktesendt TV';

  @override
  String get adminExitTooltip => 'Avslutt Admin';

  @override
  String get adminPremiereNoteLiveTv =>
      'Direkte-TV krever Emby Premiere. Uten det importerer ikke serveren kanaler eller tar opp noe.';

  @override
  String get adminPremiereNoteBackups =>
      'Sikkerhetskopiering og gjenoppretting krever Emby Premiere når prøveperioden er over.';

  @override
  String get adminGeneralRunAtStartup => 'Start serveren ved oppstart';

  @override
  String get adminGeneralLaunchWebApp =>
      'Åpne nettappen i en nettleser når serveren starter';

  @override
  String get adminGeneralBannerText => 'Bannertekst på startskjermen';

  @override
  String get adminGeneralBannerTextHelp =>
      'Vises for alle brukere på startskjermen deres';

  @override
  String get adminGeneralSectionMaintenance => 'Vedlikeholdsmodus';

  @override
  String get adminGeneralMaintenanceMode => 'Sett serveren i vedlikeholdsmodus';

  @override
  String get adminGeneralMaintenanceModeHelp =>
      'Brukerne ser bare vedlikeholdsmeldingen.';

  @override
  String get adminGeneralMaintenanceMessage => 'Vedlikeholdsmelding';

  @override
  String get adminGeneralMaintenanceMessageHelp =>
      'La stå tomt for en generell melding på hver brukers språk.';

  @override
  String get adminGeneralSectionUpdates => 'Automatiske oppdateringer';

  @override
  String get adminGeneralAutoUpdate => 'Oppdater serveren automatisk';

  @override
  String get adminGeneralAutoRestart =>
      'Start på nytt automatisk for å ta i bruk oppdateringer';

  @override
  String get adminGeneralAutoRestartHelp =>
      'Serveren starter bare på nytt når ingen brukere er aktive.';

  @override
  String adminTaskTriggerSystemEvent(String event) {
    return 'Etter en systemhendelse ($event)';
  }

  @override
  String get adminPluginNeedsPremiere =>
      'Krever Emby Premiere etter 14 dagers gratis prøveperiode';

  @override
  String get adminEmbyBackupsHelp =>
      'Emby tar sikkerhetskopi via tillegget Backup & Restore.';

  @override
  String get adminEmbyBackupsNoPlugin =>
      'Tillegget Backup & Restore er ikke installert. Installer det fra tilleggskatalogen for å ta sikkerhetskopi av serveren.';

  @override
  String get adminEmbyBackupNow => 'Ta sikkerhetskopi nå';

  @override
  String get adminEmbyFullBackup => 'Full sikkerhetskopi';

  @override
  String get adminEmbyLightBackups => 'Sikkerhetskopier av database';

  @override
  String adminEmbyBackupServerVersion(String version) {
    return 'Emby $version';
  }

  @override
  String adminEmbyRestoreConfirm(String name) {
    return 'Gjenopprette $name? Det erstatter serverens biblioteker, innstillinger, brukere og passord, og serveren slås av når det er ferdig. Du må kanskje starte den igjen selv.';
  }

  @override
  String get adminEmbyRestoreServerId => 'Gjenopprett server-ID-en';

  @override
  String get adminEmbyRestoreServerIdHelp =>
      'Slå av dette når du gjenoppretter samme sikkerhetskopi på flere servere.';

  @override
  String get adminEmbyRestoreShuttingDown =>
      'Gjenopprettingen er ferdig og serveren slås av. Start den igjen hvis den ikke starter på nytt av seg selv.';

  @override
  String get adminHiddenRemotely =>
      'Skjul fra innloggingsskjermer ved ekstern tilkobling';

  @override
  String get adminHiddenFromUnusedDevices =>
      'Skjul fra innloggingsskjermer på enheter brukeren aldri har logget inn på';

  @override
  String get adminSimultaneousStreamLimitHelp =>
      'Begrenser hvor mange videoer denne brukeren kan spille av samtidig.';

  @override
  String get adminUnlimited => 'Ubegrenset';

  @override
  String get adminAutoRemoteQuality => 'Automatisk ekstern kvalitet (Mbps)';

  @override
  String get adminAutoRemoteQualityHelp =>
      'Brukes eksternt når spilleren står på automatisk kvalitet. La stå tomt for å oppdage den automatisk.';

  @override
  String get adminAllowCameraUpload => 'Tillat kameraopplasting';

  @override
  String get adminAllowSubtitleDownloading =>
      'Tillat nedlasting av undertekster';

  @override
  String get adminAllowMediaConversion => 'Tillat mediekonvertering';

  @override
  String get adminAllowSyncTranscoding =>
      'Tillat nedlastinger som krever omkoding';

  @override
  String get adminAllowSharingPersonalItems =>
      'Tillat deling av spillelister med andre brukere';

  @override
  String get adminAllowPreferenceAccess =>
      'Tillat endring av eget passord og profilbilde';

  @override
  String get adminTagMode => 'Taggmodus';

  @override
  String get adminEmbyConnect => 'Emby Connect';

  @override
  String get adminEmbyConnectUser => 'Brukernavn eller e-post for Emby Connect';

  @override
  String get adminEmbyConnectHelp =>
      'Lar brukeren logge inn fra hvilken som helst Emby-app uten å kjenne serveradressen.';

  @override
  String get adminEmbyConnectLink => 'Koble til';

  @override
  String get adminEmbyConnectUnlink => 'Koble fra';

  @override
  String get adminEmbyConnectLinked => 'Koblet til Emby Connect';

  @override
  String get adminEmbyConnectPending =>
      'Invitasjon sendt. Koblingen opprettes når den godtas.';

  @override
  String get adminEmbyConnectUnlinked => 'Emby Connect-kobling fjernet';

  @override
  String get adminEmbyConnectNotFound =>
      'Ingen Emby Connect-konto har det brukernavnet eller den e-postadressen.';

  @override
  String get adminLibImportPlaylists => 'Importer spillelistefiler';

  @override
  String get adminLibExcludeFromSearch => 'Utelat fra globalt søk';

  @override
  String get adminLibForcedSubtitlesOnly =>
      'Last bare ned tvungne undertekster';

  @override
  String get adminLibImportCollections =>
      'Importer samlinger fra metadatanedlastere';

  @override
  String get adminLibThumbnailInterval =>
      'Intervall for forhåndsvisningsbilder';

  @override
  String adminLibThumbnailEverySeconds(int count) {
    return 'Hvert $count. sekund';
  }

  @override
  String get adminLibThumbnailAtChapters => 'Ved kapittelmerker';

  @override
  String get adminLibSaveThumbnailsWithMedia =>
      'Lagre forhåndsvisningsbilder i mediemappene';

  @override
  String get adminLibrarySectionMarkers => 'Intromerker';

  @override
  String get adminLibIntroDetection => 'Finn intro';

  @override
  String get adminLibIntroDetectionDuringScan =>
      'Finn intro under biblioteksskanning';

  @override
  String get adminProviderEmbyGuide => 'Emby Guide Data';

  @override
  String get adminLiveTvEmbyGuideSelectLineup =>
      'Velg et kanaloppsett. Hvis ingen vises, sjekk postnummeret. Kanaloppsett krever Emby Premiere.';

  @override
  String get adminLiveTvWakeServer => 'Vekk serveren for opptak';

  @override
  String get adminDrawerLiveTvChannels => 'Direkte-TV-kanaler';

  @override
  String get adminPageDescLiveTvChannels =>
      'Slå kanaler av og på og bestem rekkefølgen';

  @override
  String get adminLiveTvChannelsEmpty =>
      'Ingen kanaler ennå. De vises her når en tuner er satt opp og serveren har importert kanalene.';

  @override
  String get adminTranscodingHwaAdvanced => 'Avansert';

  @override
  String get adminTranscodingHwaHelp =>
      'Avansert lar deg velge og sortere maskinvarekodekene.';

  @override
  String get adminTranscodingHwDecoders => 'Foretrukne maskinvaredekodere';

  @override
  String get adminTranscodingHwEncoders => 'Foretrukne maskinvarekodere';

  @override
  String get adminTranscodingTempPathHelp =>
      'Hvor omkoderen lagrer arbeidsfilene sine. La stå tomt for å bruke serverens datamappe.';

  @override
  String get adminTranscodingThrottleHelp =>
      'Senker farten på omkodingen når nok er bufret, for å redusere CPU-bruken.';

  @override
  String get adminTranscodingDownmixHelp =>
      'Øker volumet når lyden mikses ned. 1 beholder det opprinnelige volumet.';

  @override
  String get adminTranscodingFontExtraction =>
      'Tillat uttrekk av skrifter underveis';

  @override
  String get adminTranscodingMaxResolution => 'Maks oppløsning ved omkoding';

  @override
  String get adminTranscodingMaxResolutionHelp =>
      'En grense for all omkoding, uansett hvilken kvalitet appen ber om.';

  @override
  String get adminTranscodingToneMapSoftware =>
      'Tonemapping ved programvareomkoding';

  @override
  String get adminTranscodingToneMapHardware =>
      'Tonemapping ved maskinvareomkoding';

  @override
  String get adminTranscodingToneMapHelp =>
      'Hindrer at HDR-video ser mørk og blek ut når den omkodes.';

  @override
  String get adminNetworkingLocalAddress => 'Lokal IP-adresse';

  @override
  String get adminNetworkingLocalAddressHelp =>
      'Den lokale adressen serveren gir til apper. La stå tomt for å oppdage den automatisk.';

  @override
  String get adminNetworkingBehindProxy =>
      'HTTPS håndteres av en omvendt proxy';

  @override
  String get adminNetworkingExternalDomain => 'Eksternt domene';

  @override
  String get adminNetworkingExternalDomainHelp =>
      'Et domene eller dynamisk DNS-navn for eksterne tilkoblinger, uten protokoll eller port. Kreves for et eget sertifikat.';

  @override
  String get adminNetworkingUpnp => 'Slå på automatisk porttilordning';

  @override
  String get adminNetworkingUpnpHelp =>
      'Prøver å tilordne den offentlige porten til den lokale porten med UPnP. Noen rutere støtter ikke dette.';

  @override
  String get adminNetworkingProxyHeaders =>
      'Les proxy-headere for klientadresser';

  @override
  String get adminNetworkingProxyHeadersHelp =>
      'Bruker headere som X-Forwarded-For til å finne hver klients adresse. Slå bare på bak en omvendt proxy.';

  @override
  String get adminNetworkingProxyHeadersRemote =>
      'Bare når de inneholder eksterne adresser';

  @override
  String get adminNetworkingIpv4Only => 'Bruk IPv4 for utgående forespørsler';

  @override
  String get adminNetworkingIpv4OnlyHelp =>
      'For når metadataleverandører og andre tjenester ikke kan nås over IPv6.';

  @override
  String get adminOnePerLine => 'Én per linje';

  @override
  String get adminStreamingStreamLimit => 'Maks samtidige videostrømmer';

  @override
  String get adminStreamingStreamLimitHelp =>
      'Hvor mange videoer som kan spilles samtidig på serveren. 0 betyr ingen grense.';

  @override
  String get adminSyncJobsConversions => 'Konverteringsjobber';

  @override
  String get adminSyncJobsDownloads => 'Nedlastingsjobber';

  @override
  String get adminSyncJobsEmpty => 'Ingen jobber';

  @override
  String get adminSyncJobCancel => 'Avbryt jobb';

  @override
  String adminSyncJobCancelConfirm(String name) {
    return 'Avbryte $name og fjerne den fra listen?';
  }

  @override
  String get adminSyncJobConverting => 'Konverterer';

  @override
  String get adminSyncJobReady => 'Klar til overføring';

  @override
  String get adminSyncJobTransferring => 'Overfører';

  @override
  String get adminSyncJobCompletedWithError => 'Fullført med feil';

  @override
  String adminSyncJobItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementer',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String get adminDrawerDatabase => 'Database';

  @override
  String get adminPageDescDatabase => 'Hurtigbufferstørrelse og vedlikehold';

  @override
  String get adminDatabaseWarning =>
      'Dette er avanserte innstillinger. La dem stå på standard med mindre du har grunn til å endre dem.';

  @override
  String get adminDatabaseCacheSize => 'Hurtigbuffer for database (MB)';

  @override
  String get adminDatabaseCacheSizeHelp =>
      'Hvor mye av hver databasefil serveren holder i minnet. Mer kan gjøre serveren raskere. Trer i kraft etter omstart.';

  @override
  String get adminDatabaseOptimize =>
      'Optimaliser databasen når serveren slås av';

  @override
  String get adminDatabaseOptimizeHelp =>
      'Vanligvis gjør dette ingenting, men av og til kjører det en analyse som hjelper serverens spørringer. Avslutning kan ta lengre tid.';

  @override
  String get adminDatabaseAnalysisLimit => 'Radgrense for analyse';

  @override
  String get adminDatabaseAnalysisLimitHelp =>
      'Omtrent hvor mange rader av hver indeks optimaliseringen leser. Flere rader gir bedre resultat, men kan gjøre avslutningen tregere.';

  @override
  String get adminDatabaseVacuum =>
      'Kjør vacuum på databasen ved neste oppstart';

  @override
  String get adminDatabaseVacuumHelp =>
      'Bygger databasefilen på nytt så den tar minst mulig plass, noe som kan bedre ytelsen. Serveren kan ikke brukes mens dette pågår og viser ingen fremdrift, så ikke tving den til å lukkes. Innstillingen slår seg av igjen etter den oppstarten.';

  @override
  String get adminDrawerCinemaIntros => 'Kinointroer';

  @override
  String get adminPageDescCinemaIntros => 'Trailere og introer før avspilling';

  @override
  String get adminCinemaIntrosPlayBefore => 'Spill introer før';

  @override
  String get adminCinemaIntrosUpcoming =>
      'Ta med trailere fra nye og kommende filmer';

  @override
  String get adminCinemaIntrosOlder => 'Ta med trailere fra eldre filmer';

  @override
  String get adminCinemaIntrosLibrary =>
      'Ta med trailere fra filmer i mine biblioteker';

  @override
  String get adminCinemaIntrosLibraryHelp =>
      'Krever at lokale trailere er satt opp.';

  @override
  String get adminCinemaIntrosCount => 'Antall trailere som skal spilles';

  @override
  String get adminCinemaIntrosParental => 'Smart foreldrekontroll';

  @override
  String get adminCinemaIntrosParentalHelp =>
      'Velger bare trailere med samme eller lavere aldersgrense enn det som ses.';

  @override
  String get adminCinemaIntrosUnwatchedOnly =>
      'Spill bare introer før usett innhold';

  @override
  String get adminCinemaIntrosSimilarOnly =>
      'Spill bare trailere som ligner det som ses';

  @override
  String get adminCinemaIntrosSimilarOnlyHelp =>
      'Basert på felles sjangre, tagger, studioer og lignende.';

  @override
  String get adminCinemaIntrosCustom => 'Egne introer';

  @override
  String get adminCinemaIntrosCustomPath => 'Mappe for egne introer';

  @override
  String get adminCinemaIntrosCustomPathHelp =>
      'En mappe med videoer. Én velges tilfeldig og spilles etter trailerne.';

  @override
  String get adminCinemaIntrosCodecPath => 'Mappe for kodek-introer';

  @override
  String get adminCinemaIntrosCodecPathHelp =>
      'En mappe med videoer. En video med filnavn som samsvarer med videokodek, lydkodek, lydprofil eller en tagg spilles før hovedfilmen.';

  @override
  String get adminDrawerDlna => 'DLNA';

  @override
  String get adminPageDescDlna => 'Play To og DLNA-serveren';

  @override
  String get adminDlnaPlayTo => 'Slå på DLNA Play To';

  @override
  String get adminDlnaPlayToHelp =>
      'Emby kan finne enheter på nettverket ditt og styre dem eksternt.';

  @override
  String get adminDlnaServer => 'Slå på DLNA-serveren';

  @override
  String get adminDlnaServerHelp =>
      'Lar serveren strømme medier til DLNA-enheter.';

  @override
  String get adminDlnaDefaultUser => 'Standardbruker';

  @override
  String get adminDlnaDefaultUserHelp =>
      'Hvem sine biblioteker tilkoblede enheter ser. En enhetsprofil kan overstyre dette.';

  @override
  String get adminDlnaDebugLog => 'Slå på feilsøkingslogg for DLNA';

  @override
  String get adminDlnaDebugLogHelp =>
      'Gir store loggfiler. Slå bare på ved feilsøking.';

  @override
  String get adminDrawerCameraUpload => 'Kameraopplasting';

  @override
  String get adminPageDescCameraUpload => 'Hvor bilder fra telefoner lagres';

  @override
  String get adminCameraUploadPath => 'Mappe for kameraopplasting';

  @override
  String get adminCameraUploadPathHelp =>
      'La stå tomt for å bruke standardmappen. En egen mappe må også legges til som bibliotek.';

  @override
  String get adminCameraUploadSubfolders => 'Lag en undermappe for hver enhet';

  @override
  String get adminDrawerConversions => 'Konverteringer';

  @override
  String get adminPageDescConversions => 'Konverterte medier og nedlastinger';

  @override
  String get adminConversionsTempPath => 'Mappe for midlertidige filer';

  @override
  String get adminConversionsTempPathHelp =>
      'Hvor medier lagres mens de konverteres.';

  @override
  String get adminConversionsFullSpeed => 'Konverter i full fart';

  @override
  String get adminConversionsFullSpeedHelp =>
      'Konverteringer kjører sakte som standard for å holde belastningen nede.';

  @override
  String get adminDrawerPremiere => 'Emby Premiere';

  @override
  String get adminPageDescPremiere => 'Lisensstatus og nøkkel';

  @override
  String get adminPremiereActive => 'Premiere er aktiv på denne serveren.';

  @override
  String get adminPremiereInactive =>
      'Denne serveren har ingen Premiere-nøkkel.';

  @override
  String get adminPremiereKeyInvalid =>
      'En nøkkel er satt, men er ikke aktiv. Den kan være skrevet feil eller utløpt.';

  @override
  String get adminPremiereCurrentKey => 'Gjeldende nøkkel';

  @override
  String get adminPremiereNewKey => 'Ny nøkkel';

  @override
  String get adminPremiereNewKeyHint =>
      'Lim inn nøkkelen fra e-posten fra Emby Premiere.';

  @override
  String get adminPremiereSaveKey => 'Lagre nøkkel';

  @override
  String get adminPremiereRemoveKey => 'Fjern nøkkel';

  @override
  String get adminPremiereKeyRejected =>
      'Emby lagret nøkkelen, men godtok den ikke.';

  @override
  String get adminPremiereLoadFailed => 'Kunne ikke laste inn Premiere-status';

  @override
  String get embyPremiereRequiredTitle => 'Emby Premiere kreves';

  @override
  String get embyPremiereRequiredBody =>
      'Dette krever et aktivt Emby Premiere-abonnement på serveren.';

  @override
  String get embyPremiereRequiredSaveBody =>
      'Dette krever et aktivt Emby Premiere-abonnement. Emby beholder innstillingen, men bruker den ikke før Premiere er aktivt.';

  @override
  String get embyPremiereLearnMore => 'Les mer';

  @override
  String get embyPremiereSaveAnyway => 'Lagre likevel';

  @override
  String get embyPremiereEnterKey => 'Skriv inn nøkkel';

  @override
  String get adminPremiereNote =>
      'Krever Emby Premiere. Serveren beholder innstillingen, men bruker den ikke før Premiere er aktivt.';

  @override
  String adminExternalIdLabel(String name) {
    return '$name-ID';
  }

  @override
  String get adminExternalIdTypePerson => 'Person';

  @override
  String get adminExternalIdTypeArtist => 'Artist';

  @override
  String get adminExternalIdTypeAlbumArtist => 'Albumartist';

  @override
  String get adminExternalIdTypeOtherArtist => 'Annen artist';

  @override
  String get adminExternalIdTypeReleaseGroup => 'Utgivelsesgruppe';

  @override
  String get adminExternalIdTypeBook => 'Bok';

  @override
  String get adminPlaybackHwAccelWarning =>
      'Maskinvareakselerasjon kan være ustabil på enkelte systemer. Hold operativsystemet og skjermkortdriverne oppdatert, og sett dette tilbake til Ingen hvis video slutter å spille.';

  @override
  String get adminLibMetadataChangeHelp =>
      'Endringer i metadatainnstillingene gjelder nytt innhold. For å oppdatere eksisterende innhold, oppdater det fra detaljsiden eller oppdater biblioteket.';

  @override
  String get adminLibFetcherSettings => 'Innstillinger for henting';

  @override
  String adminLibImageOptionsTitle(String type) {
    return 'Bildevalg for $type';
  }

  @override
  String get adminLibFetchImages => 'Hent bilder';

  @override
  String get adminLibMaxBackdrops => 'Maks antall bakgrunnsbilder per element';

  @override
  String get adminLibMinBackdropWidth =>
      'Minste bredde for nedlasting av bakgrunnsbilder';

  @override
  String get adminImageTypeArt => 'Clearart';

  @override
  String get adminImageTypeBox => 'Eske';

  @override
  String get adminImageTypeBoxRear => 'Eske (bakside)';

  @override
  String get adminImageTypeDisc => 'Plate';

  @override
  String get adminImageTypeMenu => 'Meny';

  @override
  String get adminActivityMediaDetails => 'Mediedetaljer';

  @override
  String get adminNetworkingOtherPublishedUriHint =>
      'f.eks. 192.168.1.0/24=http://192.168.1.5:8096';

  @override
  String get adminMetadataFieldOriginalLanguage => 'Originalspråk';

  @override
  String get adminMetadataFieldDateAdded => 'Dato lagt til';

  @override
  String get adminMetadataFieldArtists => 'Artister';

  @override
  String get adminMetadataFieldAlbumArtists => 'Albumartister';

  @override
  String get adminMetadataFieldAlbum => 'Album';

  @override
  String get adminMetadataFieldSeriesName => 'Serienavn';

  @override
  String get adminMetadataFieldEpisodeNumber => 'Episodenummer';

  @override
  String get adminMetadataFieldSeasonNumber => 'Sesongnummer';

  @override
  String get adminMetadataFieldTrackNumber => 'Spornummer';

  @override
  String get adminMetadataFieldDiscNumber => 'Platenummer';

  @override
  String get adminMetadataFieldAirTime => 'Sendetid';

  @override
  String get adminMetadataFieldRuntime => 'Spilletid i minutter';

  @override
  String get adminMetadataFieldPlaceOfBirth => 'Fødested';

  @override
  String get adminMetadataFieldBirthDate => 'Fødselsdato';

  @override
  String get adminMetadataFieldBirthYear => 'Fødselsår';

  @override
  String get adminMetadataFieldDeathDate => 'Dødsdato';

  @override
  String get adminMetadataFieldAspectRatio => 'Opprinnelig bildeforhold';

  @override
  String get adminMetadataFieldAirsBeforeSeason => 'Sendes før sesong';

  @override
  String get adminMetadataFieldAirsAfterSeason => 'Sendes etter sesong';

  @override
  String get adminMetadataFieldAirsBeforeEpisode => 'Sendes før episode';

  @override
  String get adminMetadataNamesHelp => 'Skill flere navn med semikolon.';

  @override
  String get adminMetadataSectionRatings => 'Vurderinger';

  @override
  String get adminMetadataItemLocked =>
      'Metadataene for dette elementet er låst. Lås dem opp før du identifiserer elementet.';

  @override
  String get adminMetadataNameOrIdRequired =>
      'Skriv inn et navn eller en ekstern ID.';

  @override
  String get adminLibMetadataReaders => 'Metadatalesere';

  @override
  String adminLibSimilarProvidersFor(String type) {
    return 'Leverandører av lignende elementer: $type';
  }

  @override
  String get adminLibMediaSegmentProviders => 'Leverandører av mediesegmenter';

  @override
  String get adminLibEnableLibrary => 'Slå på biblioteket';

  @override
  String get adminLibEnableLibraryHelp =>
      'Når biblioteket slås av, skjules det for alle brukere.';

  @override
  String get adminLibSaveLyricsWithMedia => 'Lagre sangtekster i mediemappene';

  @override
  String get adminLibUseCustomTagDelimiters =>
      'Bruk eget skilletegn for tagger';

  @override
  String get adminLibCustomTagDelimiters => 'Eget skilletegn for tagger';

  @override
  String get adminLibCustomTagDelimitersHelp =>
      'Tegn som skal brukes som skilletegn mellom tagger.';

  @override
  String get adminLibDelimiterWhitelist => 'Unntaksliste for skilletegn';

  @override
  String get adminLibDelimiterWhitelistHelp =>
      'Elementer som ikke skal deles opp i tagger, ett per linje.';

  @override
  String get adminLibDownloadLanguages => 'Nedlastingsspråk';

  @override
  String get adminLibraryFolderRequired =>
      'Legg til minst én mappe i dette biblioteket.';

  @override
  String get adminRenameLibraryWarning =>
      'Hvis du gir biblioteket nytt navn, mister det alle metadata. Vær forsiktig.';

  @override
  String adminDeleteLibraryConfirm(String name) {
    return 'Fjerne biblioteket «$name»? Filer på disken slettes ikke.';
  }

  @override
  String get adminDeleteLibraryLocations =>
      'Disse medieplasseringene fjernes fra biblioteket:';

  @override
  String get adminRefreshMode => 'Oppdateringsmodus';

  @override
  String get adminRefreshModeScan => 'Søk etter nye og endrede filer';

  @override
  String get adminRefreshModeMissing => 'Søk etter manglende metadata';

  @override
  String get adminReplaceTrickplayImages =>
      'Erstatt eksisterende forhåndsvisningsbilder for spoling';

  @override
  String get adminRefreshDialogHelp =>
      'Metadata oppdateres ut fra innstillingene og internettjenestene som er slått på i kontrollpanelet.';

  @override
  String adminActivityCount(String shown, String total) {
    return '$shown av $total';
  }

  @override
  String get adminLiveTvTabSources => 'Tunere og guide';

  @override
  String get adminLiveTvTabRecordings => 'Opptak';

  @override
  String get adminLiveTvAddTuner => 'Legg til tuner';

  @override
  String get adminLiveTvEditTuner => 'Rediger tuner';

  @override
  String get adminLiveTvTunerType => 'Tunertype';

  @override
  String get adminLiveTvDetectDevices => 'Finn enhetene mine';

  @override
  String get adminLiveTvNoNewDevices => 'Fant ingen nye enheter';

  @override
  String get adminLiveTvDrmNote => 'Kanaler med DRM importeres ikke.';

  @override
  String get adminLiveTvTunerSaved => 'Tuner lagret';

  @override
  String get adminLiveTvDeleteTuner => 'Slett tuner';

  @override
  String get adminLiveTvDeleteTunerConfirm =>
      'Er du sikker på at du vil slette denne tuneren?';

  @override
  String get adminLiveTvDeleteProvider => 'Slett guideleverandør';

  @override
  String get adminLiveTvDeleteProviderConfirm =>
      'Er du sikker på at du vil slette denne guideleverandøren?';

  @override
  String get adminLiveTvProviderSaved => 'Guideleverandør lagret';

  @override
  String get adminLiveTvAddProvider => 'Legg til leverandør';

  @override
  String get adminLiveTvRefreshGuide => 'Oppdater guidedata';

  @override
  String get adminLiveTvMapChannels => 'Tilordne kanaler';

  @override
  String get adminLiveTvNoTunerChannels => 'Fant ingen tunerkanaler';

  @override
  String get adminLiveTvXmltvPathHelp =>
      'En sti eller URL til en XMLTV-fil. Serveren leser den og ser etter oppdateringer. Du er selv ansvarlig for å lage og oppdatere filen.';

  @override
  String adminLiveTvSdCreateAccount(String url) {
    return 'Opprett en konto på $url';
  }

  @override
  String get adminLiveTvSdSignIn => 'Logg inn';

  @override
  String get adminLiveTvSdLineup => 'Kanaloppsett';

  @override
  String get adminLiveTvSdSelectLineup =>
      'Velg et kanaloppsett. Hvis ingen vises, sjekk brukernavn, passord og postnummer.';

  @override
  String get adminLiveTvGuideDays =>
      'Antall dager med guidedata som lastes ned';

  @override
  String get adminLiveTvGuideDaysHelp =>
      'Flere dager lar deg planlegge lenger frem og se flere sendinger, men nedlastingen tar lengre tid. Automatisk velger en verdi ut fra antall kanaler.';

  @override
  String get adminLiveTvRecordingPath => 'Standard opptaksmappe';

  @override
  String get adminLiveTvRecordingPathHelp =>
      'Hvor opptak lagres. Hvis tomt, brukes serverens programdatamappe.';

  @override
  String get adminLiveTvStartWhenPossible => 'Start når mulig';

  @override
  String get adminLiveTvStopWhenPossible => 'Stopp når mulig';

  @override
  String get adminLiveTvMinutesBefore => 'minutter før';

  @override
  String get adminLiveTvMinutesAfter => 'minutter etter';

  @override
  String get adminLiveTvSectionGuide => 'Guidedata';

  @override
  String get adminLiveTvSectionDefaultRecording =>
      'Standard opptaksinnstillinger';

  @override
  String get adminLiveTvSectionMetadata => 'Metadata for opptak';

  @override
  String adminUserLastActivity(String time) {
    return 'Sist aktiv $time';
  }

  @override
  String get adminCurrentPassword => 'Nåværende passord';

  @override
  String get adminChannelAccess => 'Kanaltilgang';

  @override
  String get adminDeviceAccess => 'Enhetstilgang';

  @override
  String get adminDeleteFromAllLibraries => 'Alle biblioteker';

  @override
  String get adminUserDisabledBanner =>
      'Denne brukeren er deaktivert. Slå av Deaktivert under Tillatelser for å la brukeren logge inn igjen.';

  @override
  String get adminNewPasswordEmpty => 'Nytt passord kan ikke være tomt';

  @override
  String get adminScheduleStartBeforeEnd => 'Starttiden må være før sluttiden';

  @override
  String get adminDashboardAlerts => 'Varsler';

  @override
  String get adminSessionGoHome => 'Gå til startskjermen';

  @override
  String get adminPlayMethodRemux => 'Remuxer';

  @override
  String get adminPlayMethodDirectStream => 'Direktestrømming';

  @override
  String get adminPlayMethodDirectPlay => 'Direkteavspilling';

  @override
  String get adminLogLevelTrace => 'Sporing';

  @override
  String get adminLogLevelDebug => 'Feilsøking';

  @override
  String get adminLogLevelInformation => 'Informasjon';

  @override
  String get adminLogLevelWarning => 'Advarsel';

  @override
  String get adminLogLevelError => 'Feil';

  @override
  String get adminLogLevelCritical => 'Kritisk';

  @override
  String get adminLogLevelNone => 'Ingen';

  @override
  String get adminActivityAllUsers => 'Alle brukere';

  @override
  String adminTaskLastRan(String time, String duration) {
    return 'Sist kjørt $time, tok $duration.';
  }

  @override
  String get adminTaskResultFailed => 'Mislyktes';

  @override
  String get adminTaskResultCancelled => 'Avbrutt';

  @override
  String get adminTaskResultAborted => 'Avbrutt fordi serveren ble slått av';

  @override
  String adminDurationSecondsShort(String seconds) {
    return '$seconds s';
  }

  @override
  String get adminDeleteTaskTrigger => 'Slett utløser for oppgave';

  @override
  String get adminDeleteTaskTriggerConfirm =>
      'Er du sikker på at du vil slette denne utløseren?';

  @override
  String adminTaskTriggerEveryMinutes(String minutes) {
    return 'Hvert $minutes. minutt';
  }

  @override
  String adminTaskTriggerEveryHours(String hours) {
    return 'Hver $hours. time';
  }

  @override
  String adminTaskMinutesValue(String minutes) {
    return '$minutes minutter';
  }

  @override
  String adminTaskHoursValue(String hours) {
    return '$hours timer';
  }

  @override
  String get adminTimeLimitHours => 'Tidsgrense (timer)';

  @override
  String get adminTranscodingDecodingFor => 'Slå på maskinvaredekoding for';

  @override
  String get adminTranscodingThreadCountHelp =>
      'Høyeste antall tråder en omkoding kan bruke. Færre tråder gir lavere CPU-bruk, men kan bli for tregt for jevn avspilling.';

  @override
  String get adminTranscodingThreadMax => 'Maks';

  @override
  String get adminTranscodingFfmpegPath => 'FFmpeg-bane';

  @override
  String get adminTranscodingFfmpegPathHelp =>
      'FFmpeg-programmet serveren kjører. Det stilles inn på serveren, ikke her.';

  @override
  String get adminTranscodingAudioSeek => 'Strategi for spoling i lyd';

  @override
  String get adminTranscodingAudioSeekHelp =>
      'Hvordan serveren håndterer lyd når du spoler i en HLS-strøm.';

  @override
  String get adminTranscodingTrimCopiedAudio => 'Trim kopiert lyd';

  @override
  String get adminTranscodingTranscodeAudio => 'Omkod lyd';

  @override
  String get adminResumeMinAudiobookMinutes =>
      'Minste tid for å fortsette lydbok (minutter)';

  @override
  String get adminResumeMinAudiobookHelp =>
      'Lydbøker som stoppes før denne tiden, regnes som ikke spilt.';

  @override
  String get adminResumeAudiobookRemaining =>
      'Gjenstående minutter for å fortsette lydbok';

  @override
  String get adminResumeAudiobookRemainingHelp =>
      'Lydbøker som stoppes med færre minutter igjen enn dette, regnes som spilt.';

  @override
  String get adminBrandingSplashSection => 'Oppstartsbilde';

  @override
  String get adminBrandingSectionWebClient => 'Nettklient';

  @override
  String get adminBrandingSplashSizeHint =>
      'Egne bilder bør ha sideforhold 16x9 og være minst 1920x1080.';

  @override
  String get adminNetworkingSectionServerAddress =>
      'Innstillinger for serveradresse';

  @override
  String get adminNetworkingSectionHttps => 'HTTPS-innstillinger';

  @override
  String get adminNetworkingSectionRemoteAccess =>
      'Innstillinger for fjerntilgang';

  @override
  String get adminNetworkingSectionIpProtocols => 'IP-protokoller';

  @override
  String get adminNetworkingSectionDiscovery => 'Nettverksoppdaging';

  @override
  String get adminNetworkingSectionFirewall => 'Brannmur og proxy';

  @override
  String get adminNetworkingLocalHttpPort => 'Lokalt HTTP-portnummer';

  @override
  String get adminNetworkingLocalHttpPortHelp =>
      'TCP-portnummeret for HTTP-serveren.';

  @override
  String get adminNetworkingEnableHttpsHelp =>
      'Lytt på HTTPS-porten. Et gyldig sertifikat må også være satt for at dette skal virke.';

  @override
  String get adminNetworkingLocalHttpsPort => 'Lokalt HTTPS-portnummer';

  @override
  String get adminNetworkingLocalHttpsPortHelp =>
      'TCP-portnummeret for HTTPS-serveren.';

  @override
  String get adminNetworkingBaseUrlHelp =>
      'Legger til en undermappe i server-URL-en, for eksempel https://example.com/jellyfin.';

  @override
  String get adminNetworkingBindAddress => 'Bind til lokal nettverksadresse';

  @override
  String get adminNetworkingBindAddressHelp =>
      'Overstyrer den lokale IP-adressen til HTTP-serveren. La feltet stå tomt for å binde til alle adresser. Endring krever omstart.';

  @override
  String get adminNetworkingLanNetworksHelp =>
      'IP-adresser eller IP/nettmaske for nettverk som regnes som lokale for båndbredde- og fjerntilgangsgrenser. La feltet stå tomt for å regne alle RFC1918-adresser som lokale.';

  @override
  String get adminNetworkingKnownProxiesHelp =>
      'IP-adresser eller vertsnavn for proxyene foran denne serveren. Trengs for å lese X-Forwarded-For-hoder. Endring krever omstart.';

  @override
  String get adminNetworkingCustomCertPath => 'Bane til eget SSL-sertifikat';

  @override
  String get adminNetworkingCertPathHelp =>
      'Bane til en PKCS #12-fil med sertifikat og privat nøkkel, for TLS på eget domene.';

  @override
  String get adminNetworkingCertPasswordHelp =>
      'Skriv inn passordet hvis sertifikatet krever det.';

  @override
  String get adminNetworkingAllowRemote =>
      'Tillat eksterne tilkoblinger til denne serveren';

  @override
  String get adminNetworkingAllowRemoteHelp =>
      'Når dette er av, blokkeres alle eksterne tilkoblinger.';

  @override
  String get adminNetworkingRemoteIpFilterHelp =>
      'IP-adresser eller IP/nettmaske for eksterne nettverk. La feltet stå tomt for å tillate alle eksterne adresser.';

  @override
  String get adminNetworkingRemoteIpFilterMode =>
      'Filtermodus for eksterne IP-adresser';

  @override
  String get adminNetworkingPublicHttpPortHelp =>
      'Den offentlige porten som peker til den lokale HTTP-porten.';

  @override
  String get adminNetworkingPublicHttpsPortHelp =>
      'Den offentlige porten som peker til den lokale HTTPS-porten.';

  @override
  String get adminNetworkingAutoDiscoveryLabel => 'Slå på automatisk oppdaging';

  @override
  String get adminNetworkingAutoDiscoveryHelp =>
      'Lar apper finne denne serveren på UDP-port 7359.';

  @override
  String get adminNetworkingSamePublishedUri =>
      'Bruk samme publiserte server-URI for intern og ekstern tilgang';

  @override
  String get adminNetworkingPublishedUri => 'Publisert server-URI';

  @override
  String get adminNetworkingPublishedUriHelp =>
      'Overstyrer URI-en serveren oppgir, basert på grensesnittet eller klientens IP-adresse.';

  @override
  String get adminNetworkingInternalUri => 'Intern URI';

  @override
  String get adminNetworkingInternalUriHelp =>
      'Publisert server-URI for intern tilgang.';

  @override
  String get adminNetworkingExternalUri => 'Ekstern URI';

  @override
  String get adminNetworkingExternalUriHelp =>
      'Publisert server-URI for ekstern tilgang.';

  @override
  String get adminNetworkingOtherPublishedUris => 'Andre publiserte URI-er';

  @override
  String get adminNetworkingOtherPublishedUrisHelp =>
      'URI-er for ett subnett eller grensesnitt, skrevet som subnett=URI.';

  @override
  String get adminBackupsHelp =>
      'Lag og gjenopprett øyeblikksbilder av serveren. De kan inneholde databasen, metadata, undertekster og bilder for forhåndsvisning ved spoling.';

  @override
  String get adminBackupDisclaimer =>
      'Avhengig av hvor stort biblioteket er, kan sikkerhetskopien ta en stund.';

  @override
  String get adminBackupTasksWarningTitle => 'Planlagte oppgaver kjører';

  @override
  String get adminBackupTasksWarning =>
      'Stopp disse oppgavene eller vent til de er ferdige før du lager en sikkerhetskopi.';

  @override
  String get adminBackupArchiveNotFound =>
      'Serveren fant ikke dette sikkerhetskopiarkivet.';

  @override
  String get adminRestoreInProgress => 'Gjenoppretter';

  @override
  String get adminRestoreWaitingForServer =>
      'Venter på at serveren kommer tilbake.';

  @override
  String get adminRestoreSucceeded => 'Gjenoppretting fullført';

  @override
  String get adminLogWatch => 'Følg';

  @override
  String get adminLogStopWatching => 'Slutt å følge';

  @override
  String get adminPluginInstallConfirmTitle =>
      'Bekreft installasjon av tillegg';

  @override
  String get adminPluginInstallDisclaimer =>
      'Det er risiko ved å installere tillegg fra tredjeparter. De kan inneholde ustabil eller ondsinnet kode og kan endres når som helst. Installer bare tillegg fra utviklere du stoler på, og vit hva de kan gjøre, for eksempel kontakte eksterne tjenester, gjøre bibliotekskanning tregere eller legge til bakgrunnsarbeid.';

  @override
  String get adminGroupOverview => 'Oversikt';

  @override
  String get adminGroupLibrary => 'Bibliotek';

  @override
  String get adminGroupPlayback => 'Avspilling';

  @override
  String get adminGroupPeople => 'Personer';

  @override
  String get adminGroupSystem => 'System';

  @override
  String get adminAreasLabel => 'Administrasjonsområder';

  @override
  String get adminPagesLabel => 'Sider';

  @override
  String get adminPageDescDashboard => 'Serverhelse, økter og nylig aktivitet';

  @override
  String get adminPageDescAnalytics =>
      'Bibliotekstørrelser, kodeker og formater';

  @override
  String get adminPageDescActivity => 'Alt som har skjedd på serveren';

  @override
  String get adminPageDescTasks => 'Skanninger, opprydding og utløsere';

  @override
  String get adminPageDescLibraries => 'Mapper, skannere og metadatakilder';

  @override
  String get adminPageDescDisplay => 'Hvordan bibliotekene vises for brukerne';

  @override
  String get adminPageDescMetadata => 'Standard språk, land og bilder';

  @override
  String get adminPageDescNfo => 'Lesing og lagring av Kodi NFO';

  @override
  String get adminPageDescLiveTv => 'Tunere, programguide og opptak';

  @override
  String get adminPageDescTranscoding =>
      'Maskinvareakselerasjon, kodere, tonemapping';

  @override
  String get adminPageDescResume =>
      'Når elementer regnes som startet eller spilt';

  @override
  String get adminPageDescStreaming => 'Grense for ekstern bithastighet';

  @override
  String get adminPageDescTrickplay => 'Miniatyrbilder ved spoling';

  @override
  String get adminPageDescUsers => 'Kontoer, tilgang og foreldrekontroll';

  @override
  String get adminPageDescDevices => 'Påloggede enheter og navnene deres';

  @override
  String get adminPageDescApiKeys => 'Nøkler for apper og skript';

  @override
  String get adminPageDescSettings => 'Servernavn, språk, baner, ytelse';

  @override
  String get adminPageDescBranding =>
      'Påloggingsmelding, egen CSS, oppstartsbilde';

  @override
  String get adminPageDescNetworking => 'Porter, HTTPS, LAN og fjerntilgang';

  @override
  String get adminPageDescPlugins => 'Installerte tillegg og katalogen';

  @override
  String get adminPageDescRepositories => 'Hvor tilleggene kommer fra';

  @override
  String get adminPageDescBackups =>
      'Lag og gjenopprett sikkerhetskopier av serveren';

  @override
  String get adminPageDescLogs => 'Serverens loggfiler';

  @override
  String adminSearchSettingsHint(int count) {
    return 'Søk i $count innstillinger';
  }

  @override
  String get adminSearchNoResults => 'Ingen innstillinger passer';

  @override
  String get adminSearchClear => 'Tøm søk';

  @override
  String get adminUnsavedChanges => 'Ulagrede endringer';

  @override
  String get adminDiscard => 'Forkast';

  @override
  String get adminLeaveTitle => 'Forkaste ulagrede endringer?';

  @override
  String get adminLeaveMessage =>
      'Endringene på denne siden er ikke lagret ennå.';

  @override
  String get adminKeepEditing => 'Fortsett å redigere';

  @override
  String get adminDashboardLoadFailed => 'Kunne ikke laste dashbordet';

  @override
  String get adminMediaOverview => 'Medieoversikt';

  @override
  String get adminMediaTotalsError =>
      'Kunne ikke laste inn servermedietotaler.';

  @override
  String get adminMediaOverviewSubtitle =>
      'En rask lesning om hvor mye innhold som er på denne serveren.';

  @override
  String adminPluginUpdatesAvailable(int count) {
    return 'Tilgjengelige tilleggsoppdateringer: $count';
  }

  @override
  String adminPluginsRequiringRestart(int count) {
    return 'Tillegg som krever omstart: $count';
  }

  @override
  String adminFailedScheduledTasks(int count) {
    return 'Mislykkede planlagte oppgaver: $count';
  }

  @override
  String get analyticsMediaDistribution => 'Mediedistribusjon';

  @override
  String get analyticsVideoCodecs => 'Videokodeker';

  @override
  String get analyticsAudioCodecs => 'Lydkodeker';

  @override
  String get analyticsContainers => 'Containere';

  @override
  String get analyticsTopGenres => 'Topp sjangere';

  @override
  String get analyticsReleaseYears => 'Utgivelsesår';

  @override
  String get analyticsContentRatings => 'Innholdsvurderinger';

  @override
  String get analyticsRuntimeBuckets => 'Runtime Bøtter';

  @override
  String get analyticsFileFormats => 'Filformater';

  @override
  String get analyticsNoData => 'Ingen data tilgjengelig.';

  @override
  String get adminServerInfo => 'Serverinfo';

  @override
  String get adminRestartPending => 'Venter på nytt';

  @override
  String get adminServerPaths => 'Serverbaner';

  @override
  String get adminServerActions => 'Serverhandlinger';

  @override
  String get adminRestartServer => 'Start server på nytt';

  @override
  String get adminShutdownServer => 'Slå av server';

  @override
  String get adminLibraryScanStarted => 'Bibliotekskanning startet';

  @override
  String errorGeneric(String error) {
    return 'Feil: $error';
  }

  @override
  String get adminServerRebootInProgress => 'Server omstart pågår';

  @override
  String get adminServerRebootMessage =>
      'Server omstart pågår, vennligst start Tortugarr på nytt';

  @override
  String get adminActiveSessions => 'Aktive økter';

  @override
  String get adminSessionsLoadFailed => 'Kunne ikke laste inn økter';

  @override
  String get adminNoActiveSessions => 'Ingen aktive økter';

  @override
  String get adminRecentActivity => 'Nylig aktivitet';

  @override
  String get adminNoRecentActivity => 'Ingen nylig aktivitet';

  @override
  String adminCommandFailed(String error) {
    return 'Kommandoen mislyktes: $error';
  }

  @override
  String get adminSendMessage => 'Send melding';

  @override
  String get adminMessageTextHint => 'Meldingstekst';

  @override
  String get adminSetVolume => 'Still inn volum';

  @override
  String get sessionPrev => 'Forrige';

  @override
  String get sessionRewind => 'Spole';

  @override
  String get sessionForward => 'Fremover';

  @override
  String get sessionNext => 'Neste';

  @override
  String get sessionVolumeDown => 'Vol –';

  @override
  String get sessionVolumeUp => 'Vol +';

  @override
  String get uhd4k => '4K';

  @override
  String get nowPlaying => 'Spiller nå';

  @override
  String get volume => 'Volum';

  @override
  String get actions => 'Handlinger';

  @override
  String get videoCodec => 'Videokodek';

  @override
  String get audioCodec => 'Lydkodek';

  @override
  String get hwAccel => 'HW-akselerasjon';

  @override
  String get completion => 'Fullføring';

  @override
  String get adminClearDates => 'Klare datoer';

  @override
  String get adminActivitySeverityAll => 'Alle alvorlighetsgrader';

  @override
  String get adminActivityDateRange => 'Datoområde';

  @override
  String adminActivityLoadFailed(String error) {
    return 'Kunne ikke laste inn aktivitetsloggen: $error';
  }

  @override
  String get adminNoActivityEntries => 'Ingen aktivitetsoppføringer';

  @override
  String get adminEditDeviceName => 'Rediger enhetsnavn';

  @override
  String get adminCustomName => 'Egendefinert navn';

  @override
  String get adminDeviceNameUpdated => 'Enhetsnavnet er oppdatert';

  @override
  String adminDeviceUpdateFailed(String error) {
    return 'Kunne ikke oppdatere enheten: $error';
  }

  @override
  String get adminDeleteDevice => 'Slett enhet';

  @override
  String get adminDeviceDeleted => 'Enheten er slettet';

  @override
  String adminDeviceDeleteFailed(String error) {
    return 'Kunne ikke slette enheten: $error';
  }

  @override
  String adminRemoveDeviceConfirm(String name) {
    return 'Vil du fjerne enheten \'$name\'? Brukeren må logge på igjen på denne enheten.';
  }

  @override
  String get adminDeleteAllDevices => 'Slett alle enheter';

  @override
  String adminDeleteAllDevicesConfirm(int count) {
    return 'Vil du fjerne $count enheter? Berørte brukere må logge på igjen. Din nåværende enhet påvirkes ikke.';
  }

  @override
  String get adminDevicesDeletedAll => 'Enhetene er fjernet';

  @override
  String adminDevicesDeletedPartial(int count) {
    return 'Noen enheter ble fjernet, men $count kunne ikke fjernes.';
  }

  @override
  String get adminDevicesLoadFailed => 'Kunne ikke laste inn enheter';

  @override
  String get adminSearchDevices => 'Søk etter enheter';

  @override
  String get adminThisDevice => 'Denne enheten';

  @override
  String get adminEditName => 'Rediger navn';

  @override
  String get adminLibrariesLoadFailed => 'Kunne ikke laste inn bibliotekene';

  @override
  String get adminNoLibraries => 'Ingen biblioteker er konfigurert';

  @override
  String get adminScanAllLibraries => 'Skann alle biblioteker';

  @override
  String get adminAddLibrary => 'Legg til bibliotek';

  @override
  String adminScanFailed(String error) {
    return 'Kunne ikke starte skanningen: $error';
  }

  @override
  String get adminRenameLibrary => 'Gi nytt navn til biblioteket';

  @override
  String get adminNewName => 'Nytt navn';

  @override
  String adminLibraryRenamed(String name) {
    return 'Biblioteket er omdøpt til «$name»';
  }

  @override
  String adminRenameFailed(String error) {
    return 'Kunne ikke gi nytt navn: $error';
  }

  @override
  String get adminDeleteLibrary => 'Slett bibliotek';

  @override
  String adminLibraryDeleted(String name) {
    return 'Biblioteket «$name» er slettet';
  }

  @override
  String adminLibraryDeleteFailed(String error) {
    return 'Kunne ikke slette biblioteket: $error';
  }

  @override
  String adminAddPathFailed(String error) {
    return 'Kunne ikke legge til banen: $error';
  }

  @override
  String get adminRemovePath => 'Fjern bane';

  @override
  String adminRemovePathConfirm(String path) {
    return 'Vil du fjerne «$path» fra dette biblioteket?';
  }

  @override
  String adminRemovePathFailed(String error) {
    return 'Kunne ikke fjerne banen: $error';
  }

  @override
  String get adminLibraryLoadFailed => 'Kunne ikke laste inn biblioteket';

  @override
  String get adminNoMediaPaths => 'Ingen mediebaner er konfigurert';

  @override
  String get adminAddPath => 'Legg til bane';

  @override
  String get adminBrowseFilesystem => 'Bla gjennom serverfilsystemet:';

  @override
  String get adminPreferredMetadataLanguage => 'Foretrukket metadataspråk';

  @override
  String get adminMetadataLanguageHint => 'f.eks. no, de, fr';

  @override
  String get adminMetadataCountryCode => 'Metadata landskode';

  @override
  String get adminMetadataCountryHint => 'f.eks. USA, DE, FR';

  @override
  String get adminLibraryTabPaths => 'Baner';

  @override
  String get adminLibraryTabOptions => 'Alternativer';

  @override
  String get adminLibraryTabDownloaders => 'Nedlastere';

  @override
  String get adminLibMetadataSavers => 'Metadatalagrere';

  @override
  String get adminLibSubtitleDownloaders => 'Undertekstnedlastere';

  @override
  String get adminLibLyricDownloaders => 'Sangtekstnedlastere';

  @override
  String adminLibMetadataDownloadersFor(String type) {
    return 'Metadatanedlastere: $type';
  }

  @override
  String adminLibImageFetchersFor(String type) {
    return 'Bildehentere: $type';
  }

  @override
  String get adminLibNoDownloaders =>
      'Denne serveren tilbyr ingen nedlastere for denne bibliotektypen.';

  @override
  String get adminLibrarySectionGeneral => 'Generelt';

  @override
  String get adminLibrarySectionMetadata => 'Metadata';

  @override
  String get adminLibrarySectionEmbedded => 'Innebygd informasjon';

  @override
  String get adminLibrarySectionSubtitles => 'Undertekster';

  @override
  String get adminLibrarySectionImages => 'Bilder';

  @override
  String get adminLibrarySectionSeries => 'Serier';

  @override
  String get adminLibrarySectionMusic => 'Musikk';

  @override
  String get adminLibrarySectionMovies => 'Filmer';

  @override
  String get adminLibRealtimeMonitor => 'Aktiver sanntidsovervåking';

  @override
  String get adminLibRealtimeMonitorHint =>
      'Oppdag filendringer og behandle dem automatisk.';

  @override
  String get adminLibEnablePhotos => 'Vis bilder';

  @override
  String get adminLibSaveLocalMetadata => 'Lagre bildemateriell i mediemappene';

  @override
  String get adminLibRefreshInterval => 'Automatisk oppdatering av metadata';

  @override
  String get adminLibRefreshNever => 'Aldri';

  @override
  String get adminLibDefault => 'Standard';

  @override
  String get adminLibDisplayTitle => 'Visning';

  @override
  String get adminLibDisplaySection => 'Bibliotekvisning';

  @override
  String get adminLibFolderView =>
      'Vis en mappevisning for å vise vanlige mediemapper';

  @override
  String get adminLibSpecialsInSeasons =>
      'Vis spesialepisoder i sesongene de ble sendt i';

  @override
  String get adminLibGroupMovies => 'Grupper filmer i samlinger';

  @override
  String get adminLibGroupShows => 'Grupper serier i samlinger';

  @override
  String get adminLibExternalSuggestions => 'Vis eksternt innhold i forslag';

  @override
  String get adminLibDateAddedSection => 'Virkemåte for lagt til-dato';

  @override
  String get adminLibDateAddedLabel => 'Bruk lagt til-dato fra';

  @override
  String get adminLibDateAddedImport =>
      'Datoen filen ble skannet inn i biblioteket';

  @override
  String get adminLibDateAddedFile => 'Datoen filen ble opprettet';

  @override
  String get adminLibMetadataTitle => 'Metadata og bilder';

  @override
  String get adminLibMetadataLangSection => 'Foretrukket metadataspråk';

  @override
  String get adminLibChaptersSection => 'Kapitler';

  @override
  String get adminLibDummyChapterDuration =>
      'Varighet for genererte kapitler (sekunder)';

  @override
  String get adminLibDummyChapterDurationHint =>
      'Lengden på kapitler som genereres for medier uten kapitler. Sett til 0 for å deaktivere.';

  @override
  String get adminLibChapterImageResolution => 'Oppløsning for kapittelbilder';

  @override
  String get adminLibNfoTitle => 'NFO-innstillinger';

  @override
  String get adminLibNfoHelp =>
      'NFO-metadata er kompatible med Kodi og lignende klienter. Innstillingene gjelder alle biblioteker som lagrer NFO-metadata.';

  @override
  String get adminLibKodiUser =>
      'Bruker det skal lagres visningsdata for i NFO-filer';

  @override
  String get adminLibSaveImagePaths => 'Lagre bildebaner i NFO-filer';

  @override
  String get adminLibPathSubstitution =>
      'Aktiver baneerstatning for NFO-bildebaner';

  @override
  String get adminLibExtraThumbs =>
      'Kopier extrafanart-bilder til en extrathumbs-mappe';

  @override
  String get adminLibNone => 'Ingen';

  @override
  String adminLibRefreshDays(int days) {
    return '$days dager';
  }

  @override
  String get adminLibEmbeddedTitles => 'Bruk innebygde titler';

  @override
  String get adminLibEmbeddedExtrasTitles =>
      'Bruk innebygde titler for ekstramateriale';

  @override
  String get adminLibEmbeddedEpisodeInfos => 'Bruk innebygd episodeinformasjon';

  @override
  String get adminLibAllowEmbeddedSubtitles => 'Tillat innebygde undertekster';

  @override
  String get adminLibEmbeddedAllowAll => 'Tillat alle';

  @override
  String get adminLibEmbeddedAllowText => 'Kun tekst';

  @override
  String get adminLibEmbeddedAllowImage => 'Kun bilde';

  @override
  String get adminLibEmbeddedAllowNone => 'Ingen';

  @override
  String get adminLibSkipIfEmbeddedSubs =>
      'Hopp over nedlasting hvis innebygde undertekster finnes';

  @override
  String get adminLibSkipIfAudioMatches =>
      'Hopp over nedlasting hvis lydsporet samsvarer med nedlastingsspråket';

  @override
  String get adminLibRequirePerfectMatch => 'Krev perfekt undertekstsamsvar';

  @override
  String get adminLibSaveSubtitlesWithMedia =>
      'Lagre undertekster i mediemappene';

  @override
  String get adminLibChapterImageExtraction => 'Trekk ut kapittelbilder';

  @override
  String get adminLibChapterImagesDuringScan =>
      'Trekk ut kapittelbilder under bibliotekskanningen';

  @override
  String get adminLibTrickplayExtraction =>
      'Aktiver uttrekking av trickplay-bilder';

  @override
  String get adminLibTrickplayDuringScan =>
      'Trekk ut trickplay-bilder under bibliotekskanningen';

  @override
  String get adminLibSaveTrickplayWithMedia =>
      'Lagre trickplay-bilder i mediemappene';

  @override
  String get adminLibAutomaticSeriesGrouping =>
      'Slå automatisk sammen serier som er spredt over flere mapper';

  @override
  String get adminLibSeasonZeroName => 'Visningsnavn for sesong null';

  @override
  String get adminLibLufsScan => 'Aktiver LUFS-skanning for lydnormalisering';

  @override
  String get adminLibPreferNonstandardArtist =>
      'Foretrekk ikke-standard artisttagg';

  @override
  String get adminLibAutoAddToCollection =>
      'Legg filmer automatisk til i samlinger';

  @override
  String get adminLibraryNameRequired => 'Biblioteknavn er obligatorisk';

  @override
  String adminLibraryCreateFailed(String error) {
    return 'Kunne ikke opprette biblioteket: $error';
  }

  @override
  String get adminLibraryName => 'Bibliotekets navn';

  @override
  String get adminSelectedPaths => 'Valgte stier:';

  @override
  String get adminCreateLibrary => 'Opprett bibliotek';

  @override
  String get paths => 'Baner:';

  @override
  String get adminDisableUser => 'Deaktiver bruker';

  @override
  String get adminEnableUser => 'Aktiver bruker';

  @override
  String adminDisableUserConfirm(String name) {
    return 'Vil du deaktivere $name? Brukeren vil ikke kunne logge på.';
  }

  @override
  String adminEnableUserConfirm(String name) {
    return 'Vil du aktivere $name? Brukeren vil kunne logge på igjen.';
  }

  @override
  String adminUserDisabled(String name) {
    return 'Brukeren «$name» er deaktivert';
  }

  @override
  String adminUserEnabled(String name) {
    return 'Brukeren «$name» er aktivert';
  }

  @override
  String adminUserPolicyUpdateFailed(String error) {
    return 'Kunne ikke oppdatere brukerpolicyen: $error';
  }

  @override
  String get adminUsersLoadFailed => 'Kunne ikke laste inn brukere';

  @override
  String get adminSearchUsers => 'Søk etter brukere';

  @override
  String get adminEditUser => 'Rediger bruker';

  @override
  String get adminAddUser => 'Legg til bruker';

  @override
  String adminUserCreateFailed(String error) {
    return 'Kunne ikke opprette brukeren: $error';
  }

  @override
  String get adminCreateUser => 'Opprett bruker';

  @override
  String get adminPasswordOptional => 'Passord (valgfritt)';

  @override
  String get adminUsernameRequired => 'Brukernavnet kan ikke være tomt';

  @override
  String adminSaveFailed(String error) {
    return 'Kunne ikke lagre: $error';
  }

  @override
  String get adminPasswordsMismatch => 'Passord stemmer ikke';

  @override
  String adminFailed(String error) {
    return 'Mislyktes: $error';
  }

  @override
  String get adminUserLoadFailed => 'Kunne ikke laste brukeren';

  @override
  String get adminDeleteUser => 'Slett bruker';

  @override
  String get admin => 'Administrasjon';

  @override
  String get adminFullAccessWarning =>
      'Administratorer har full tilgang til serveren. Gi med forsiktighet.';

  @override
  String get administrator => 'Administrator';

  @override
  String get adminHiddenUser => 'Skjult bruker';

  @override
  String get adminAllowMediaPlayback => 'Tillat medieavspilling';

  @override
  String get adminAllowAudioTranscoding => 'Tillat lydomkoding';

  @override
  String get adminAllowVideoTranscoding => 'Tillat videoomkoding';

  @override
  String get adminAllowRemuxing => 'Tillat remiksing';

  @override
  String get adminForceRemoteTranscoding => 'Tving omkoding av ekstern kilde';

  @override
  String get adminAllowContentDownloading => 'Tillat nedlasting av innhold';

  @override
  String get adminAllowPublicSharing => 'Tillat offentlig deling';

  @override
  String get adminAllowRemoteControl => 'Tillat fjernkontroll av andre brukere';

  @override
  String get adminAllowSharedDeviceControl => 'Tillat delt enhetskontroll';

  @override
  String get adminAllowRemoteAccess => 'Tillat ekstern tilgang';

  @override
  String get adminLeaveEmptyNoLimit => 'La stå tomt uten grense';

  @override
  String get adminMaxActiveSessions => 'Maks aktive økter';

  @override
  String get adminAllowLiveTvAccess => 'Tillat direkte TV-tilgang';

  @override
  String get adminAllowLiveTvManagement => 'Tillat direkte-TV-administrasjon';

  @override
  String get adminAllowCollectionManagement => 'Tillat samlingshåndtering';

  @override
  String get adminAllowSubtitleManagement => 'Tillat undertekstbehandling';

  @override
  String get adminAllowLyricManagement => 'Tillat tekstbehandling';

  @override
  String get adminEnableAllLibraryAccess =>
      'Aktiver tilgang til alle biblioteker';

  @override
  String get adminChangePassword => 'Endre passord';

  @override
  String get adminNewPassword => 'Nytt passord';

  @override
  String get adminConfirmPassword => 'Bekreft passord';

  @override
  String get adminSetPassword => 'Angi passord';

  @override
  String get adminResetPassword => 'Tilbakestill passord';

  @override
  String get adminPasswordReset => 'Tilbakestill passord';

  @override
  String get adminPasswordUpdated => 'Passord oppdatert';

  @override
  String get adminUserSettings => 'Brukerinnstillinger';

  @override
  String get adminLibraryAccess => 'Bibliotektilgang';

  @override
  String get adminEnableAllDevices => 'Aktiver tilgang til alle enheter';

  @override
  String get adminEnableAllChannels => 'Aktiver tilgang til alle kanaler';

  @override
  String get adminParentalControl => 'Foreldrekontroll';

  @override
  String get adminMaxParentalRating => 'Maksimal tillatt aldersgrense';

  @override
  String get adminMaxParentalRatingHint =>
      'Innhold med høyere aldersgrense skjules for denne brukeren.';

  @override
  String get adminParentalRatingNone => 'Ingen';

  @override
  String get adminBlockUnratedItems =>
      'Blokker elementer uten eller med ukjent aldersgrense';

  @override
  String get adminUnratedBook => 'Bøker';

  @override
  String get adminUnratedChannelContent => 'Kanaler';

  @override
  String get adminUnratedLiveTvChannel => 'Direktesendt TV';

  @override
  String get adminUnratedMovie => 'Filmer';

  @override
  String get adminUnratedMusic => 'Musikk';

  @override
  String get adminUnratedTrailer => 'Trailere';

  @override
  String get adminUnratedSeries => 'Serier';

  @override
  String get adminAccessSchedules => 'Tilgangstidsplaner';

  @override
  String get adminAccessSchedulesHint =>
      'Tillat tilgang bare i tidsrommene nedenfor. Tilgang er tillatt hele døgnet når ingen tidsplan er angitt.';

  @override
  String get adminAddSchedule => 'Legg til tidsplan';

  @override
  String get adminScheduleDay => 'Dag';

  @override
  String get adminScheduleStart => 'Start';

  @override
  String get adminScheduleEnd => 'Slutt';

  @override
  String get adminDayEveryday => 'Hver dag';

  @override
  String get adminDayWeekday => 'Ukedag';

  @override
  String get adminDayWeekend => 'Helg';

  @override
  String get adminDaySunday => 'Søndag';

  @override
  String get adminDayMonday => 'Mandag';

  @override
  String get adminDayTuesday => 'Tirsdag';

  @override
  String get adminDayWednesday => 'Onsdag';

  @override
  String get adminDayThursday => 'Torsdag';

  @override
  String get adminDayFriday => 'Fredag';

  @override
  String get adminDaySaturday => 'Lørdag';

  @override
  String get adminAllowedTags => 'Tillatte tagger';

  @override
  String get adminAllowedTagsHint =>
      'Bare innhold med disse taggene vises. La stå tomt for å tillate alt.';

  @override
  String get adminBlockedTags => 'Blokkerte tagger';

  @override
  String get adminBlockedTagsHint =>
      'Innhold med disse taggene skjules for denne brukeren.';

  @override
  String get adminAddTag => 'Legg til tagg';

  @override
  String get adminAuthProvider => 'Autentiseringsleverandør';

  @override
  String get adminPasswordResetProvider =>
      'Leverandør for tilbakestilling av passord';

  @override
  String get adminLoginAttemptsBeforeLockout =>
      'Maksimalt antall mislykkede påloggingsforsøk før utestenging';

  @override
  String get adminLoginAttemptsHint =>
      'Sett til 0 for standardverdien, eller -1 for å deaktivere utestenging.';

  @override
  String get adminSyncPlayAccess => 'SyncPlay-tilgang';

  @override
  String get adminSyncPlayCreateAndJoin =>
      'Tillat å opprette og bli med i grupper';

  @override
  String get adminSyncPlayJoin => 'Tillat å bli med i grupper';

  @override
  String get adminSyncPlayNone => 'Ingen tilgang';

  @override
  String get adminContentDeletionFolders => 'Tillat sletting av innhold fra';

  @override
  String get adminResetPasswordWarning =>
      'Dette vil fjerne passordet. Brukeren vil kunne logge inn uten passord.';

  @override
  String adminServerReturnedHttp(int status) {
    return 'Serveren returnerte HTTP $status';
  }

  @override
  String adminDeleteUserConfirm(String name) {
    return 'Er du sikker på at du vil slette $name?';
  }

  @override
  String adminUserDeleted(String name) {
    return 'Brukeren «$name» er slettet';
  }

  @override
  String adminUserDeleteFailed(String error) {
    return 'Kunne ikke slette brukeren: $error';
  }

  @override
  String get adminCreateApiKey => 'Opprett API-nøkkel';

  @override
  String get adminAppName => 'Appnavn';

  @override
  String get adminApiKeyCreated => 'API-nøkkel opprettet';

  @override
  String get adminApiKeyCreatedNoToken =>
      'Nøkkelen ble opprettet. Serveren returnerte ikke tokenet. Sjekk server API-nøkler.';

  @override
  String get adminKeyCopied => 'Nøkkel kopiert til utklippstavlen';

  @override
  String adminApiKeyCreateFailed(String error) {
    return 'Kunne ikke opprette nøkkelen: $error';
  }

  @override
  String get adminKeyTokenMissing => 'Nøkkeltoken mangler fra serversvar';

  @override
  String get adminRevokeApiKey => 'Tilbakekall API-nøkkel';

  @override
  String adminRevokeKeyConfirm(String name) {
    return 'Vil du oppheve nøkkelen for $name?';
  }

  @override
  String get adminApiKeyRevoked => 'API-nøkkel er opphevet';

  @override
  String adminApiKeyRevokeFailed(String error) {
    return 'Kunne ikke oppheve nøkkelen: $error';
  }

  @override
  String get adminApiKeysLoadFailed => 'Kunne ikke laste inn API-nøkler';

  @override
  String get adminApiKeysTitle => 'API-nøkler';

  @override
  String get adminCreateKey => 'Opprett nøkkel';

  @override
  String get adminNoApiKeys => 'Ingen API-nøkler funnet';

  @override
  String get adminUnknownApp => 'Ukjent app';

  @override
  String adminApiKeyTokenCreated(String token, String created) {
    return 'Token: $token\\nOpprettet: $created';
  }

  @override
  String get adminBackupOptionsTitle => 'Opprett sikkerhetskopi';

  @override
  String get adminBackupDatabase => 'Database';

  @override
  String get adminBackupDatabaseAlways => 'Alltid inkludert';

  @override
  String get adminBackupMetadata => 'Metadata';

  @override
  String get adminBackupSubtitles => 'Undertekster';

  @override
  String get adminBackupTrickplay => 'Trickplay-bilder';

  @override
  String get adminCreatingBackup => 'Oppretter sikkerhetskopi...';

  @override
  String get adminBackupCreated => 'Sikkerhetskopien ble opprettet';

  @override
  String adminBackupCreateFailed(String error) {
    return 'Kunne ikke opprette sikkerhetskopien: $error';
  }

  @override
  String get adminBackupPathMissing => 'Backup-bane mangler i serversvar';

  @override
  String adminBackupManifest(String name) {
    return 'Manifest: $name';
  }

  @override
  String adminManifestLoadFailed(String error) {
    return 'Kunne ikke laste inn manifestet: $error';
  }

  @override
  String get adminConfirmRestore => 'Bekreft gjenoppretting';

  @override
  String get adminRestoringBackup => 'Gjenoppretter sikkerhetskopien ...';

  @override
  String adminRestoreFailed(String error) {
    return 'Kunne ikke gjenopprette sikkerhetskopien: $error';
  }

  @override
  String get adminBackupsLoadFailed => 'Kunne ikke laste inn sikkerhetskopier';

  @override
  String get adminCreateBackup => 'Lag sikkerhetskopi';

  @override
  String get adminNoBackups => 'Ingen sikkerhetskopier funnet';

  @override
  String get adminViewDetails => 'Se detaljer';

  @override
  String get restore => 'Restaurere';

  @override
  String get adminLogsLoadFailed => 'Kunne ikke laste inn serverlogger';

  @override
  String get adminNoLogFiles => 'Ingen loggfiler funnet';

  @override
  String get adminLogCopied => 'Logg kopiert til utklippstavlen';

  @override
  String get adminSaveLogFile => 'Lagre loggfil';

  @override
  String adminSavedTo(String path) {
    return 'Lagret til $path';
  }

  @override
  String adminFileSaveFailed(String error) {
    return 'Kunne ikke lagre filen: $error';
  }

  @override
  String adminLogFileLoadFailed(String fileName) {
    return 'Kunne ikke laste inn $fileName';
  }

  @override
  String get adminSearchInLog => 'Søk i logg';

  @override
  String get adminNoMatchingLines => 'Ingen samsvarende linjer';

  @override
  String adminTasksLoadFailed(String error) {
    return 'Kunne ikke laste inn oppgavene: $error';
  }

  @override
  String get adminNoScheduledTasks => 'Fant ingen planlagte oppgaver';

  @override
  String get adminNoTasksMatchFilter =>
      'Ingen oppgaver samsvarer med gjeldende filter';

  @override
  String adminTaskStartFailed(String error) {
    return 'Kunne ikke starte oppgaven: $error';
  }

  @override
  String adminTaskStopFailed(String error) {
    return 'Kunne ikke stoppe oppgaven: $error';
  }

  @override
  String adminTaskLoadFailed(String error) {
    return 'Kunne ikke laste inn oppgaven: $error';
  }

  @override
  String get adminRunNow => 'Kjør nå';

  @override
  String adminTriggerRemoveFailed(String error) {
    return 'Kunne ikke fjerne utløseren: $error';
  }

  @override
  String adminTriggerAddFailed(String error) {
    return 'Kunne ikke legge til utløseren: $error';
  }

  @override
  String get adminLastExecution => 'Siste utførelse';

  @override
  String get adminTriggers => 'Utløsere';

  @override
  String get adminAddTrigger => 'Legg til trigger';

  @override
  String get adminNoTriggers => 'Ingen utløsere er konfigurert';

  @override
  String get adminTriggerType => 'Utløsertype';

  @override
  String get adminNoLimit => 'Ingen grense';

  @override
  String adminHours(String hours) {
    return '$hours time(r)';
  }

  @override
  String get adminDayOfWeek => 'ukedag';

  @override
  String get adminSearchPlugins => 'Søk i plugins...';

  @override
  String adminPluginToggleFailed(String error) {
    return 'Kunne ikke slå tillegget av/på: $error';
  }

  @override
  String get adminUninstallPlugin => 'Avinstaller plugin';

  @override
  String adminUninstallPluginConfirm(String name) {
    return 'Er du sikker på at du vil avinstallere «$name»?';
  }

  @override
  String adminPluginUninstallFailed(String error) {
    return 'Kunne ikke avinstallere tillegget: $error';
  }

  @override
  String adminPackageInstallFailed(String error) {
    return 'Kunne ikke installere pakken: $error';
  }

  @override
  String adminPluginUpdateFailed(String error) {
    return 'Kunne ikke installere oppdateringen: $error';
  }

  @override
  String adminPluginsLoadFailed(String error) {
    return 'Kunne ikke laste inn tilleggene: $error';
  }

  @override
  String get adminNoPluginsMatchSearch =>
      'Ingen plugins samsvarer med søket ditt';

  @override
  String get adminNoPluginsInstalled => 'Ingen plugins installert';

  @override
  String adminInstallUpdate(String version) {
    return 'Installer oppdatering (v$version)';
  }

  @override
  String adminCatalogLoadFailed(String error) {
    return 'Kunne ikke laste inn katalogen: $error';
  }

  @override
  String get adminNoPackagesMatchSearch =>
      'Ingen pakker samsvarer med søket ditt';

  @override
  String get adminNoPackagesAvailable => 'Ingen tilgjengelige pakker';

  @override
  String get adminExperimentalIntegration => 'Eksperimentell integrasjon';

  @override
  String get adminExperimentalWarning =>
      'Integrasjon av plugin-innstillinger er fortsatt eksperimentell. Det kan hende at enkelte innstillingssider ikke blir riktig gjengitt.';

  @override
  String get continueAction => 'Fortsette';

  @override
  String adminPluginRemoveAfterRestart(String name) {
    return '«$name» fjernes etter at serveren startes på nytt';
  }

  @override
  String adminUninstallFailed(String error) {
    return 'Kunne ikke avinstallere: $error';
  }

  @override
  String adminPluginUpdating(String name, String version) {
    return 'Oppdaterer «$name» til v$version...';
  }

  @override
  String adminPluginLoadFailed(String error) {
    return 'Kunne ikke laste inn tillegget: $error';
  }

  @override
  String get adminPluginNotFound => 'Finner ikke plugin';

  @override
  String adminPluginVersion(String version) {
    return 'Versjon $version';
  }

  @override
  String get adminEnablePlugin => 'Aktiver plugin';

  @override
  String get adminPluginSettingsPage => 'Innstillingssiden for plugin';

  @override
  String get adminRevisionHistory => 'Revisjonshistorie';

  @override
  String get adminNoChangelog => 'Ingen endringslogg tilgjengelig.';

  @override
  String get adminRemoveRepository => 'Fjern repository';

  @override
  String adminRemoveRepositoryConfirm(String name) {
    return 'Er du sikker på at du vil fjerne «$name»?';
  }

  @override
  String adminRepositoriesSaveFailed(String error) {
    return 'Kunne ikke lagre repositoriene: $error';
  }

  @override
  String adminRepositoriesLoadFailed(String error) {
    return 'Kunne ikke laste inn repositoriene: $error';
  }

  @override
  String get adminRepositoryNameHint => 'f.eks. Jellyfin Stall';

  @override
  String get adminRepositoryUrl => 'Repositorie-URL';

  @override
  String get adminAddEntry => 'Legg til oppføring';

  @override
  String get adminInvalidUrl => 'Ugyldig URL';

  @override
  String adminPluginSettingsLoadFailed(String error) {
    return 'Kan ikke laste inn tilleggsinnstillingene: $error';
  }

  @override
  String adminCouldNotOpenUrl(String uri) {
    return 'Kunne ikke åpne $uri';
  }

  @override
  String get adminOpenInBrowser => 'Åpne i nettleseren';

  @override
  String get adminOpenExternally => 'Åpne eksternt';

  @override
  String get adminGeneralSettings => 'Generelle innstillinger';

  @override
  String get adminServerName => 'Servernavn';

  @override
  String get adminPreferredMetadataCountry => 'Foretrukket metadataland';

  @override
  String get adminCachePath => 'Bufferbane';

  @override
  String get adminMetadataPath => 'Metadatabane';

  @override
  String get adminLibraryScanConcurrency => 'Bibliotekskanning samtidig';

  @override
  String get adminParallelImageEncodingLimit =>
      'Grensen for koding av parallelle bilder';

  @override
  String get adminSlowResponseThreshold => 'Langsom responsterskel (ms)';

  @override
  String get adminBrandingLoadFailed =>
      'Kunne ikke laste inn merkevareinnstillinger';

  @override
  String get adminLoginDisclaimer => 'Ansvarsfraskrivelse for pålogging';

  @override
  String get adminLoginDisclaimerHint => 'HTML vist under påloggingsskjemaet';

  @override
  String get adminCustomCss => 'Egendefinert CSS';

  @override
  String get adminCustomCssHint =>
      'Egendefinert CSS brukt på nettgrensesnittet';

  @override
  String get adminEnableSplashScreen => 'Aktiver velkomstskjerm';

  @override
  String get adminStreamingLoadFailed =>
      'Kunne ikke laste inn strømmeinnstillinger';

  @override
  String get adminStreamingDescription =>
      'Angi globale bithastighetsgrenser for strømming for eksterne tilkoblinger.';

  @override
  String get adminRemoteBitrateLimitMbps =>
      'Ekstern klientbithastighetsgrense (Mbps)';

  @override
  String get adminLeaveEmptyForUnlimited =>
      'La stå tomt eller 0 for ubegrenset';

  @override
  String get adminPlaybackLoadFailed =>
      'Kunne ikke laste inn avspillingsinnstillinger';

  @override
  String get adminHardwareAcceleration => 'Maskinvareakselerasjon';

  @override
  String get adminVaapiDevice => 'VA-API-enhet';

  @override
  String get adminEnableHardwareEncoding => 'Aktiver maskinvarekoding';

  @override
  String get adminEnableHardwareDecoding => 'Aktiver maskinvaredekoding for:';

  @override
  String get adminEncodingThreads => 'Koding av tråder';

  @override
  String get adminAutomatic => '0 = automatisk';

  @override
  String get adminTranscodingTempPath => 'Transkoding temp bane';

  @override
  String get adminEnableFallbackFont => 'Aktiver reservefont';

  @override
  String get adminFallbackFontPath => 'Reserve skriftbane';

  @override
  String get adminAllowSegmentDeletion => 'Tillat sletting av segmenter';

  @override
  String get adminSegmentKeepSeconds => 'Segmenthold (sekunder)';

  @override
  String get adminThrottleBuffering => 'Gassbuffring';

  @override
  String get adminTrickplayLoadFailed =>
      'Kunne ikke laste inn trickplay-innstillinger';

  @override
  String get adminEnableHardwareAcceleration =>
      'Aktiver maskinvareakselerasjon';

  @override
  String get adminEnableKeyFrameExtraction =>
      'Aktiver uttrekking av kun nøkkelramme';

  @override
  String get adminKeyFrameSubtitle => 'Raskere, men lavere nøyaktighet';

  @override
  String get adminScanBehavior => 'Skanneadferd';

  @override
  String get adminProcessPriority => 'Prosessprioritet';

  @override
  String get adminImageSettings => 'Bildeinnstillinger';

  @override
  String get adminIntervalMs => 'Intervall (ms)';

  @override
  String get adminCaptureFrameSubtitle => 'Hvor ofte du skal ta bilder';

  @override
  String get adminWidthResolutions => 'Breddeoppløsninger';

  @override
  String get adminTileWidth => 'Flisbredde';

  @override
  String get adminTileHeight => 'Flishøyde';

  @override
  String get adminQualitySubtitle =>
      'Lavere verdier = bedre kvalitet, større filer';

  @override
  String get adminProcessThreads => 'Behandle tråder';

  @override
  String get adminResumeLoadFailed => 'Kunne ikke laste inn CV-innstillingene';

  @override
  String get adminResumeDescription =>
      'Konfigurer når innhold skal merkes som delvis avspilt eller fullstendig avspilt.';

  @override
  String get adminMinResumePercentage => 'Minste CV-prosent';

  @override
  String get adminMinResumeSubtitle =>
      'Innhold må spilles over denne prosentandelen for å lagre fremdrift';

  @override
  String get adminMaxResumePercentage => 'Maksimal gjenoppta prosentandel';

  @override
  String get adminMaxResumeSubtitle =>
      'Innhold anses som fullt spilt etter denne prosentandelen';

  @override
  String get adminMinResumeDuration => 'Minimum gjenoppta varighet (sekunder)';

  @override
  String get adminMinResumeDurationSubtitle =>
      'Elementer som er kortere enn dette kan ikke gjenopptas';

  @override
  String get adminMinAudiobookResume =>
      'Minimumsprosent for gjenopptakelse av lydbok';

  @override
  String get adminMaxAudiobookResume =>
      'Maksimal gjenopptakelsesprosent for lydbok';

  @override
  String get adminNetworkingLoadFailed =>
      'Kunne ikke laste inn nettverksinnstillinger';

  @override
  String get adminNetworkingWarning =>
      'Endringer i nettverksinnstillinger kan kreve omstart av serveren.';

  @override
  String get adminEnableRemoteAccess => 'Aktiver ekstern tilgang';

  @override
  String get ports => 'Havner';

  @override
  String get adminHttpPort => 'HTTP-port';

  @override
  String get adminHttpsPort => 'HTTPS-port';

  @override
  String get adminPublicHttpsPort => 'Offentlig HTTPS-port';

  @override
  String get adminBaseUrl => 'Base-URL';

  @override
  String get adminBaseUrlHint => 'f.eks. /jellyfin';

  @override
  String get https => 'HTTPS';

  @override
  String get adminEnableHttps => 'Aktiver HTTPS';

  @override
  String get adminLocalNetwork => 'Lokalt nettverk';

  @override
  String get adminLocalNetworkAddresses => 'Lokale nettverksadresser';

  @override
  String get adminKnownProxies => 'Kjente fullmektiger';

  @override
  String get adminRemoteIpFilter => 'Eksternt IP-filter';

  @override
  String get adminRemoteIpFilterEntries => 'Eksternt IP-filter';

  @override
  String get adminCertificatePath => 'Sertifikatbane';

  @override
  String get whitelist => 'Hviteliste';

  @override
  String get blacklist => 'Svarteliste';

  @override
  String get notSet => 'Ikke satt';

  @override
  String adminMetadataLoadFailed(String error) {
    return 'Kunne ikke laste inn metadata: $error';
  }

  @override
  String get adminRefreshMetadata => 'Oppdater metadata';

  @override
  String get recursive => 'Rekursivt';

  @override
  String get adminReplaceAllMetadata => 'Erstatt alle metadata';

  @override
  String get adminMetadataRefreshRequested =>
      'Forespørsel om oppdatering av metadata';

  @override
  String adminMetadataRefreshFailed(String error) {
    return 'Kunne ikke oppdatere metadata: $error';
  }

  @override
  String get adminNoRemoteMatches => 'Ingen eksterne treff funnet';

  @override
  String get adminRemoteResults => 'Eksterne resultater';

  @override
  String get adminRemoteMetadataApplied => 'Eksterne metadata er brukt';

  @override
  String adminRemoteSearchFailed(String error) {
    return 'Eksternt søk mislyktes: $error';
  }

  @override
  String get adminUpdateContentType => 'Oppdater innholdstype';

  @override
  String get adminContentType => 'Innholdstype';

  @override
  String get adminContentTypeUpdated => 'Innholdstype oppdatert';

  @override
  String adminContentTypeUpdateFailed(String error) {
    return 'Kunne ikke oppdatere innholdstypen: $error';
  }

  @override
  String get adminMetadataEditorLoadFailed =>
      'Kunne ikke laste inn metadataredigering';

  @override
  String get adminNoPeopleEntries => 'Ingen personer oppføringer';

  @override
  String get adminNoExternalIds => 'Ingen eksterne ID-er tilgjengelig';

  @override
  String adminImageUpdated(String imageType) {
    return '$imageType-bildet er oppdatert';
  }

  @override
  String adminImageDownloadFailed(String error) {
    return 'Kunne ikke laste ned bildet: $error';
  }

  @override
  String get adminUnsupportedImageFormat => 'Bildeformat som ikke støttes';

  @override
  String get adminImageReadFailed => 'Kunne ikke lese det valgte bildet';

  @override
  String adminImageUploaded(String imageType) {
    return '$imageType-bildet er lastet opp';
  }

  @override
  String adminImageUploadFailed(String error) {
    return 'Kunne ikke laste opp bildet: $error';
  }

  @override
  String adminDeleteImage(String imageType) {
    return 'Slett $imageType-bildet';
  }

  @override
  String adminImageDeleted(String imageType) {
    return '$imageType-bildet er slettet';
  }

  @override
  String adminImageDeleteFailed(String error) {
    return 'Kunne ikke slette bildet: $error';
  }

  @override
  String get adminAllProviders => 'Alle tilbydere';

  @override
  String get adminNoRemoteImages => 'Ingen eksterne bilder funnet';

  @override
  String adminTunerDiscoveryFailed(String error) {
    return 'Søk etter tunere mislyktes: $error';
  }

  @override
  String get adminTunerTypeM3u => 'M3U-tuner';

  @override
  String get adminTunerTypeHdHomerun => 'HDHomeRun';

  @override
  String get adminTunerFileOrUrl => 'Fil eller URL';

  @override
  String get adminTunerIpAddress => 'Tunerens IP-adresse';

  @override
  String get adminTunerFriendlyName => 'Visningsnavn';

  @override
  String get adminTunerUserAgent => 'Brukeragent';

  @override
  String get adminTunerCount => 'Grense for samtidige tilkoblinger';

  @override
  String get adminTunerCountHelp =>
      'Maksimalt antall strømmer tuneren tillater samtidig. Sett til 0 for ubegrenset.';

  @override
  String get adminTunerFallbackBitrate => 'Reserve for maks strømmebitrate';

  @override
  String get adminTunerImportFavoritesOnly => 'Importer bare favorittkanaler';

  @override
  String get adminTunerAllowHwTranscoding => 'Tillat maskinvareomkoding';

  @override
  String get adminTunerAllowFmp4 => 'Tillat fMP4-omkodingscontainer';

  @override
  String get adminTunerAllowStreamSharing => 'Tillat strømdeling';

  @override
  String get adminTunerEnableStreamLooping => 'Aktiver strømsløyfe';

  @override
  String get adminTunerIgnoreDts => 'Ignorer DTS';

  @override
  String get adminTunerReadAtNativeFramerate =>
      'Les inndata med opprinnelig bildefrekvens';

  @override
  String get adminProviderXmltv => 'XMLTV';

  @override
  String get adminProviderSchedulesDirect => 'Schedules Direct';

  @override
  String get adminXmltvPath => 'Fil eller URL';

  @override
  String get adminXmltvMoviePrefix => 'Filmprefiks';

  @override
  String get adminXmltvMovieCategories => 'Filmkategorier';

  @override
  String get adminXmltvCategoriesHelp =>
      'Skill flere kategorier med en loddrett strek.';

  @override
  String get adminXmltvKidsCategories => 'Barnekategorier';

  @override
  String get adminXmltvNewsCategories => 'Nyhetskategorier';

  @override
  String get adminXmltvSportsCategories => 'Sportskategorier';

  @override
  String get adminSdUsername => 'Brukernavn';

  @override
  String get adminSdPassword => 'Passord';

  @override
  String get adminSdCountry => 'Land';

  @override
  String get adminSdCountrySelect => 'Velg et land';

  @override
  String get adminSdPostalCode => 'Postnummer';

  @override
  String get adminEnableAllTuners => 'Aktiver alle tunere';

  @override
  String adminTunerRemoveFailed(String error) {
    return 'Kunne ikke fjerne tuneren: $error';
  }

  @override
  String adminProviderRemoveFailed(String error) {
    return 'Kunne ikke fjerne leverandøren: $error';
  }

  @override
  String get adminSeriesRecordingPath => 'Serieopptaksbane';

  @override
  String get adminMovieRecordingPath => 'Bane for filmopptak';

  @override
  String get adminGuideDaysAuto => 'Automatisk';

  @override
  String get adminRecordingPostProcessor => 'Bane til etterbehandlingsprogram';

  @override
  String get adminRecordingPostProcessorArgs => 'Argumenter for etterbehandler';

  @override
  String get adminSaveRecordingNfo => 'Lagre NFO-metadata for opptak';

  @override
  String get adminSaveRecordingImages => 'Lagre bilder for opptak';

  @override
  String get adminLiveTvSectionPaths => 'Opptaksbaner';

  @override
  String get adminLiveTvSectionPostProcessing => 'Etterbehandling';

  @override
  String adminSettingsSaveFailed(String error) {
    return 'Kunne ikke lagre innstillingene: $error';
  }

  @override
  String get adminLiveTvLoadFailed =>
      'Kunne ikke laste direkte TV-administrasjon';

  @override
  String get adminTunerDevices => 'Tuner-enheter';

  @override
  String get adminNoTunerHosts => 'Ingen tuner-verter konfigurert';

  @override
  String get adminGuideProviders => 'Veiledningsleverandører';

  @override
  String get adminGuideRefreshStarted => 'Oppdatering av guidedata er startet';

  @override
  String get adminGuideRefreshUnavailable =>
      'Oppgaven for oppdatering av guiden er ikke tilgjengelig på denne serveren.';

  @override
  String get adminNoListingProviders =>
      'Ingen oppføringsleverandører er konfigurert';

  @override
  String get adminSettingsSaved => 'Innstillinger lagret';

  @override
  String get adminBackupsNotAvailable =>
      'Sikkerhetskopier er ikke tilgjengelig på denne serverbyggingen.';

  @override
  String get adminRestoreWarning1 =>
      'Gjenoppretting vil erstatte ALLE gjeldende serverdata med sikkerhetskopidataene.';

  @override
  String get adminRestoreWarning2 =>
      'Gjeldende serverinnstillinger, brukere og bibliotekdata vil bli overskrevet.';

  @override
  String get adminRestoreWarning3 =>
      'Serveren vil starte på nytt etter gjenoppretting.';

  @override
  String adminRestoreConfirmMessage(String name) {
    return 'Vil du gjenopprette sikkerhetskopien $name nå?';
  }

  @override
  String get adminBackupsTitle => 'Sikkerhetskopier';

  @override
  String get adminUnknownDate => 'Ukjent dato';

  @override
  String get adminUnnamedBackup => 'Sikkerhetskopiering uten navn';

  @override
  String get adminApply => 'Bruk';

  @override
  String get adminLogsTitle => 'Serverlogger';

  @override
  String get adminLogsNewestFirst => 'Nyeste først';

  @override
  String get adminLogsOldestFirst => 'Eldste først';

  @override
  String get adminLogsJustNow => 'Akkurat nå';

  @override
  String adminLogsMinutesAgo(int minutes) {
    return '$minutes min siden';
  }

  @override
  String adminLogsHoursAgo(int hours) {
    return '$hours t siden';
  }

  @override
  String adminLogsDaysAgo(int days) {
    return '$days d siden';
  }

  @override
  String adminLogViewerLoadFailed(String fileName) {
    return 'Kunne ikke laste inn $fileName';
  }

  @override
  String adminLogViewerMatches(int count) {
    return '$count treff';
  }

  @override
  String get adminLogViewerNoMatches => 'Ingen samsvarende linjer';

  @override
  String get adminMetadataEditorTitle => 'Metadataredigerer';

  @override
  String get adminMetadataIdentify => 'Identifiser';

  @override
  String get adminMetadataType => 'Type';

  @override
  String get adminMetadataDetails => 'Detaljer';

  @override
  String get adminMetadataExternalIds => 'Eksterne IDer';

  @override
  String get adminMetadataImages => 'Bilder';

  @override
  String get adminMetadataFieldTitle => 'Tittel';

  @override
  String get adminMetadataFieldSortTitle => 'Sorter tittel';

  @override
  String get adminMetadataFieldOriginalTitle => 'Originaltittel';

  @override
  String get adminMetadataFieldPremiereDate => 'Premieredato (ÅÅÅÅ-MM-DD)';

  @override
  String get adminMetadataFieldEndDate => 'Sluttdato (ÅÅÅÅ-MM-DD)';

  @override
  String get adminMetadataFieldProductionYear => 'Produksjonsår';

  @override
  String get adminMetadataFieldOfficialRating => 'Offisiell vurdering';

  @override
  String get adminMetadataFieldCommunityRating => 'Samfunnsvurdering';

  @override
  String get adminMetadataFieldCriticRating => 'Kritikervurdering';

  @override
  String get adminMetadataFieldCustomRating => 'Egen aldersgrense';

  @override
  String get adminMetadataFieldTagline => 'Slagord';

  @override
  String get adminMetadataFieldOverview => 'Oversikt';

  @override
  String get adminMetadataFieldDisplayOrder => 'Visningsrekkefølge';

  @override
  String get adminMetadataDisplayOrderAired => 'Sendt';

  @override
  String get adminMetadataDisplayOrderOriginalAirDate =>
      'Opprinnelig sendedato';

  @override
  String get adminMetadataDisplayOrderAbsolute => 'Absolutt';

  @override
  String get adminMetadataDisplayOrderDvd => 'DVD';

  @override
  String get adminMetadataDisplayOrderDigital => 'Digital';

  @override
  String get adminMetadataDisplayOrderStoryArc => 'Handlingsbue';

  @override
  String get adminMetadataDisplayOrderProduction => 'Produksjon';

  @override
  String get adminMetadataDisplayOrderTv => 'TV';

  @override
  String get adminMetadataDisplayOrderAlternate => 'Alternativ';

  @override
  String get adminMetadataDisplayOrderRegional => 'Regional';

  @override
  String get adminMetadataDisplayOrderAlternateDvd => 'Alternativ DVD';

  @override
  String get adminMetadataDisplayOrderDateModified => 'Endringsdato';

  @override
  String get adminMetadataDisplayOrderSortName => 'Sorteringsnavn';

  @override
  String get adminMetadataDisplayOrderReleaseDate => 'Utgivelsesdato';

  @override
  String get adminMetadataSettings => 'Metadatainnstillinger';

  @override
  String get adminMetadataDownloadLanguage => 'Foretrukket nedlastingsspråk';

  @override
  String get adminMetadataCountryRegion => 'Land/region';

  @override
  String get adminMetadataInheritHelp =>
      'La dette stå på Standard for å arve innstillingen fra et overordnet element eller fra serverens standard.';

  @override
  String get adminMetadataField3DFormat => '3D-format';

  @override
  String get adminMetadataPersonKindActor => 'Skuespiller';

  @override
  String get adminMetadataPersonKindDirector => 'Regissør';

  @override
  String get adminMetadataPersonKindComposer => 'Komponist';

  @override
  String get adminMetadataPersonKindWriter => 'Manusforfatter';

  @override
  String get adminMetadataPersonKindGuestStar => 'Gjesteskuespiller';

  @override
  String get adminMetadataPersonKindProducer => 'Produsent';

  @override
  String get adminMetadataPersonKindConductor => 'Dirigent';

  @override
  String get adminMetadataPersonKindLyricist => 'Tekstforfatter';

  @override
  String get adminMetadataPersonKindArranger => 'Arrangør';

  @override
  String get adminMetadataPersonKindEngineer => 'Lydtekniker';

  @override
  String get adminMetadataPersonKindMixer => 'Mikser';

  @override
  String get adminMetadataPersonKindRemixer => 'Remikser';

  @override
  String get adminMetadataPersonKindCreator => 'Skaper';

  @override
  String get adminMetadataPersonKindArtist => 'Artist';

  @override
  String get adminMetadataPersonKindAlbumArtist => 'Albumartist';

  @override
  String get adminMetadataPersonKindAuthor => 'Forfatter';

  @override
  String get adminMetadataPersonKindIllustrator => 'Illustratør';

  @override
  String get adminMetadataPersonKindPenciller => 'Tegner';

  @override
  String get adminMetadataPersonKindInker => 'Tusjer';

  @override
  String get adminMetadataPersonKindColorist => 'Kolorist';

  @override
  String get adminMetadataPersonKindLetterer => 'Tekster';

  @override
  String get adminMetadataPersonKindCoverArtist => 'Omslagstegner';

  @override
  String get adminMetadataPersonKindEditor => 'Redaktør';

  @override
  String get adminMetadataPersonKindTranslator => 'Oversetter';

  @override
  String get adminMetadataPersonKindNarrator => 'Forteller';

  @override
  String get adminMetadataAirDays => 'Sendedager';

  @override
  String get adminMetadataLockItem =>
      'Lås dette elementet mot fremtidige metadataendringer';

  @override
  String get adminMetadataEnabledFields => 'Aktive felt';

  @override
  String get adminMetadataEnabledFieldsHelp =>
      'Fjern haken for et felt for å låse det, slik at dataene ikke kan endres.';

  @override
  String get adminMetadataLockFieldName => 'Navn';

  @override
  String get adminMetadataLockFieldOverview => 'Sammendrag';

  @override
  String get adminMetadataLockFieldGenres => 'Sjangre';

  @override
  String get adminMetadataLockFieldOfficialRating => 'Aldersgrense';

  @override
  String get adminMetadataLockFieldCast => 'Personer';

  @override
  String get adminMetadataLockFieldProductionLocations => 'Produksjonssteder';

  @override
  String get adminMetadataLockFieldBirthLocation => 'Fødested';

  @override
  String get adminMetadataLockFieldRuntime => 'Spilletid';

  @override
  String get adminMetadataLockFieldStudios => 'Studioer';

  @override
  String get adminMetadataLockFieldTags => 'Stikkord';

  @override
  String get adminMetadataGenres => 'Sjangere';

  @override
  String get adminMetadataTags => 'Tagger';

  @override
  String get adminMetadataStudios => 'Studioer';

  @override
  String get adminMetadataPeople => 'Mennesker';

  @override
  String get adminMetadataAddGenre => 'Legg til sjanger';

  @override
  String get adminMetadataAddTag => 'Legg til tag';

  @override
  String get adminMetadataAddStudio => 'Legg til studio';

  @override
  String get adminMetadataAddPerson => 'Legg til person';

  @override
  String get adminMetadataEditPerson => 'Rediger person';

  @override
  String get adminMetadataRole => 'Rolle';

  @override
  String get adminMetadataImagePrimary => 'Primær';

  @override
  String get adminMetadataImageBackdrop => 'Bakteppe';

  @override
  String get adminMetadataImageLogo => 'Logo';

  @override
  String get adminMetadataImageBanner => 'Banner';

  @override
  String get adminMetadataImageThumb => 'Tommel';

  @override
  String get adminMetadataProvider => 'Leverandør';

  @override
  String adminMetadataImageUpdated(String imageType) {
    return '$imageType-bildet er oppdatert';
  }

  @override
  String adminMetadataImageUploaded(String imageType) {
    return '$imageType-bildet er lastet opp';
  }

  @override
  String adminMetadataImageDeleted(String imageType) {
    return '$imageType-bildet er slettet';
  }

  @override
  String adminMetadataImageDownloadFailed(String error) {
    return 'Kunne ikke laste ned bildet: $error';
  }

  @override
  String get adminMetadataImageReadFailed =>
      'Kunne ikke lese det valgte bildet';

  @override
  String adminMetadataImageUploadFailed(String error) {
    return 'Kunne ikke laste opp bildet: $error';
  }

  @override
  String adminMetadataDeleteImageTitle(String imageType) {
    return 'Slett $imageType-bildet';
  }

  @override
  String get adminMetadataDeleteImageContent =>
      'Dette fjerner det gjeldende bildet fra elementet.';

  @override
  String adminMetadataImageDeleteFailed(String error) {
    return 'Kunne ikke slette bildet: $error';
  }

  @override
  String adminMetadataChooseImage(String imageType) {
    return 'Velg $imageType-bilde';
  }

  @override
  String get adminMetadataUpload => 'Last opp';

  @override
  String get adminMetadataUpdate => 'Oppdater';

  @override
  String get adminMetadataRemoteImage => 'Eksternt bilde';

  @override
  String get adminPluginsInstalled => 'Installert';

  @override
  String get adminPluginsCatalog => 'Katalog';

  @override
  String get adminPluginsActive => 'Aktiv';

  @override
  String get adminPluginsRestart => 'Start på nytt';

  @override
  String get adminPluginsRestartRequired => 'Krever omstart';

  @override
  String get adminPluginsNoSearchResults =>
      'Ingen plugins samsvarer med søket ditt';

  @override
  String get adminPluginsNoneInstalled => 'Ingen plugins installert';

  @override
  String get adminPluginsNoneActive => 'Ingen aktive tillegg';

  @override
  String get adminPluginsNoneRequireRestart =>
      'Ingen tillegg krever omstart av serveren';

  @override
  String adminPluginsUpdateAvailable(String version) {
    return 'Oppdatering tilgjengelig: v$version';
  }

  @override
  String get adminPluginsUpdateAvailableGeneric => 'Oppdatering tilgjengelig';

  @override
  String get adminPluginsPendingRemoval => 'Venter på fjerning etter omstart';

  @override
  String get adminPluginsChangesPending => 'Endringer som venter på omstart';

  @override
  String get adminPluginsEnable => 'Aktiver';

  @override
  String get adminPluginsDisable => 'Deaktiver';

  @override
  String get adminPluginsInstallUpdate => 'Installer oppdatering';

  @override
  String adminPluginsInstallUpdateVersioned(String version) {
    return 'Installer oppdatering (v$version)';
  }

  @override
  String get adminPluginsCatalogNoSearchResults =>
      'Ingen pakker samsvarer med søket ditt';

  @override
  String get adminPluginsCatalogEmpty => 'Ingen tilgjengelige pakker';

  @override
  String adminPluginsInstalling(String name) {
    return '«$name» installeres...';
  }

  @override
  String get adminPluginDetailExperimental => 'Eksperimentell integrasjon';

  @override
  String get adminPluginDetailExperimentalContent =>
      'Integrasjon av plugin-innstillinger er fortsatt eksperimentell. Noen felt eller oppsett kan ikke gjengis riktig ennå.';

  @override
  String get adminPluginDetailToggle404 =>
      'Kunne ikke bytte plugin. Serveren kunne ikke finne denne plugin-versjonen. Prøv å oppdatere plugins, og prøv deretter på nytt.';

  @override
  String get adminPluginDetailToggleDioError =>
      'Kunne ikke bytte plugin. Vennligst sjekk serverloggene for detaljer.';

  @override
  String adminPluginDetailSettingsTitle(String name) {
    return '$name-innstillinger';
  }

  @override
  String get adminPluginDetailDetails => 'Detaljer';

  @override
  String get adminPluginDetailDeveloper => 'Utvikler';

  @override
  String get adminPluginDetailRepository => 'Depot';

  @override
  String get adminPluginDetailBundled => 'Buntet';

  @override
  String get adminPluginDetailEnablePlugin => 'Aktiver plugin';

  @override
  String get adminPluginDetailRestartRequired =>
      'En omstart av serveren er nødvendig for at endringer skal tre i kraft.';

  @override
  String get adminPluginDetailRemovalPending =>
      'Denne plugin-en vil bli fjernet etter omstart av serveren.';

  @override
  String get adminPluginDetailMalfunctioned =>
      'Denne plugin-en har fungert feil og fungerer kanskje ikke som den skal.';

  @override
  String get adminPluginDetailNotSupported =>
      'Denne plugin-modulen støttes ikke av den gjeldende serverversjonen.';

  @override
  String get adminPluginDetailSuperseded =>
      'Denne plugin-en har blitt erstattet av en nyere versjon.';

  @override
  String adminReposLoadFailed(String error) {
    return 'Kunne ikke laste inn repositoriene: $error';
  }

  @override
  String get adminReposRemoveTitle => 'Fjern repository';

  @override
  String adminReposRemoveConfirm(String name) {
    return 'Er du sikker på at du vil fjerne «$name»?';
  }

  @override
  String get adminReposRemove => 'Fjern';

  @override
  String adminReposSaveFailed(String error) {
    return 'Kunne ikke lagre repositoriene: $error';
  }

  @override
  String get adminReposEmpty => 'Ingen repositories konfigurert';

  @override
  String get adminReposEmptySubtitle =>
      'Legg til et depot for å bla gjennom tilgjengelige plugins';

  @override
  String get adminReposUnnamed => '(uten navn)';

  @override
  String get adminReposEditTitle => 'Rediger depot';

  @override
  String get adminReposAddTitle => 'Legg til arkiv';

  @override
  String get adminReposUrl => 'Repositorie-URL';

  @override
  String get adminReposNameHint => 'f.eks. Jellyfin Stall';

  @override
  String get adminPluginSettingsInvalidUrl => 'Ugyldig URL';

  @override
  String get adminGeneralSettingsTitle => 'Generelle innstillinger';

  @override
  String get adminGeneralMetadataLanguage => 'Foretrukket metadataspråk';

  @override
  String get adminGeneralMetadataLanguageHint => 'f.eks. no, de, fr';

  @override
  String get adminGeneralMetadataCountry => 'Foretrukket metadataland';

  @override
  String get adminGeneralMetadataCountryHint => 'f.eks. USA, DE, FR';

  @override
  String get adminGeneralLibraryScanConcurrency => 'Bibliotekskanning samtidig';

  @override
  String get adminGeneralImageEncodingLimit =>
      'Grensen for koding av parallelle bilder';

  @override
  String get adminUnknownError => 'Ukjent feil';

  @override
  String get adminBrowse => 'Bla gjennom';

  @override
  String get adminCloseBrowser => 'Lukk nettleseren';

  @override
  String get adminNetworkingTitle => 'Nettverk';

  @override
  String get adminNetworkingRestartWarning =>
      'Endringer i nettverksinnstillinger kan kreve omstart av serveren.';

  @override
  String get adminNetworkingEnableHttps => 'Aktiver HTTPS';

  @override
  String get adminNetworkingAddressHint => 'f.eks. 192.168.1.0/24';

  @override
  String get adminNetworkingKnownProxies => 'Kjente fullmektiger';

  @override
  String get adminNetworkingProxyHint => 'f.eks. 10.0.0.1';

  @override
  String get adminNetworkingWhitelist => 'Hviteliste';

  @override
  String get adminNetworkingBlacklist => 'Svarteliste';

  @override
  String get adminNetworkingAddEntry => 'Legg til oppføring';

  @override
  String get adminBrandingTitle => 'Merkevarebygging';

  @override
  String get adminBrandingLoginDisclaimer =>
      'Ansvarsfraskrivelse for pålogging';

  @override
  String get adminBrandingLoginDisclaimerHint =>
      'HTML vist under påloggingsskjemaet';

  @override
  String get adminBrandingCustomCss => 'Egendefinert CSS';

  @override
  String get adminBrandingCustomCssHint =>
      'Egendefinert CSS brukt på nettgrensesnittet';

  @override
  String get adminBrandingEnableSplash => 'Aktiver velkomstskjerm';

  @override
  String get adminBrandingSplashUpload => 'Last opp bilde';

  @override
  String get adminBrandingSplashUploaded => 'Velkomstskjermen er oppdatert';

  @override
  String get adminBrandingSplashUploadFailed =>
      'Kunne ikke laste opp velkomstskjermen';

  @override
  String get adminBrandingSplashDeleted => 'Velkomstskjermen er fjernet';

  @override
  String get adminBrandingNoSplash => 'Ingen egendefinert velkomstskjerm';

  @override
  String get adminPlaybackHwAccel => 'Maskinvareakselerasjon';

  @override
  String get adminPlaybackHwAccelLabel => 'Maskinvareakselerasjon';

  @override
  String get adminPlaybackEnableHwEncoding => 'Aktiver maskinvarekoding';

  @override
  String get adminPlaybackQsvDevice => 'QSV-enhet';

  @override
  String get adminPlaybackEnhancedNvdec => 'Aktiver forbedret NVDEC-dekoder';

  @override
  String get adminPlaybackPreferNativeDecoder =>
      'Foretrekk systemets egen maskinvaredekoder';

  @override
  String get adminPlaybackColorDepth10Hevc => '10-bits HEVC-dekoding';

  @override
  String get adminPlaybackColorDepth10Vp9 => '10-bits VP9-dekoding';

  @override
  String get adminPlaybackColorDepth10HevcRext =>
      'HEVC RExt 8/10-bits dekoding';

  @override
  String get adminPlaybackColorDepth12HevcRext => 'HEVC RExt 12-bits dekoding';

  @override
  String get adminPlaybackHwEncodingSection => 'Maskinvarekoding';

  @override
  String get adminPlaybackAllowHevcEncoding => 'Tillat HEVC-koding';

  @override
  String get adminPlaybackAllowAv1Encoding => 'Tillat AV1-koding';

  @override
  String get adminPlaybackIntelLowPowerH264 =>
      'Aktiver Intels lavenergi-H.264-koder';

  @override
  String get adminPlaybackIntelLowPowerHevc =>
      'Aktiver Intels lavenergi-HEVC-koder';

  @override
  String get adminPlaybackToneMapping => 'Tone mapping';

  @override
  String get adminPlaybackEnableTonemapping => 'Aktiver tone mapping';

  @override
  String get adminPlaybackEnableVppTonemapping => 'Aktiver VPP tone mapping';

  @override
  String get adminPlaybackEnableVtTonemapping =>
      'Aktiver VideoToolbox tone mapping';

  @override
  String get adminPlaybackTonemappingAlgorithm => 'Algoritme for tone mapping';

  @override
  String get adminPlaybackTonemappingMode => 'Modus for tone mapping';

  @override
  String get adminPlaybackTonemappingRange => 'Område for tone mapping';

  @override
  String get adminPlaybackTonemappingDesat => 'Avmetning for tone mapping';

  @override
  String get adminPlaybackTonemappingPeak => 'Topp for tone mapping';

  @override
  String get adminPlaybackTonemappingParam => 'Parameter for tone mapping';

  @override
  String get adminPlaybackVppTonemappingBrightness =>
      'Lysstyrke for VPP tone mapping';

  @override
  String get adminPlaybackVppTonemappingContrast =>
      'Kontrast for VPP tone mapping';

  @override
  String get adminPlaybackEncoderPreset => 'Forhåndsinnstilling for koder';

  @override
  String get adminPlaybackH264Crf => 'CRF for H.264-koding';

  @override
  String get adminPlaybackH265Crf => 'CRF for H.265-koding (HEVC)';

  @override
  String get adminPlaybackDeinterlaceMethod => 'Deinterlace-metode';

  @override
  String get adminPlaybackDeinterlaceDoubleRate =>
      'Doble bildefrekvensen ved deinterlacing';

  @override
  String get adminPlaybackAudioSection => 'Lyd';

  @override
  String get adminPlaybackEnableAudioVbr => 'Aktiver VBR-koding for lyd';

  @override
  String get adminPlaybackDownmixBoost => 'Forsterkning ved nedmiksing av lyd';

  @override
  String get adminPlaybackDownmixAlgorithm => 'Algoritme for stereonedmiksing';

  @override
  String get adminPlaybackMaxMuxingQueue => 'Maks størrelse på muxekøen';

  @override
  String get adminPlaybackAutoOption => 'Auto';

  @override
  String get adminPlaybackEncoding => 'Koding';

  @override
  String get adminPlaybackEncodingThreads => 'Koding av tråder';

  @override
  String get adminPlaybackFallbackFont => 'Aktiver reservefont';

  @override
  String get adminPlaybackFallbackFontPath => 'Reserve skriftbane';

  @override
  String get adminPlaybackStreaming => 'Strømming';

  @override
  String get adminResumeVideo => 'Video';

  @override
  String get adminResumeAudiobooks => 'Lydbøker';

  @override
  String get adminStreamingBitrateLimit =>
      'Ekstern klientbithastighetsgrense (Mbps)';

  @override
  String get adminStreamingBitrateLimitHint =>
      'La stå tomt eller 0 for ubegrenset';

  @override
  String get adminTrickplayHwAccel => 'Aktiver maskinvareakselerasjon';

  @override
  String get adminTrickplayHwEncoding => 'Aktiver maskinvarekoding';

  @override
  String get adminTrickplayKeyFrameOnly =>
      'Aktiver uttrekking av kun nøkkelramme';

  @override
  String get adminTrickplayKeyFrameOnlySubtitle =>
      'Raskere, men lavere nøyaktighet';

  @override
  String get adminTrickplayNonBlocking => 'Ikke-blokkerende';

  @override
  String get adminTrickplayBlocking => 'Blokkering';

  @override
  String get adminTrickplayPriorityHigh => 'Høy';

  @override
  String get adminTrickplayPriorityAboveNormal => 'Over Normal';

  @override
  String get adminTrickplayPriorityNormal => 'Normal';

  @override
  String get adminTrickplayPriorityBelowNormal => 'Under Normal';

  @override
  String get adminTrickplayPriorityIdle => 'Uvirksom';

  @override
  String get adminTrickplayImageSettings => 'Bildeinnstillinger';

  @override
  String get adminTrickplayInterval => 'Intervall (ms)';

  @override
  String get adminTrickplayIntervalSubtitle => 'Hvor ofte du skal ta bilder';

  @override
  String get adminTrickplayWidthResolutionsHint =>
      'Kommaseparerte pikselbredder (f.eks. 320)';

  @override
  String get adminTrickplayQuality => 'Kvalitet';

  @override
  String get adminTrickplayQScale => 'Kvalitetsskala';

  @override
  String get adminTrickplayQScaleSubtitle =>
      'Lavere verdier = bedre kvalitet, større filer';

  @override
  String get adminTrickplayJpegQuality => 'JPEG-kvalitet';

  @override
  String get adminTrickplayProcessing => 'Behandling';

  @override
  String get adminTasksEmpty => 'Fant ingen planlagte oppgaver';

  @override
  String get adminTasksNoFilterMatch =>
      'Ingen oppgaver samsvarer med gjeldende filter';

  @override
  String get adminTaskCancelling => 'Avbryter …';

  @override
  String get adminTaskRunning => 'Kjører...';

  @override
  String get adminTaskNeverRun => 'Aldri løp';

  @override
  String get adminTaskStop => 'Stopp';

  @override
  String get adminRunningTasks => 'Oppgaver som kjører';

  @override
  String get adminTaskRun => 'Løp';

  @override
  String get adminTaskDetailLastExecution => 'Siste utførelse';

  @override
  String get adminTaskDetailStarted => 'Startet';

  @override
  String get adminTaskDetailEnded => 'Avsluttet';

  @override
  String get adminTaskDetailDuration => 'Varighet';

  @override
  String get adminTaskDetailErrorLabel => 'Feil:';

  @override
  String adminTaskTriggerDaily(String time) {
    return 'Daglig kl. $time';
  }

  @override
  String adminTaskTriggerWeekly(String day, String time) {
    return 'Hver $day kl. $time';
  }

  @override
  String get adminTaskTriggerStartup => 'Ved oppstart av applikasjon';

  @override
  String get adminTaskTriggerTypeDaily => 'Daglig';

  @override
  String get adminTaskTriggerTypeWeekly => 'Ukentlig';

  @override
  String get adminTaskTriggerTypeInterval => 'På et intervall';

  @override
  String get adminTaskTriggerIntervalLabel => 'Intervall';

  @override
  String get adminTaskTriggerEveryHour => 'Hver time';

  @override
  String adminTaskTriggerHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timer',
      one: '1 time',
    );
    return '$_temp0';
  }

  @override
  String get adminTaskTriggerTime => 'Tid';

  @override
  String get adminActivityJustNow => 'Akkurat nå';

  @override
  String get adminActivityLastHour => 'Siste time';

  @override
  String get adminActivityToday => 'I dag';

  @override
  String get adminActivityYesterday => 'I går';

  @override
  String get adminActivityOlder => 'Eldre';

  @override
  String adminActivityDaysAgo(int days) {
    return '$days d siden';
  }

  @override
  String adminActivityHoursAgo(int hours) {
    return '$hours t siden';
  }

  @override
  String adminActivityMinutesAgo(int minutes) {
    return '$minutes min siden';
  }

  @override
  String get adminActivityNow => 'nå';

  @override
  String adminActivityMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String adminActivityHoursShort(int hours) {
    return '$hours t';
  }

  @override
  String adminActivityDaysShort(int days) {
    return '$days d';
  }

  @override
  String adminActivityDateShort(int month, int day) {
    return '$day.$month';
  }

  @override
  String get adminTrickplayDescription =>
      'Konfigurer trickplay-bildegenerering for forhåndsvisningsminiatyrbilder.';

  @override
  String get adminNetworkingPublicHttpsPort => 'Offentlig HTTPS-port';

  @override
  String get adminNetworkingBaseUrl => 'Base-URL';

  @override
  String get adminNetworkingBaseUrlHint => 'f.eks. /jellyfin';

  @override
  String get adminNetworkingPublicHttpPort => 'Offentlig HTTP-port';

  @override
  String get adminNetworkingRequireHttps => 'Krev HTTPS';

  @override
  String get adminNetworkingRequireHttpsHint =>
      'Omdiriger alle eksterne forespørsler til HTTPS. Har ingen effekt hvis serveren ikke har et gyldig sertifikat.';

  @override
  String get adminNetworkingCertPassword => 'Sertifikatpassord';

  @override
  String get adminNetworkingEnableIpv4 => 'Aktiver IPv4';

  @override
  String get adminNetworkingEnableIpv6 => 'Aktiver IPv6';

  @override
  String get adminNetworkingLocalSubnets => 'LAN-nettverk';

  @override
  String get adminNetworkingRemoteIpFilterLabel => 'Eksternt IP-filter';

  @override
  String get adminPlaybackVaapiDevice => 'VA-API-enhet';

  @override
  String get adminPlaybackAutomatic => '0 = automatisk';

  @override
  String get adminPlaybackTranscodeTempPath => 'Transkoding temp bane';

  @override
  String get adminPlaybackSegmentDeletion => 'Tillat sletting av segmenter';

  @override
  String get adminPlaybackSegmentKeep => 'Segmenthold (sekunder)';

  @override
  String get adminPlaybackThrottleBuffering => 'Gassbuffring';

  @override
  String get adminPlaybackThrottleDelay =>
      'Forsinkelse for struping (sekunder)';

  @override
  String get adminPlaybackEnableSubtitleExtraction =>
      'Tillat uttrekking av undertekster underveis';

  @override
  String get adminResumeMinPct => 'Minste CV-prosent';

  @override
  String get adminResumeMinPctSubtitle =>
      'Innhold må spilles over denne prosentandelen for å lagre fremdrift';

  @override
  String get adminResumeMaxPct => 'Maksimal gjenoppta prosentandel';

  @override
  String get adminResumeMaxPctSubtitle =>
      'Innhold anses som fullt spilt etter denne prosentandelen';

  @override
  String get adminResumeMinDuration => 'Minimum gjenoppta varighet (sekunder)';

  @override
  String get adminResumeMinDurationSubtitle =>
      'Elementer som er kortere enn dette kan ikke gjenopptas';

  @override
  String get adminTrickplayScanBehavior => 'Skanneadferd';

  @override
  String get adminTrickplayProcessPriority => 'Prosessprioritet';

  @override
  String get adminTrickplayTileWidth => 'Flisbredde';

  @override
  String get adminTrickplayTileHeight => 'Flishøyde';

  @override
  String get adminTrickplayProcessThreads => 'Behandle tråder';

  @override
  String get adminTrickplayWidthResolutions => 'Breddeoppløsninger';

  @override
  String get adminMetadataDefault => 'Misligholde';

  @override
  String get adminMetadataContentTypeUpdated => 'Innholdstype oppdatert';

  @override
  String adminMetadataContentTypeFailed(String error) {
    return 'Kunne ikke oppdatere innholdstypen: $error';
  }

  @override
  String get adminGeneralSlowResponseThreshold => 'Langsom responsterskel (ms)';

  @override
  String get adminGeneralEnableSlowResponse =>
      'Aktiver advarsler om trege svar';

  @override
  String get adminGeneralQuickConnect => 'Aktiver hurtigkobling';

  @override
  String get adminGeneralSectionServer => 'Server';

  @override
  String get adminGeneralSectionMetadata => 'Metadata';

  @override
  String get adminGeneralSectionPaths => 'Baner';

  @override
  String get adminGeneralSectionPerformance => 'Ytelse';

  @override
  String get adminGeneralCachePath => 'Bufferbane';

  @override
  String get adminGeneralMetadataPath => 'Metadatabane';

  @override
  String get adminGeneralServerName => 'Servernavn';

  @override
  String get adminGeneralDisplayLanguage => 'Foretrukket visningsspråk';

  @override
  String get adminSettingsLoadFailed => 'Kunne ikke laste inn innstillingene';

  @override
  String adminChannelMappingsUpdateFailed(String error) {
    return 'Kunne ikke oppdatere tilordningene: $error';
  }

  @override
  String adminTimeLimitDuration(String duration) {
    return 'Tidsgrense: $duration';
  }

  @override
  String get folders => 'Mapper';

  @override
  String get libraries => 'Biblioteker';

  @override
  String get syncPlay => 'SyncPlay';

  @override
  String get syncPlayDisabledTitle => 'SyncPlay deaktivert';

  @override
  String get syncPlayDisabledMessage =>
      'Aktiver SyncPlay i Innstillinger for å bruke synkronisert avspilling.';

  @override
  String get syncPlayServerUnsupportedTitle => 'Server støttes ikke';

  @override
  String get syncPlayServerUnsupportedMessage =>
      'SyncPlay krever en Jellyfin-server. Den gjeldende serveren støtter det ikke.';

  @override
  String get syncPlayGroupFallbackName => 'SyncPlay-gruppe';

  @override
  String get syncPlayGroupTooltip => 'SyncPlay-gruppe';

  @override
  String syncPlayParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# deltakere',
      one: '# deltaker',
    );
    return '$_temp0';
  }

  @override
  String get syncPlayIgnoreWait => 'Ignorer vent';

  @override
  String get syncPlayIgnoreWaitSubtitle =>
      'Ikke hold gruppen oppe mens denne enheten bufrer';

  @override
  String get syncPlayContinueLocallyNoWait =>
      'Fortsett lokalt uten å vente på trege medlemmer';

  @override
  String get syncPlayRepeat => 'Gjenta';

  @override
  String get syncPlayRepeatOne => 'En';

  @override
  String get syncPlayShuffleModeShuffled => 'Blandet';

  @override
  String get syncPlayShuffleModeSorted => 'Sortert';

  @override
  String get syncPlaySyncCurrentQueue => 'Synkroniser gjeldende avspillingskø';

  @override
  String get syncPlaySyncCurrentQueueSubtitle =>
      'Bytt ut gruppekøen med det som spilles lokalt';

  @override
  String get syncPlayLeaveGroup => 'Forlat gruppen';

  @override
  String get syncPlayGroupQueue => 'Gruppekø';

  @override
  String syncPlayQueueItemFallback(int index) {
    return 'Element $index';
  }

  @override
  String get syncPlayPlayNow => 'Spill nå';

  @override
  String get syncPlayCreateNewGroup => 'Opprett en ny gruppe';

  @override
  String get syncPlayGroupName => 'Gruppenavn';

  @override
  String get syncPlayDefaultGroupName => 'Min SyncPlay-gruppe';

  @override
  String get syncPlayCreateGroup => 'Opprett gruppe';

  @override
  String get syncPlayAvailableGroups => 'Tilgjengelige grupper';

  @override
  String get syncPlayNoGroupsAvailable => 'Ingen grupper tilgjengelig';

  @override
  String get syncPlayJoinGroupQuestion => 'Bli med i SyncPlay-gruppen?';

  @override
  String get syncPlayJoinGroupWarning =>
      'Å bli med i en SyncPlay-gruppe kan erstatte gjeldende avspillingskø. Fortsette?';

  @override
  String get syncPlayJoin => 'Bli med';

  @override
  String get syncPlayStateIdle => 'Uvirksom';

  @override
  String get syncPlayStateWaiting => 'Venter';

  @override
  String get syncPlayStatePaused => 'Pause';

  @override
  String get syncPlayStatePlaying => 'Spiller';

  @override
  String syncPlayUserJoinedGroup(String userName) {
    return '$userName ble med i SyncPlay-gruppen';
  }

  @override
  String syncPlayUserLeftGroup(String userName) {
    return '$userName forlot SyncPlay-gruppen';
  }

  @override
  String get syncPlayAccessDeniedTitle => 'SyncPlay-tilgang nektet';

  @override
  String get syncPlayAccessDeniedMessage =>
      'Du har ikke tilgang til ett eller flere elementer i denne SyncPlay-gruppen. Be gruppeeieren om å bekrefte bibliotektillatelser eller velge en annen kø.';

  @override
  String syncPlaySyncingPlaybackToGroup(String groupName) {
    return 'Synkroniserer avspilling til $groupName';
  }

  @override
  String get voiceSearchUnavailable => 'Talesøk er utilgjengelig.';

  @override
  String get dolbyVisionDirectPlayFailedTitle =>
      'Dolby Vision Direct-avspilling mislyktes';

  @override
  String get dolbyVisionDirectPlayFailedMessage =>
      'Direkte avspilling kunne ikke starte for denne Dolby Vision-strømmen. Prøve å bruke servertranscode på nytt?';

  @override
  String get retryWithTranscode => 'Prøv på nytt med transkoding';

  @override
  String get dolbyVisionNotSupportedTitle => 'Dolby Vision støttes ikke';

  @override
  String get dolbyVisionNotSupportedMessage =>
      'Denne enheten kan ikke dekode Dolby Vision-innhold direkte. Bruk HDR10 reserve- eller be om serveromkoding.';

  @override
  String get rememberMyChoice => 'Husk valget mitt';

  @override
  String get playHdr10Fallback => 'Spill HDR10 reserve';

  @override
  String get requestTranscode => 'Be om omkoding';

  @override
  String integrationRowsDiscoveredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# rader oppdaget',
      one: '# rad oppdaget',
    );
    return '$_temp0';
  }

  @override
  String get seeAll => 'Se alle';

  @override
  String get noItems => 'Ingen varer';

  @override
  String get switchUser => 'Bytt bruker';

  @override
  String get remoteControl => 'Fjernkontroll';

  @override
  String get mediaBarLoading => 'Laster medielinje ...';

  @override
  String get mediaBarError => 'Mediefeltet kunne ikke lastes inn';

  @override
  String get offlineServerUnavailable =>
      'Koblet til internett, men gjeldende server er utilgjengelig.';

  @override
  String get offlineNoInternet =>
      'Du er frakoblet. Kun nedlastet innhold er tilgjengelig.';

  @override
  String get offlineFileNotAvailable => 'Filen er ikke tilgjengelig';

  @override
  String get offlineSwitchServer => 'Bytt server';

  @override
  String get offlineSavedMedia => 'Lagrede medier';

  @override
  String get offlineBannerTitle => 'Du er frakoblet';

  @override
  String get offlineBannerSubtitle => 'Viser nedlastingene dine';

  @override
  String get serverUnreachableBannerTitle => 'Får ikke kontakt med serveren';

  @override
  String get serverUnreachableBannerSubtitle =>
      'Spiller av fra nedlastinger til den er tilbake';

  @override
  String get castGoogleCast => 'Google Cast';

  @override
  String get castAirPlay => 'AirPlay';

  @override
  String get castDlna => 'DLNA';

  @override
  String get castRemotePlayback => 'Fjernavspilling';

  @override
  String castControlFailed(String error) {
    return 'Cast-kontrollen mislyktes: $error';
  }

  @override
  String castKindControls(String kind) {
    return '$kind-kontroller';
  }

  @override
  String get castDeviceVolume => 'Enhetsvolum';

  @override
  String get castVolumeUnavailable => 'Utilgjengelig';

  @override
  String castStopKind(String kind) {
    return 'Stopp $kind';
  }

  @override
  String get audioLabel => 'Lyd';

  @override
  String get subtitlesLabel => 'Undertekster';

  @override
  String get pinConfirmTitle => 'Bekreft PIN';

  @override
  String get pinSetTitle => 'Angi PIN-kode';

  @override
  String get pinEnterTitle => 'Skriv inn PIN';

  @override
  String get pinReenterToConfirm =>
      'Skriv inn PIN-koden på nytt for å bekrefte';

  @override
  String pinEnterNDigit(int length) {
    return 'Angi en $length-sifret PIN';
  }

  @override
  String pinEnterYourNDigit(int length) {
    return 'Angi din $length-sifrede PIN';
  }

  @override
  String get kidsMode => 'Barnemodus';

  @override
  String get kidsModeSubtitle =>
      'Forenkle appen og lås utgangen med en PIN-kode';

  @override
  String get kidsModeExit => 'Avslutt barnemodus';

  @override
  String get kidsModeExitSubtitle =>
      'Skriv inn PIN-koden for å få tilbake hele appen';

  @override
  String get pinIncorrect => 'Feil PIN-kode';

  @override
  String pinTryAgainIn(String wait) {
    return 'For mange forsøk. Prøv igjen om $wait.';
  }

  @override
  String get pinMismatch => 'PIN-kodene stemmer ikke overens';

  @override
  String get pinForgot => 'Glemt PIN-koden?';

  @override
  String get pinClear => 'Tøm';

  @override
  String get pinBackspace => 'Tilbake';

  @override
  String get quickConnectAuthorized =>
      'Hurtigkoblingsforespørselen er autorisert.';

  @override
  String get quickConnectInvalidOrExpired =>
      'Hurtigkoblingskoden er ugyldig eller utløpt.';

  @override
  String get quickConnectNotSupported =>
      'Hurtigkobling støttes ikke på denne serveren.';

  @override
  String get quickConnectAuthorizeFailed =>
      'Kunne ikke autorisere hurtigkoblingskoden.';

  @override
  String get quickConnectDisabled =>
      'Hurtigkobling er deaktivert på denne serveren.';

  @override
  String get quickConnectForbidden =>
      'Kontoen din kan ikke autorisere denne hurtigkoblingsforespørselen.';

  @override
  String get quickConnectNotFound =>
      'Hurtigkoblingskoden ble ikke funnet. Prøv en ny kode.';

  @override
  String quickConnectFailedWithMessage(String message) {
    return 'Hurtigkobling mislyktes: $message';
  }

  @override
  String get quickConnectEnterCode => 'Skriv inn kode';

  @override
  String get quickConnectAuthorize => 'Autorisere';

  @override
  String remoteCommandFailed(String error) {
    return 'Kommandoen mislyktes: $error';
  }

  @override
  String get remoteControlTitle => 'Fjernkontroll';

  @override
  String get remoteFailedToLoadSessions => 'Kunne ikke laste inn økter';

  @override
  String get remoteNoSessions => 'Ingen kontrollerbare økter';

  @override
  String get remoteStartPlayback => 'Start avspilling på en annen enhet';

  @override
  String get unknownUser => 'Ukjent';

  @override
  String get unknownItem => 'Ukjent';

  @override
  String get remoteNothingPlaying => 'Ingenting spiller på denne økten';

  @override
  String get castingStarted => 'Casting startet på valgt enhet';

  @override
  String castingFailed(String error) {
    return 'Kunne ikke starte casting: $error';
  }

  @override
  String get noRemoteDevices =>
      'Ingen eksterne avspillingsenheter tilgjengelig.';

  @override
  String get noRemoteDevicesIos =>
      'Ingen eksterne avspillingsenheter tilgjengelig.\n\nPå iOS kan AirPlay-mål være utilgjengelige i simulatoren.';

  @override
  String get trackActionPlayNext => 'Spill Neste';

  @override
  String get trackActionViewDetails => 'Vis detaljer';

  @override
  String get trackActionAddToQueue => 'Legg til i kø';

  @override
  String get trackActionAddToPlaylist => 'Legg til spilleliste';

  @override
  String get trackActionCancelDownload => 'Avbryt nedlasting';

  @override
  String get trackActionDeleteFromPlaylist => 'Slett fra spilleliste';

  @override
  String get trackActionMoveUp => 'Flytt opp';

  @override
  String get trackActionMoveDown => 'Flytt ned';

  @override
  String get trackActionRemoveFromFavorites => 'Fjern fra favoritter';

  @override
  String get trackActionAddToFavorites => 'Legg til i favoritter';

  @override
  String get trackActionGoToAlbum => 'Gå til Album';

  @override
  String get trackActionGoToArtist => 'Gå til artist';

  @override
  String trackActionDownloading(String name) {
    return 'Laster ned $name...';
  }

  @override
  String get trackActionDeletedFile => 'Slettet nedlastet fil';

  @override
  String get trackActionDeleteFileFailed => 'Kunne ikke slette nedlastet fil';

  @override
  String get shuffleBy => 'Bland av';

  @override
  String get shuffleSelectLibrary => 'Velg Bibliotek';

  @override
  String get shuffleSelectGenre => 'Velg sjanger';

  @override
  String get shuffleLibrary => 'Bibliotek';

  @override
  String get shuffleGenre => 'Sjanger';

  @override
  String get shuffleNoLibraries => 'Ingen kompatible biblioteker tilgjengelig.';

  @override
  String get shuffleNoGenres =>
      'Fant ingen sjangere for denne tilfeldige modusen.';

  @override
  String get posterDisplayTitle => 'Visning';

  @override
  String get posterImageType => 'Bildetype';

  @override
  String get imageTypePoster => 'Plakat';

  @override
  String get imageTypeThumbnail => 'Miniatyrbilde';

  @override
  String get imageTypeBanner => 'Banner';

  @override
  String get playlistAddFailed => 'Kunne ikke legge til spillelisten';

  @override
  String get playlistCreateFailed => 'Kunne ikke opprette spilleliste';

  @override
  String get playlistNew => 'Ny spilleliste';

  @override
  String get playlistCreate => 'Skape';

  @override
  String get playlistCreateNew => 'Opprett ny spilleliste';

  @override
  String get playlistNoneFound => 'Fant ingen spillelister';

  @override
  String get addToPlaylist => 'Legg til spilleliste';

  @override
  String get lyricsNotAvailable => 'Ingen tekster tilgjengelig';

  @override
  String get upNext => 'Neste';

  @override
  String get playNext => 'Spill Neste';

  @override
  String get stillWatchingContent =>
      'Avspillingen er satt på pause. Ser du fortsatt på?';

  @override
  String get stillWatchingStop => 'Stopp';

  @override
  String get stillWatchingContinue => 'Fortsette';

  @override
  String skipSegment(String segment) {
    return 'Hopp over $segment';
  }

  @override
  String get liveTv => 'Direktesendt TV';

  @override
  String get continueWatchingAndNextUp => 'Fortsett å se og neste opp';

  @override
  String downloadingBatchProgress(int current, int total, String fileName) {
    return 'Laster ned $current/$total — $fileName';
  }

  @override
  String downloadingFile(String fileName) {
    return 'Laster ned $fileName';
  }

  @override
  String get nextEpisode => 'Neste episode';

  @override
  String get moreFromThisSeason => 'Mer fra denne sesongen';

  @override
  String get playerTooltipPlaybackSpeed => 'Avspillingshastighet';

  @override
  String get playerTooltipCastControls => 'Cast-kontroller';

  @override
  String get playerTooltipPlaybackQuality => 'Bithastighet';

  @override
  String get playerTooltipEnterFullscreen => 'Gå inn i fullskjerm';

  @override
  String get playerTooltipExitFullscreen => 'Avslutt fullskjerm';

  @override
  String get playerTooltipFloatOnTop => 'Flyt på toppen';

  @override
  String get playerTooltipExitFloatOnTop => 'Deaktiver flyte på toppen';

  @override
  String get playerTooltipLockLandscape => 'Lås landskap';

  @override
  String get playerTooltipUnlockOrientation => 'Tillat rotasjon';

  @override
  String get playerTooltipPrevious => 'Forrige';

  @override
  String get playerTooltipSeekBack => 'Søk tilbake';

  @override
  String get playerTooltipSeekForward => 'Søk fremover';

  @override
  String get playerTooltipMinimize => 'Minimer spilleren';

  @override
  String get miniPlayerOpenPlayer => 'Åpne spilleren';

  @override
  String get contextMenuMarkWatched => 'Merk som sett';

  @override
  String get contextMenuMarkUnwatched => 'Merk som usett';

  @override
  String get contextMenuAddToFavorites => 'Legg til i favoritter';

  @override
  String get contextMenuRemoveFromFavorites => 'Fjern fra favoritter';

  @override
  String get contextMenuGoToSeries => 'Gå til serien';

  @override
  String get contextMenuHideFromContinueWatching => 'Skjul fra Fortsett å se';

  @override
  String get contextMenuHideFromNextUp => 'Skjul fra Neste opp';

  @override
  String get contextMenuAddToCollection => 'Legg til i samling';

  @override
  String get contextMenuRemoveFromCollection => 'Fjern fra samling';

  @override
  String removeFromCollectionConfirm(String item, String collection) {
    return 'Fjerne $item fra $collection? Elementet blir værende i biblioteket.';
  }

  @override
  String get removeFromCollectionFailed => 'Kunne ikke fjerne fra samlingen';

  @override
  String get settingsAdministrationSubtitle =>
      'Få tilgang til serveradministrasjonspanelet';

  @override
  String get settingsDynamicContent => 'Dynamisk innhold';

  @override
  String get settingsDynamicContentSubtitle => 'Media Bar og visuelle overlegg';

  @override
  String get settingsAboutSubtitle =>
      'Appversjon, juridisk informasjon og kreditter';

  @override
  String get settingsSortServersBy => 'Sorter servere etter';

  @override
  String get settingsLastUsed => 'Sist brukt';

  @override
  String get settingsAlphabetical => 'Alfabetisk';

  @override
  String get settingsAllowSelfSignedCerts => 'Tillat selvsignerte sertifikater';

  @override
  String get settingsAllowSelfSignedCertsSubtitle =>
      'Stol på servere som bruker selvsignerte TLS-sertifikater eller sertifikater fra en privat CA. Aktiver bare for servere du selv kontrollerer. Dette deaktiverer sertifikatvalidering for alle tilkoblinger.';

  @override
  String get untrustedServerCertificate =>
      'Sertifikatet til denne serveren er ikke klarert. Hvis det er din egen server og den bruker et selvsignert eller privat sertifikat, kan du tillate det her.';

  @override
  String get clientCertTitle => 'Klientsertifikat';

  @override
  String clientCertHost(String host) {
    return 'Sertifikat for $host';
  }

  @override
  String get clientCertChooseFile => 'Velg fil';

  @override
  String get clientCertPassword => 'Sertifikatpassord';

  @override
  String get clientCertStartUpload => 'Send fra telefonen';

  @override
  String get clientCertUploadHint =>
      'Skann koden med telefonen, eller åpne adressen i nettleseren der, og velg filen og skriv inn passordet.';

  @override
  String get clientCertStopUpload => 'Slutt å vente';

  @override
  String get clientCertNoFileData => 'Kunne ikke lese filen. Prøv igjen.';

  @override
  String get clientCertPickFailed => 'Kunne ikke åpne filvelgeren.';

  @override
  String get clientCertUploadFailed =>
      'Kunne ikke starte opplastingssiden. Prøv igjen.';

  @override
  String get clientCertNoSecureStorage =>
      'Denne enheten har ingen sikker lagring, så sertifikatet kan ikke lagres. På Linux installerer du libsecret og prøver igjen.';

  @override
  String get clientCertDecodeFailed =>
      'Kunne ikke lese filen som et sertifikat. Sjekk at det er en .p12 eller .pfx.';

  @override
  String get clientCertWrongPassword =>
      'Passordet låser ikke opp dette sertifikatet.';

  @override
  String get clientCertRequired =>
      'Denne serveren krever et klientsertifikat (mTLS). Legg til et for denne verten for å fortsette.';

  @override
  String clientCertExpired(String date) {
    return 'Sertifikatet for denne serveren gikk ut $date. Bytt det ut for å fortsette.';
  }

  @override
  String get clientCertAddButton => 'Legg til klientsertifikat';

  @override
  String get settingsClientCertificates => 'Klientsertifikater';

  @override
  String get settingsClientCertificatesSubtitle =>
      'Sertifikater appen viser fram til servere som krever det (mTLS)';

  @override
  String get clientCertSubject => 'Emne';

  @override
  String clientCertExpires(String date) {
    return 'Utløper $date';
  }

  @override
  String get clientCertReplace => 'Bytt ut';

  @override
  String get clientCertAdd => 'Legg til sertifikat';

  @override
  String get clientCertAddHostPrompt =>
      'Hvilken serververt trenger et sertifikat?';

  @override
  String get itemBlockedByParentalControls => 'Dette er ikke tilgjengelig';

  @override
  String get blockedRatingsCeilingHint =>
      'Å blokkere en aldersgrense blokkerer også alt som er strengere.';

  @override
  String get blockedRatingsUnrankedSection => 'Blokkerer bare seg selv';

  @override
  String get settingsHomePage => 'Hjemmeside';

  @override
  String get settingsTwentyFourHourClock => '24-timers klokke';

  @override
  String get settingsTwentyFourHourClockSubtitle =>
      'Bruk 24-timers tidsformatering uansett hvor klokken vises';

  @override
  String get settingsShowShuffleButtonInNavigation =>
      'Vis tilfeldig rekkefølge-knappen i navigasjonslinjen';

  @override
  String get settingsShowGenresButtonInNavigation =>
      'Vis sjangerknappen i navigasjonslinjen';

  @override
  String get settingsShowFavoritesButtonInNavigation =>
      'Vis favorittknappen i navigasjonslinjen';

  @override
  String get settingsShowLiveTvButtonInNavigation =>
      'Vis Direkte-TV-knappen i navigasjonslinjen når serveren har et Direkte-TV-bibliotek';

  @override
  String get settingsShowLibrariesButtonInNavigation =>
      'Vis bibliotek-knappen i navigasjonslinjen';

  @override
  String get settingsShowSeerrButtonInNavigation =>
      'Vis Seerr-knappen i navigasjonslinjen';

  @override
  String get settingsAlwaysExpandNavbarLabels =>
      'Vis alltid tekstetiketter i den øverste navigasjonslinjen';

  @override
  String get settingsLibraryVisibilitySubtitle =>
      'Slå av og på hjemmesidens synlighet per bibliotek. Start Tortugarr på nytt for at endringer skal tre i kraft.';

  @override
  String get settingsMediaBarAndLocalPreviews =>
      'Media Bar og lokale forhåndsvisninger';

  @override
  String get settingsVisualOverlays => 'Visuelle overlegg';

  @override
  String get settingsSeasonalSurprise => 'Sesongmessig overraskelse';

  @override
  String get useNativeEmulator => 'Innebygd emulering';

  @override
  String get useNativeEmulatorSubtitle =>
      'Spill med innebygde kjerner i stedet for EmulatorJS-nettspilleren';

  @override
  String get emulatorCores => 'Emulatorkjerner';

  @override
  String get emulatorCoresSubtitle =>
      'Last ned systemer for å spille spill direkte på enheten';

  @override
  String get emulatorCoresDescription =>
      'Velg hvilke systemer som skal installeres. Kjernene kommer fra libretro-prosjektet og lar spill kjøre direkte på enheten i stedet for i en nettleservisning.';

  @override
  String get emulatorCoreDownloading => 'Laster ned';

  @override
  String get emulatorCoreUnavailable => 'Ikke tilgjengelig for denne enheten';

  @override
  String get emulatorCoreDownloadFailed =>
      'Kunne ikke laste ned kjernen. Sjekk tilkoblingen og prøv igjen.';

  @override
  String emulatorCoreResetSettings(String system) {
    return 'Tilbakestill $system-innstillinger til standard';
  }

  @override
  String get emulatorCoreSettingsReset =>
      'Innstillingene er tilbakestilt til standard.';

  @override
  String get emulatorCoreResetSettingsFailed =>
      'Kunne ikke tilbakestille innstillingene. Sjekk tilkoblingen og prøv igjen.';

  @override
  String get downloadedGames => 'Nedlastede spill';

  @override
  String get downloadedGamesSubtitle => 'Frigjør plass brukt av spillfiler';

  @override
  String get downloadedGamesDescription =>
      'Spill kopieres til denne enheten før de startes. Fjern dem du er ferdig med for å frigjøre plass. Lagringer ligger på serveren og slettes ikke.';

  @override
  String get downloadedGamesEmpty =>
      'Ingen spill er lastet ned til denne enheten ennå.';

  @override
  String downloadedGamesTotal(int count, String size) {
    return '$count spill, $size';
  }

  @override
  String get removeAllDownloadedGames => 'Fjern alle';

  @override
  String removeDownloadedGameConfirm(String title) {
    return 'Fjerne $title fra denne enheten? Spillet lastes ned igjen neste gang du spiller det.';
  }

  @override
  String get removeAllDownloadedGamesConfirm =>
      'Fjerne alle nedlastede spill fra denne enheten? De lastes ned igjen neste gang du spiller dem.';

  @override
  String get settingsHigh => 'Høy';

  @override
  String get settingsLow => 'Lav';

  @override
  String get settingsCustomPath => 'Egendefinert bane';

  @override
  String get settingsEnterDownloadFolderPath =>
      'Angi banen for nedlastingsmappe';

  @override
  String get settingsConcurrentDownloads => 'Samtidige nedlastinger';

  @override
  String get settingsConcurrentDownloadsDescription =>
      'Maksimalt antall elementer å laste ned samtidig.';

  @override
  String get settingsAppInfo => 'APPINFO';

  @override
  String get settingsReportAnIssue => 'Rapporter et problem';

  @override
  String get settingsReportAnIssueSubtitle => 'Åpne problemsporingen på GitHub';

  @override
  String get settingsJoinDiscord => 'Bli med i Discord';

  @override
  String get settingsJoinDiscordSubtitle => 'Chat med fellesskapet';

  @override
  String get settingsJoinTheDiscord => 'Bli med i Discord';

  @override
  String get settingsSupportMoonfin => 'Støtt Tortugarr';

  @override
  String get settingsSupportMoonfinSubtitle => 'Spander en kaffe på utvikleren';

  @override
  String get settingsLegal => 'LOVLIG';

  @override
  String get settingsLicenses => 'Lisenser';

  @override
  String get settingsOpenSourceLicenseNotices =>
      'Lisensmerknader for åpen kildekode';

  @override
  String get settingsPrivacyPolicy => 'Personvernerklæring';

  @override
  String get settingsPrivacyPolicySubtitle =>
      'Hvordan Tortugarr håndterer dataene dine';

  @override
  String get settingsCheckForUpdates => 'Se etter oppdateringer';

  @override
  String get settingsCheckForUpdatesSubtitle =>
      'Se etter den siste Tortugarr-utgivelsen';

  @override
  String get settingsBoth => 'Både';

  @override
  String get settingsShuffleContentTypeFilter => 'Bland innholdstypefilter';

  @override
  String get settingsAudioPreferencesSubtitle =>
      'Alternativer for lydspor, prosessering og passthrough';

  @override
  String get settingsAutomationAndQueueSubtitle =>
      'Automatisert avspilling og sekvensering';

  @override
  String get settingsSyncplaySubtitle =>
      'Synkroniseringslogikk for gruppeøkter';

  @override
  String get settingsSkipIntrosAndOutros =>
      'Vil du hoppe over introer og outroer?';

  @override
  String settingsMediaSegmentTypeAction(String segment) {
    return '$segment-segmenter';
  }

  @override
  String get settingsMediaSegmentCountdown => 'Nedtelling for mediesegment';

  @override
  String get settingsProgressBar => 'Fremdriftslinje';

  @override
  String get settingsTimer => 'Tidtaker';

  @override
  String get settingsNone => 'Ingen';

  @override
  String get settingsSkipButtonAutoHide => 'Skjul Hopp over-knappen automatisk';

  @override
  String get settingsSkipButtonAutoHideDescription =>
      'Skjul knappen for å hoppe over intro og rulletekst automatisk etter noen sekunder.';

  @override
  String get settingsPromptUser => 'Spør bruker';

  @override
  String get settingsSkip => 'Hopp over';

  @override
  String get settingsDoNothing => 'Gjør ingenting';

  @override
  String get settingsMaxBitrateDescription =>
      'Sett tak for strømmingsbithastigheten. Innhold over denne terskelen vil bli omkodet for å passe.';

  @override
  String get settingsMaxResolutionDescription =>
      'Begrens den maksimale oppløsningen spilleren vil be om. Innhold med høyere oppløsning vil bli omkodet ned.';

  @override
  String get settingsPlayerZoomDescription =>
      'Hvordan video skal skaleres for å passe til skjermen.';

  @override
  String get settingsPlaybackEngineAndroidTv => 'Avspillingsmotor (Android TV)';

  @override
  String get settingsPlaybackEngineAndroidTvDescription =>
      'Brukes når Automatisk avspiller er av. Media3 er standard; prøv mpv hvis en film hakker eller lyden faller ut. Gjelder fra neste film.';

  @override
  String get settingsPlaybackEngineMedia3Recommended => 'Media3 (anbefalt)';

  @override
  String get settingsPlaybackEngineMpvLegacy => 'mpv';

  @override
  String get settingsMpvOnBluetooth => 'Bruk mpv med Bluetooth-lyd';

  @override
  String get settingsMpvOnBluetoothDescription =>
      'Spiller av med mpv når lyden går til Bluetooth-hodetelefoner eller en høyttaler. Media3 kan hakke og hoppe med Bluetooth på noen TV-er.';

  @override
  String get settingsRedetectDisplay => 'Finn skjermen på nytt';

  @override
  String get settingsRedetectDisplayDescription =>
      'Spør TV-en på nytt hvilke HDR-formater den støtter. Bruk dette hvis Dolby Vision- eller HDR10-titler omkodes etter at TV-en eller forsterkeren ble slått på sent.';

  @override
  String get settingsDisplayIsSdr => 'TV-en min har ikke HDR';

  @override
  String get settingsDisplayIsSdrDescription =>
      'Slutt å oppgi HDR-støtte for denne skjermen. Bruk dette bare hvis gjenkjenningen fortsetter å melde HDR som TV-en egentlig ikke kan vise.';

  @override
  String settingsDisplayRedetected(String formats) {
    return 'Skjermen er funnet på nytt: $formats';
  }

  @override
  String get settingsDisplayNoHdrDetected => 'Fant ingen HDR-formater';

  @override
  String get settingsDisplayMarkedSdr => 'Skjermen er lagret som SDR';

  @override
  String get settingsDolbyVisionFallback => 'Reserve for Dolby Vision';

  @override
  String get settingsDolbyVisionFallbackDescription =>
      'Atferd for Dolby Vision-titler på enheter uten Dolby Vision-dekoding.';

  @override
  String get settingsAskEachTime => 'Spør hver gang';

  @override
  String get settingsPreferHdr10Fallback => 'Foretrekker HDR10 reserve';

  @override
  String get settingsPreferServerTranscode => 'Foretrekk servertranscode';

  @override
  String get settingsDolbyVisionProfile7DirectPlay =>
      'Direkteavspilling av Dolby Vision Profil 7';

  @override
  String get settingsDolbyVisionProfile7DirectPlayDescription =>
      'Styrer om Dolby Vision-profil 7-strømmer med forbedringslag skal styre avspilling.';

  @override
  String get settingsAutoAftkrtEnabled => 'Auto (AFTKRT aktivert)';

  @override
  String get settingsEnabledOnThisDevice => 'Aktivert på denne enheten';

  @override
  String get settingsDisabledPreferTranscode =>
      'Deaktivert (foretrekker omkode)';

  @override
  String get settingsResumeRewindDescription =>
      'Når du fortsetter avspillingen (fra Fortsett å se eller en side med medieelementer), hvor mange sekunder skal du spole tilbake?';

  @override
  String get settingsUnpauseRewindDescription =>
      'Når du fortsetter avspillingen etter å ha trykket på pauseknappen, hvor mange sekunder skal du spole tilbake?';

  @override
  String get settingsSkipBackLengthDescription =>
      'Hvor mange sekunder å hoppe tilbake etter å ha trykket på tilbakespolingsknappen.';

  @override
  String get settingsOneSecond => '1 sekund';

  @override
  String get settingsThreeSeconds => '3 sekunder';

  @override
  String get settingsFortyFiveSeconds => '45 sekunder';

  @override
  String get settingsSixtySeconds => '60 sekunder';

  @override
  String get settingsSkipForwardLengthDescription =>
      'Hvor mange sekunder å hoppe fremover etter å ha trykket på spole fremover-knappen.';

  @override
  String get settingsBitstreamAc3ToExternalDecoder =>
      'Bitstream AC3 til ekstern dekoder';

  @override
  String get settingsCinemaMode => 'Kinomodus';

  @override
  String get settingsCinemaModeSubtitle =>
      'Spill trailere/prerolls før en hovedfunksjon';

  @override
  String get settingsCinemaModeEpisodes => 'Kinomodus for episoder';

  @override
  String get settingsCinemaModeEpisodesSubtitle =>
      'Spill også forfilmer før TV-episoder';

  @override
  String get settingsNextUpDisplayDescription =>
      'Utvidet viser et fullstendig kort med episodegrafikk og beskrivelse. Minimal viser et kompakt nedtellingsoverlegg. Deaktivert skjuler ledeteksten helt.';

  @override
  String get settingsShort => 'Kort';

  @override
  String get settingsLong => 'Lang';

  @override
  String get settingsVeryLong => 'Veldig lang';

  @override
  String get settingsVideoStartDelay => 'Videostartforsinkelse';

  @override
  String settingsMillisecondsValue(int value) {
    return '$value ms';
  }

  @override
  String get settingsLiveTvDirect => 'Direkte TV direkte';

  @override
  String get settingsLiveTvDirectSubtitle =>
      'Aktiver direkteavspilling for direktesendt TV';

  @override
  String get settingsOpenGroups => 'Åpne grupper';

  @override
  String get settingsOpenGroupsSubtitle =>
      'Opprett, bli med i eller administrer SyncPlay-grupper';

  @override
  String get settingsSyncplayEnabled => 'SyncPlay aktivert';

  @override
  String get settingsSyncplayEnabledSubtitle =>
      'Aktiver gruppevisningsfunksjoner';

  @override
  String get settingsSyncplayButton => 'SyncPlay-knapp';

  @override
  String get settingsSyncplayButtonSubtitle =>
      'Vis SyncPlay-knappen på navigasjonslinjen';

  @override
  String get settingsSyncplayAdvancedCorrection => 'Avansert korrigering';

  @override
  String get settingsSyncplayAdvancedCorrectionSubtitle =>
      'Aktiver finkornet synkroniseringslogikk';

  @override
  String get settingsSyncplaySyncCorrection => 'Synkroniseringskorreksjon';

  @override
  String get settingsSyncplaySyncCorrectionSubtitle =>
      'Juster avspillingen automatisk for å forbli synkronisert';

  @override
  String get settingsSyncplaySpeedToSync => 'Hastighet til synkronisering';

  @override
  String get settingsSyncplaySpeedToSyncSubtitle =>
      'Bruk avspillingshastighetsjustering for å synkronisere';

  @override
  String get settingsSyncplaySkipToSync => 'Hopp til synkronisering';

  @override
  String get settingsSyncplaySkipToSyncSubtitle =>
      'Bruk søker for å synkronisere';

  @override
  String get settingsSyncplayMinimumSpeedDelay =>
      'Minimum hastighetsforsinkelse';

  @override
  String get settingsSyncplayMaximumSpeedDelay =>
      'Maksimal hastighetsforsinkelse';

  @override
  String get settingsSyncplaySpeedDuration => 'Hastighet Varighet';

  @override
  String get settingsSyncplayMinimumSkipDelay => 'Minimum hoppforsinkelse';

  @override
  String get settingsSyncplayExtraOffset => 'SyncPlay Ekstra forskyvning';

  @override
  String get onNow => 'På nå';

  @override
  String get collections => 'Samlinger';

  @override
  String get lastPlayed => 'Sist spilt';

  @override
  String libraryNameWithServer(String libraryName, String serverName) {
    return '$libraryName ($serverName)';
  }

  @override
  String latestLibraryName(String libraryName) {
    return 'Nylig lagt til i $libraryName';
  }

  @override
  String recentlyReleasedLibraryName(String libraryName) {
    return 'Nylig utgitt i $libraryName';
  }

  @override
  String get autoplayNextEpisode => 'Spill av neste episode automatisk';

  @override
  String get autoplayNextEpisodeSubtitle =>
      'Spill av neste episode automatisk når den er tilgjengelig.';

  @override
  String get skipSilenceTitle => 'Hopp over stillhet';

  @override
  String get skipSilenceSubtitle =>
      'Hopp automatisk over stille lydsegmenter når strømmen støtter det.';

  @override
  String get allowExternalAudioEffectsTitle => 'Tillat eksterne lydeffekter';

  @override
  String get allowExternalAudioEffectsSubtitle =>
      'La equalizer- og effektapper (f.eks. Wavelet) koble seg til Media3-avspillingsøkter.';

  @override
  String get disableTunnelingTitle => 'Deaktiver tunnelering';

  @override
  String get disableTunnelingSubtitle =>
      'Tving avspilling uten tunnelering. Nyttig på enheter med lyd-/videobrudd ved tunnelering.';

  @override
  String get enableTunnelingTitle => 'Tunneling';

  @override
  String get enableTunnelingSubtitle =>
      'Prøv dette hvis 4K-filmer hakker. Bilde og lyd går rett til TV-ens videobrikke. Noen TV-er mister lyden med dette på.';

  @override
  String get mapDolbyVisionP7Title =>
      'Spill alltid Dolby Vision profil 7 som HDR10';

  @override
  String get mapDolbyVisionP7Subtitle =>
      'Hopper over omgjøringen til profil 8. Bruk dette hvis omgjorte filmer ser feil ut.';

  @override
  String get subtitlesUseEmbeddedStyles => 'Bruk innebygde undertekststiler';

  @override
  String get subtitlesUseEmbeddedStylesSubtitle =>
      'Bruk farger, skrifter og plassering som er innebygd i undertekstsporet. Deaktiver for å bruke dine egne stilinnstillinger i stedet.';

  @override
  String get subtitlesUseEmbeddedFontSizes =>
      'Bruk innebygde skriftstørrelser for undertekster';

  @override
  String get subtitlesUseEmbeddedFontSizesSubtitle =>
      'Bruk hint om skriftstørrelse som er innebygd i undertekstsporet. Deaktiver for å bruke undertekststørrelsen fra stilinnstillingene dine.';

  @override
  String get showMediaDetailsOnLibraryPage => 'Vis mediedetaljer';

  @override
  String get showMediaDetailsOnLibraryPageDescription =>
      'Vis detaljer om det valgte elementet øverst på bibliotekssidene.';

  @override
  String get hideBackdropsInLibraries => 'Skjul bakgrunnsbilder mens du blar?';

  @override
  String get useDetailedSubHeadings => 'Bruk detaljerte underoverskrifter';

  @override
  String get useDetailedSubHeadingsDescription =>
      'Vis en detaljert eller minimal underrad på bibliotekssidene.';

  @override
  String get savedThemesDeleteDialogTitle =>
      'Vil du slette det lagrede temaet?';

  @override
  String savedThemesDeleteDialogMessage(String themeName) {
    return 'Vil du fjerne «$themeName» fra bufferen på denne enheten?';
  }

  @override
  String get themeStore => 'Temabutikk';

  @override
  String get themeStoreSubtitle =>
      'Bla gjennom og lagre temaer fra fellesskapet';

  @override
  String get themeStoreDescription =>
      'Lagre et tema for å bruke det som de andre lagrede temaene dine.';

  @override
  String get themeStoreEmpty => 'Ingen temaer er tilgjengelige akkurat nå.';

  @override
  String get themeStoreLoadFailed =>
      'Kunne ikke laste inn Temabutikken. Sjekk tilkoblingen og prøv igjen.';

  @override
  String get themeStoreSave => 'Lagre';

  @override
  String get themeStoreSaveAndApply => 'Lagre og bruk';

  @override
  String get themeStoreSaved => 'Lagret';

  @override
  String get themeStoreInvalidMessage => 'Dette temaet kunne ikke lastes inn.';

  @override
  String themeStoreSavedMessage(String themeName) {
    return 'Lagret «$themeName».';
  }

  @override
  String savedThemesDeletedMessage(String themeName) {
    return 'Slettet «$themeName» fra denne enheten.';
  }

  @override
  String savedThemesDeleteFailedMessage(String themeName) {
    return 'Kunne ikke slette «$themeName».';
  }

  @override
  String get savedThemesTitle => 'Lagrede temaer';

  @override
  String get savedThemesDescription =>
      'Dette er temaer som er lastet ned fra Tortugarr-tillegget for den gjeldende serveren. Sletting fjerner bare denne lokale kopien.';

  @override
  String get savedThemesEmpty =>
      'Fant ingen lagrede temaer for denne serveren.';

  @override
  String savedThemesCurrentThemeId(String themeId) {
    return '$themeId • Aktiv nå';
  }

  @override
  String get savedThemesDeleteTooltip => 'Slett lagret tema';

  @override
  String get savedThemesManageSubtitle =>
      'Administrer nedlastede tilleggstemaer på denne enheten';

  @override
  String get themeEditor => 'Temaredigering';

  @override
  String get themeEditorSubtitle =>
      'Åpne temaredigering for Tortugarr i nettleseren';

  @override
  String get homeScreen => 'Startskjerm';

  @override
  String get bottomBar => 'Bunnlinje';

  @override
  String get homeRowsStyleClassic => 'Klassisk';

  @override
  String get homeRowsStyleModern => 'Moderne';

  @override
  String get homeRowsSection => 'Hjem-rader';

  @override
  String get rowsType => 'Rows Type';

  @override
  String get rowsTypeDescription =>
      'Klassisk beholder bildetype og infooverlegg per rad. Moderne bruker rader fra portrett til bakgrunnsbilde.';

  @override
  String get modernCardsOnMyMediaRow => 'Moderne kort på Mine medier-raden';

  @override
  String get modernCardsOnMyMediaRowDescription =>
      'Vis tilpassbare plakater som utvides ved fokus. Slå av for å alltid vise liggende miniatyrbilde.';

  @override
  String get sortOrder => 'Sorteringsrekkefølge';

  @override
  String get ascending => 'Stigende';

  @override
  String get descending => 'Synkende';

  @override
  String get displayFavoritesRows => 'Vis favorittrader';

  @override
  String get displayFavoritesRowsSubtitle =>
      'Vis rader med favorittfilmer, -serier og andre favoritter i Hjem-seksjonene.';

  @override
  String get favoritesRowSorting => 'Sortering av favorittrader';

  @override
  String get favoritesRowSortingDescription =>
      'Sorter favorittrader etter lagt til-dato, utgivelsesdato, alfabetisk og mer.';

  @override
  String get favoritesRowSortOrderDescription =>
      'Sorter Favoritter-radene stigende eller synkende.';

  @override
  String get displayCollectionsRows => 'Vis samlingsrader';

  @override
  String get displayCollectionsRowsSubtitle =>
      'Vis samlingsrader i Hjem-seksjonene.';

  @override
  String get collectionsRowSorting => 'Sortering av samlingsrader';

  @override
  String get collectionsRowSortingDescription =>
      'Sorter samlingsrader etter lagt til-dato, utgivelsesdato, alfabetisk og mer.';

  @override
  String get collectionsRowSortOrderDescription =>
      'Sorter Samlinger-radene stigende eller synkende.';

  @override
  String get collectionsRowShowEpisodes => 'Vis enkeltepisoder';

  @override
  String get collectionsRowShowEpisodesSubtitle =>
      'Utvid TV-serier så hver episode vises for seg.';

  @override
  String get displayGenresRows => 'Vis sjangerrader';

  @override
  String get displayGenresRowsSubtitle => 'Vis sjangerrader i Hjem-seksjonene.';

  @override
  String get genresRowSorting => 'Sortering av sjangerrader';

  @override
  String get genresRowSortingDescription =>
      'Sorter sjangerrader etter lagt til-dato, utgivelsesdato, alfabetisk og mer.';

  @override
  String get genresRowSortOrderDescription =>
      'Sorter Sjangre-radene stigende eller synkende.';

  @override
  String get genresRowItems => 'Elementer i sjangerrader';

  @override
  String get genresRowItemsDescription =>
      'Vis filmer, serier eller begge deler i sjangerrader.';

  @override
  String get displayStudiosRows => 'Vis studio-rad';

  @override
  String get displayStudiosRowsSubtitle => 'Vis studio-raden på startskjermen.';

  @override
  String get studiosRowSorting => 'Sortering av studio-rad';

  @override
  String get studiosRowSortingDescription =>
      'Studio-rad etter navn, nylig lagt til med mer.';

  @override
  String get studiosRowSortOrderDescription =>
      'Velg stigende eller synkende rekkefølge.';

  @override
  String get selectStudiosToInclude => 'Velg studioer som skal tas med';

  @override
  String get selectStudiosToIncludeDescription =>
      'Velg hvilke studioer som skal vises på startskjerm-raden.';

  @override
  String get selectAllStudios => 'Velg alle';

  @override
  String get deselectAllStudios => 'Fjern alle';

  @override
  String get tvStudiosFilter => 'TV-studioer';

  @override
  String get movieStudiosFilter => 'Filmstudioer';

  @override
  String get selectedStudiosFilter => 'Valgte studioer';

  @override
  String get unselectedStudiosFilter => 'Ikke valgte studioer';

  @override
  String get filtersHeader => 'Filtre';

  @override
  String get showHeader => 'Vis';

  @override
  String get displayPlaylistsRows => 'Vis spillelisterader';

  @override
  String get displayPlaylistsRowsSubtitle =>
      'Vis spillelisterader i Hjem-seksjonene.';

  @override
  String get playlistsRowSorting => 'Sortering av spillelisterader';

  @override
  String get playlistsRowSortingDescription =>
      'Sorter spillelisterader etter lagt til-dato, utgivelsesdato, alfabetisk og mer.';

  @override
  String get playlistsRowSortOrderDescription =>
      'Sorter Spilleliste-radene stigende eller synkende.';

  @override
  String get playlistsRowShowEpisodes => 'Vis enkeltepisoder';

  @override
  String get playlistsRowShowEpisodesSubtitle =>
      'Utvid TV-serier så hver episode vises for seg.';

  @override
  String get displayAudioRows => 'Vis lydrader';

  @override
  String get displayAudioRowsSubtitle => 'Vis lydrader i Hjem-seksjonene.';

  @override
  String get audioRowsSorting => 'Sortering av lydrader';

  @override
  String get audioRowsSortingDescription =>
      'Sorter lydrader etter lagt til-dato, utgivelsesdato, alfabetisk og mer.';

  @override
  String get audioRowsSortOrderDescription =>
      'Sorter Lyd-radene stigende eller synkende.';

  @override
  String get audioPlaylists => 'Lydspillelister';

  @override
  String get appearance => 'Utseende';

  @override
  String get layout => 'Oppsett';

  @override
  String get theme => 'Tema';

  @override
  String get keyboard => 'Tastatur';

  @override
  String get navButtons => 'Knapper';

  @override
  String get rendering => 'Gjengivelse';

  @override
  String get mpvConfiguration => 'MPV-konfigurasjon';

  @override
  String get cardSize => 'Kortstørrelse';

  @override
  String get externalPlayerApp => 'Ekstern spillerapp';

  @override
  String get externalPlayerAppDescription =>
      'Angi en ekstern spiller for å aktivere avspilling ved langt trykk';

  @override
  String get externalPlayerAskEachTimeSubtitle =>
      'Vis appvelgeren når avspillingen starter.';

  @override
  String get loadingInstalledPlayers => 'Laster inn installerte spillere...';

  @override
  String get connection => 'Tilkobling';

  @override
  String get locallyDecodedCodecs => 'Lokalt dekodede kodeker';

  @override
  String get transcodeTargetCodecs => 'Målkodeker for omkoding';

  @override
  String get passthrough => 'Passthrough';

  @override
  String get supportedOnThisDevice => 'Støttes på denne enheten';

  @override
  String get notSupportedOnThisDevice => 'Støttes ikke på denne enheten';

  @override
  String get mediaPlayerBehavior => 'Virkemåte for mediespiller';

  @override
  String get playbackEnhancements => 'Avspillingsforbedringer';

  @override
  String get alwaysOn => 'Alltid på.';

  @override
  String get replaceSkipOutroWithNextUpDisplay =>
      'Erstatt Hopp over outro med Neste opp-visning';

  @override
  String get replaceSkipOutroWithNextUpDisplaySubtitle =>
      'Vis Neste opp-overlegget i stedet for Hopp over outro-knappen.';

  @override
  String get playerRouting => 'Spillerruting';

  @override
  String get preferSoftwareDecoders => 'Foretrekk programvaredekodere';

  @override
  String get preferSoftwareDecodersSubtitle =>
      'Pakker ut lyd og AV1-video i appen i stedet for i videobrikken. Slå av hvis Dolby eller DTS til forsterkeren slutter å virke.';

  @override
  String get useExternalPlayer => 'Use external player';

  @override
  String get useExternalPlayerSubtitle =>
      'Åpne videoavspilling i den valgte eksterne appen på Android TV.';

  @override
  String get automaticQueuing => 'Automatisk køing';

  @override
  String get preferSdhSubtitles => 'Foretrekk SDH-undertekster';

  @override
  String get preferSdhSubtitlesSubtitle =>
      'Prioriter SDH-/CC-undertekstspor ved automatisk valg.';

  @override
  String get preferTextSubtitles => 'Foretrekk tekstbaserte undertekster';

  @override
  String get preferTextSubtitlesSubtitle =>
      'Prioriter tekstbaserte undertekster (SRT, VTT) foran bildebaserte formater (PGS, VobSub).';

  @override
  String get preferExternalSubtitles => 'Foretrekk eksterne undertekster';

  @override
  String get preferExternalSubtitlesSubtitle =>
      'Prioriter eksterne undertekstfiler foran innebygde spor.';

  @override
  String get webDiagnostics => 'Nettdiagnostikk';

  @override
  String get webDiagnosticsTitle => 'Tortugarr nettdiagnostikk';

  @override
  String get webDiagnosticsIntro =>
      'Bruk denne siden til å diagnostisere tilkoblingsproblemer i nettleseren (CORS, blandet innhold og oppdagelsesinnstillinger).';

  @override
  String get webDiagnosticsDetectedMixedContentFailure =>
      'Oppdaget feil med blandet innhold';

  @override
  String get webDiagnosticsDetectedCorsPreflightFailure =>
      'Oppdaget CORS-/preflight-feil';

  @override
  String get webDiagnosticsMixedContentFailureBody =>
      'Tortugarr oppdaget en HTTPS-side som prøver å kalle en HTTP-server-URL. Nettlesere blokkerer denne forespørselen før den når serveren din.';

  @override
  String get webDiagnosticsCorsFailureBody =>
      'Tortugarr oppdaget en forespørselsfeil på nettlesernivå som vanligvis skyldes manglende CORS- eller preflight-hoder på medieserveren.';

  @override
  String webDiagnosticsTargetUrl(String url) {
    return 'Mål-URL: $url';
  }

  @override
  String webDiagnosticsDetail(String detail) {
    return 'Detalj: $detail';
  }

  @override
  String get webDiagnosticsCurrentRuntimeContext =>
      'Gjeldende kjøretidskontekst';

  @override
  String get webDiagnosticsOrigin => 'Opprinnelse';

  @override
  String get webDiagnosticsScheme => 'Protokoll';

  @override
  String get webDiagnosticsPluginMode => 'Tilleggsmodus';

  @override
  String get webDiagnosticsWebRtcScan => 'WebRTC-skanning';

  @override
  String get webDiagnosticsForcedServerUrl => 'Tvunget server-URL';

  @override
  String get webDiagnosticsDefaultServerUrl => 'Standard server-URL';

  @override
  String get webDiagnosticsDiscoveryProxyUrl => 'URL for oppdagelsesproxy';

  @override
  String get notConfigured => 'ikke konfigurert';

  @override
  String get webDiagnosticsMixedContent => 'Blandet innhold';

  @override
  String get webDiagnosticsMixedContentDetected =>
      'Denne siden lastes over HTTPS, men én eller flere konfigurerte URL-er bruker HTTP. Nettlesere blokkerer HTTPS-sider fra å kalle HTTP-API-er.';

  @override
  String get webDiagnosticsMixedContentFix =>
      'Løsning: server medieserveren eller proxy-endepunktet via HTTPS, eller last Tortugarr over HTTP bare på klarerte lokale nettverk.';

  @override
  String get webDiagnosticsNoMixedContentDetected =>
      'Ingen åpenbar konfigurasjon med blandet innhold ble oppdaget ut fra gjeldende kjøretidsinnstillinger.';

  @override
  String get webDiagnosticsCorsChecklist => 'CORS-sjekkliste';

  @override
  String get webDiagnosticsCorsChecklistItem1 =>
      '• Tillat nettleserens origin i Access-Control-Allow-Origin.';

  @override
  String get webDiagnosticsCorsChecklistItem2 =>
      '• Inkluder Authorization, X-Emby-Authorization og X-Emby-Token i Access-Control-Allow-Headers.';

  @override
  String get webDiagnosticsCorsChecklistItem3 =>
      '• Eksponer Content-Range og Accept-Ranges for strømming og spoling.';

  @override
  String get webDiagnosticsCorsChecklistItem4 =>
      '• Returner 204 på OPTIONS-preflight-forespørsler.';

  @override
  String get webDiagnosticsHeaderSnippetTitle =>
      'Eksempel på header-utdrag (nginx-stil)';

  @override
  String get note => 'Merk';

  @override
  String get webDiagnosticsNonWebNote =>
      'Denne diagnostikkruten er ment for nettbygg. Hvis du ser dette på en annen plattform, gjelder kanskje ikke disse kontrollene.';

  @override
  String get backToServerSelect => 'Tilbake til servervalg';

  @override
  String get signOutAllUsers => 'Logg av alle brukere';

  @override
  String get voiceSearchPermissionPermanentlyDenied =>
      'Mikrofontillatelsen er permanent avslått. Aktiver den i systeminnstillingene.';

  @override
  String get voiceSearchPermissionRequired =>
      'Mikrofontillatelse kreves for talesøk.';

  @override
  String get voiceSearchNoMatch => 'Fikk ikke med meg det. Prøv igjen.';

  @override
  String get voiceSearchNoSpeechDetected => 'Ingen tale ble oppdaget.';

  @override
  String get voiceSearchMicrophoneError => 'Mikrofonfeil.';

  @override
  String get voiceSearchNeedsInternet => 'Talesøk krever internett.';

  @override
  String get voiceSearchServiceBusy => 'Taletjenesten er opptatt. Prøv igjen.';

  @override
  String get microphonePermissionPermanentlyDenied =>
      'Mikrofontillatelsen er permanent avslått.';

  @override
  String get microphonePermissionDenied => 'Mikrofontillatelsen er avslått.';

  @override
  String get speechRecognitionUnavailable =>
      'Talegjenkjenning er ikke tilgjengelig på denne enheten.';

  @override
  String get openIosRoutePicker => 'Åpne iOS-rutevelgeren';

  @override
  String get airPlayRoutePickerUnavailable =>
      'AirPlay-rutevelgeren er ikke tilgjengelig på denne enheten.';

  @override
  String get videos => 'Videoer';

  @override
  String get programs => 'Programmer';

  @override
  String get songs => 'Sanger';

  @override
  String get photoAlbums => 'Fotoalbum';

  @override
  String get photos => 'Bilder';

  @override
  String get people => 'Personer';

  @override
  String get recentlyReleasedEpisodes => 'Nylig utgitte episoder';

  @override
  String get watchAgain => 'Se igjen';

  @override
  String get guestAppearances => 'Gjesteopptredener';

  @override
  String get appearancesSeerr => 'Opptredener (Seerr)';

  @override
  String get crewContributionsSeerr => 'Bidrag fra teamet (Seerr)';

  @override
  String get watchWithGroup => 'Se med gruppe';

  @override
  String get disk => 'Disk';

  @override
  String get openInBrowser => 'Åpne i nettleser';

  @override
  String get achievementBadges => 'Prestasjonsmerker';

  @override
  String get achievementBadgesSubtitle =>
      'Merker, rangeringer og oppdrag du får av det du ser på';

  @override
  String get achievementsBadges => 'Merker';

  @override
  String achievementsBadgeCount(int unlocked, int total) {
    return '$unlocked av $total merker';
  }

  @override
  String get achievementsUnlockToasts => 'Varsler ved opplåsing';

  @override
  String get achievementsUnlockToastsSubtitle =>
      'Vis et varsel når du låser opp et merke';

  @override
  String get achievementsUnlockedNotification => 'Prestasjon låst opp';

  @override
  String achievementsUnlockedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prestasjoner låst opp',
      one: '$count prestasjon låst opp',
    );
    return '$_temp0';
  }

  @override
  String achievementsUnlockedMore(int count) {
    return '+$count til';
  }

  @override
  String get achievementsQuests => 'Oppdrag';

  @override
  String achievementsQuestCount(int count) {
    return '$count fullført';
  }

  @override
  String get achievementsLeaderboard => 'Toppliste';

  @override
  String get achievementsLeaderboardSubtitle =>
      'Hvordan du ligger an mot andre brukere på serveren';

  @override
  String get achievementsRecap => 'Oppsummering';

  @override
  String get achievementsRecapSubtitle => 'Det du har sett nylig';

  @override
  String get achievementsLibraryCompletion => 'Fullført i biblioteket';

  @override
  String achievementsLibraryCount(int count) {
    return '$count biblioteker';
  }

  @override
  String achievementsScore(int score) {
    return '$score poeng';
  }

  @override
  String get achievementsScoreLabel => 'Poengsum';

  @override
  String get achievementsTopRank => 'Høyeste rang nådd';

  @override
  String achievementsPointsToNextRank(int points, String tier) {
    return '$points poeng til $tier';
  }

  @override
  String achievementsCurrentStreak(int days) {
    return '$days dager på rad';
  }

  @override
  String achievementsBestStreak(int days) {
    return 'Beste: $days dager';
  }

  @override
  String get achievementsShowcase => 'Utstilling';

  @override
  String get achievementsUnlocked => 'Låst opp';

  @override
  String get achievementsLocked => 'Låst';

  @override
  String get achievementsNothingHere => 'Ingenting her ennå.';

  @override
  String get achievementsHiddenBadge => 'Skjult prestasjon';

  @override
  String achievementsUnlockedOn(String date) {
    return 'Låst opp $date';
  }

  @override
  String achievementsPoints(int points) {
    return '$points p';
  }

  @override
  String get achievementsDailyQuests => 'Daglige';

  @override
  String get achievementsWeeklyQuests => 'Ukentlige';

  @override
  String achievementsQuestReward(int points) {
    return '+$points';
  }

  @override
  String get achievementsRerollDaily => 'Bytt daglige oppdrag';

  @override
  String get achievementsRerollWeekly => 'Bytt ukentlige oppdrag';

  @override
  String get achievementsRerollOffer => 'Bytt dette settet mot et annet';

  @override
  String get achievementsRerollSpentDaily =>
      'Brukt i dag, kommer tilbake ved midnatt UTC';

  @override
  String get achievementsRerollSpentWeekly =>
      'Brukt denne uken, kommer tilbake mandag UTC';

  @override
  String get achievementsRerollConfirm => 'Bytte disse oppdragene?';

  @override
  String get achievementsRerollConfirmBody =>
      'Du får ett daglig og ett ukentlig bytte, og dette bruker det opp.';

  @override
  String get achievementsRerollFailed => 'Kunne ikke bytte oppdragene.';

  @override
  String get achievementsSuggested => 'Forslag til hva du kan se';

  @override
  String get achievementsNoSuggestions => 'Ingen forslag for dette merket.';

  @override
  String get achievementsProgressLabel => 'Fremdrift';

  @override
  String get achievementsLoadout => 'Utrustning';

  @override
  String get achievementsLoadoutSubtitle => 'Poeng å bruke og boostene du har';

  @override
  String get achievementsAppearance => 'Utseende';

  @override
  String get achievementsAppearanceSubtitle =>
      'Avataren og tittelen på profilen din';

  @override
  String get achievementsAvatars => 'Avatarer';

  @override
  String get achievementsTitles => 'Titler';

  @override
  String get achievementsEquipped => 'I bruk';

  @override
  String get achievementsOwned => 'Eid';

  @override
  String achievementsEarnedAt(int score) {
    return 'Oppnås ved $score poeng totalt';
  }

  @override
  String get achievementsAppearanceEmpty =>
      'Denne serveren har ingen avatarer eller titler å bruke.';

  @override
  String get achievementsAppearanceFailed =>
      'Kunne ikke endre hvordan profilen ser ut.';

  @override
  String get achievementsPowerUps => 'Power-ups';

  @override
  String get achievementsStats => 'Statistikk';

  @override
  String get achievementsStatsSubtitle =>
      'Rekordene dine og hvordan serveren gjør det';

  @override
  String get achievementsStatsWatched => 'Sett';

  @override
  String get achievementsStatsBests => 'Rekorder';

  @override
  String get achievementsStatsHabits => 'Vaner';

  @override
  String get achievementsStatsVariety => 'Variasjon';

  @override
  String get achievementsStatsServer => 'Denne serveren';

  @override
  String get achievementsStatsClock => 'Når du ser på';

  @override
  String get achievementsStatItems => 'Elementer sett';

  @override
  String get achievementsStatMovies => 'Filmer sett';

  @override
  String get achievementsStatSeries => 'Serier fullført';

  @override
  String get achievementsStatHours => 'Timer sett';

  @override
  String get achievementsStatDays => 'Dager med seing';

  @override
  String get achievementsStatRewatches => 'Gjensyn';

  @override
  String get achievementsStatBestWatchStreak => 'Lengste seerrekke';

  @override
  String get achievementsStatBestLoginStreak => 'Lengste påloggingsrekke';

  @override
  String get achievementsStatMostEpisodes => 'Flest episoder på én dag';

  @override
  String get achievementsStatMostMovies => 'Flest filmer på én dag';

  @override
  String get achievementsStatLongestItem => 'Lengste enkeltelement';

  @override
  String get achievementsStatBestCombo => 'Beste kombo';

  @override
  String get achievementsStatLateNight => 'Sene kvelder';

  @override
  String get achievementsStatEarlyMorning => 'Tidlige morgener';

  @override
  String get achievementsStatWeekend => 'Helgeøkter';

  @override
  String get achievementsStatDaysSignedIn => 'Dager pålogget';

  @override
  String get achievementsStatLibraries => 'Biblioteker besøkt';

  @override
  String get achievementsStatGenres => 'Sjangre sett';

  @override
  String get achievementsStatDecades => 'Tiår sett';

  @override
  String get achievementsStatCountries => 'Land sett';

  @override
  String get achievementsStatLanguages => 'Språk sett';

  @override
  String get achievementsStatUsers => 'Brukere';

  @override
  String get achievementsStatBadgesUnlocked => 'Merker låst opp';

  @override
  String get achievementsStatScoreEarned => 'Poeng opptjent';

  @override
  String get achievementsStatCommonBadge => 'Vanligste merke';

  @override
  String get achievementsActivity => 'Aktivitet';

  @override
  String get achievementsActivitySubtitle =>
      'Hva serveren har låst opp i det siste';

  @override
  String achievementsActivityUnlocked(String user, String badge) {
    return '$user låste opp $badge';
  }

  @override
  String get achievementsShop => 'Butikk';

  @override
  String get achievementsShopSubtitle => 'Bruk poeng på flere boost';

  @override
  String achievementsShopPack(String name, int count) {
    return '$name ×$count';
  }

  @override
  String get achievementsShopEmpty => 'Ingenting til salgs akkurat nå.';

  @override
  String get achievementsBuyConfirm => 'Kjøpe dette?';

  @override
  String get achievementsBuyConfirmBody =>
      'Det trekkes rett fra poengbanken din.';

  @override
  String get achievementsBuyFailed => 'Kunne ikke kjøpe det.';

  @override
  String get achievementsScoreBank => 'Poengbank';

  @override
  String get achievementsBoost => 'XP-boost';

  @override
  String get achievementsBoostBody =>
      'Dobler poengene i en time. Bruker du den igjen, starter timen på nytt.';

  @override
  String get achievementsDoubleCredit => 'Dobbel uttelling';

  @override
  String get achievementsDoubleCreditBody =>
      'Det neste du fullfører teller dobbelt mot merker.';

  @override
  String get achievementsStreakFreeze => 'Rekkefrys';

  @override
  String get achievementsStreakFreezeBody =>
      'Dekker én tapt dag. Du kan bare ha én på lager.';

  @override
  String achievementsPowerUpHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count på lager',
      one: '1 på lager',
      zero: 'Ingen på lager',
    );
    return '$_temp0';
  }

  @override
  String get achievementsPowerUpActive => 'Aktiv nå';

  @override
  String get achievementsUsePowerUp => 'Bruke denne power-upen?';

  @override
  String get achievementsUsePowerUpBody =>
      'Den brukes opp så snart du bekrefter.';

  @override
  String get achievementsPowerUpFailed => 'Kunne ikke bruke den power-upen.';

  @override
  String get achievementsHours => 'Timer';

  @override
  String get achievementsStreak => 'Rekke';

  @override
  String get achievementsPeriodWeek => 'Uke';

  @override
  String get achievementsPeriodMonth => 'Måned';

  @override
  String get achievementsPeriodYear => 'År';

  @override
  String achievementsDaysWatched(int count) {
    return '$count dager med seing';
  }

  @override
  String achievementsBadgesEarned(int count) {
    return '$count merker opptjent';
  }

  @override
  String get achievementsTopDirectors => 'Mest sette regissører';

  @override
  String get achievementsTopActors => 'Mest sette skuespillere';

  @override
  String get achievementsLoadFailed => 'Kunne ikke laste prestasjonene dine.';

  @override
  String get friends => 'Venner';

  @override
  String get friendsSubtitle =>
      'Se hvem som er pålogget, og chat med folk på denne serveren';

  @override
  String get friendsShowButton => 'Vis Venner-knappen';

  @override
  String get friendsShowButtonSubtitle =>
      'Venner og chat fra Achievement Badges-tillegget';

  @override
  String get friendsMessages => 'Meldinger';

  @override
  String friendsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uleste meldinger',
      one: '1 ulest melding',
      zero: 'Ingen uleste meldinger',
    );
    return '$_temp0';
  }

  @override
  String get friendsRequests => 'Venneforespørsler';

  @override
  String friendsRequestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count venter på deg',
      one: '1 venter på deg',
      zero: 'Ingenting venter',
    );
    return '$_temp0';
  }

  @override
  String get friendsAdd => 'Legg til venner';

  @override
  String get friendsAddSubtitle => 'Finn folk på denne serveren';

  @override
  String get friendsPrivacy => 'Personvern';

  @override
  String get friendsPrivacySubtitle => 'Hva vennene dine kan se';

  @override
  String get friendsOnline => 'Pålogget';

  @override
  String get friendsOffline => 'Frakoblet';

  @override
  String get friendsNone =>
      'Ingen venner ennå. Legg til folk fra denne serveren for å se dem her.';

  @override
  String friendsWatching(String title) {
    return 'Ser på $title';
  }

  @override
  String friendsLastWatched(String title) {
    return 'Så sist $title';
  }

  @override
  String friendsLastSeen(String time) {
    return 'Sist sett $time';
  }

  @override
  String get friendsLoadFailed =>
      'Kunne ikke laste dette. Sjekk tilkoblingen og prøv igjen.';

  @override
  String get friendsActionFailed => 'Det gikk ikke. Prøv igjen om litt.';

  @override
  String get friendsIncoming => 'Venter på deg';

  @override
  String get friendsOutgoing => 'Sendt av deg';

  @override
  String get friendsNoRequests => 'Ingen venneforespørsler.';

  @override
  String get friendsAccept => 'Godta';

  @override
  String get friendsDecline => 'Avslå';

  @override
  String get friendsCancelRequest => 'Trekk tilbake forespørsel';

  @override
  String friendsRequestFrom(String name) {
    return '$name vil bli venner';
  }

  @override
  String friendsCancelRequestBody(String name) {
    return 'Trekke tilbake forespørselen du sendte til $name?';
  }

  @override
  String get friendsSearchHint => 'Søk etter folk';

  @override
  String get friendsNoMatches => 'Ingen har det navnet.';

  @override
  String friendsRequestSent(String name) {
    return 'Forespørsel sendt til $name';
  }

  @override
  String get friendsSendRequest => 'Legg til som venn';

  @override
  String get friendsSendMessage => 'Send melding';

  @override
  String friendsOpenItem(String title) {
    return 'Åpne $title';
  }

  @override
  String get friendsRemove => 'Fjern venn';

  @override
  String friendsRemoveBody(String name) {
    return 'Fjerne $name fra vennene dine? Du kan legge vedkommende til igjen senere.';
  }

  @override
  String get friendsBlock => 'Blokker';

  @override
  String get friendsUnblock => 'Opphev blokkering';

  @override
  String friendsBlockBody(String name) {
    return 'Blokkere $name? Ingen av dere kan sende direktemeldinger til den andre. Gruppechatter dere deler, forblir åpne.';
  }

  @override
  String friendsUnblockBody(String name) {
    return 'Oppheve blokkeringen av $name?';
  }

  @override
  String get friendsBlocked => 'Blokkerte brukere';

  @override
  String friendsProfileHidden(String name) {
    return '$name holder profilen sin privat.';
  }

  @override
  String get friendsAppearOffline => 'Vis meg som frakoblet';

  @override
  String get friendsAppearOfflineSubtitle =>
      'Venner ser deg alltid som frakoblet';

  @override
  String get friendsHideNowPlaying => 'Skjul hva jeg ser på';

  @override
  String get friendsHideNowPlayingSubtitle =>
      'Venner ser fortsatt at du er pålogget, men ikke hva som spilles';

  @override
  String get friendsHideLastWatched => 'Skjul det jeg så sist';

  @override
  String get friendsHideLastWatchedSubtitle =>
      'Venner ser ikke hva du så sist mens du er frakoblet';

  @override
  String get friendsMessageNotifications => 'Meldingsvarsler';

  @override
  String get friendsMessageNotificationsSubtitle =>
      'Vis et banner når en venn sender deg en melding';

  @override
  String get friendsMuteDuringPlayback => 'Demp under avspilling';

  @override
  String get friendsMuteDuringPlaybackSubtitle =>
      'Ingen meldingsbannere mens en video eller et spill kjører';

  @override
  String get friendsSaveFailed => 'Kunne ikke lagre innstillingene.';

  @override
  String get chatNew => 'Ny melding';

  @override
  String get chatNewSubtitle => 'Start en chat med en venn';

  @override
  String get chatNewGroup => 'Ny gruppe';

  @override
  String get chatNewGroupSubtitle => 'Chat med flere venner samtidig';

  @override
  String get chatNone => 'Ingen meldinger ennå.';

  @override
  String get chatYou => 'Du';

  @override
  String chatYouSaid(String text) {
    return 'Du: $text';
  }

  @override
  String get chatPhoto => 'Bilde';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String get chatEmojiSearch => 'Søk etter emoji';

  @override
  String get chatNoRecentEmoji => 'Ingen nylig brukte emoji';

  @override
  String get chatViewPhoto => 'Vis bilde';

  @override
  String get chatHint => 'Skriv en melding';

  @override
  String get chatAttach => 'Send et bilde';

  @override
  String get chatEdited => 'redigert';

  @override
  String get chatSeen => 'Sett';

  @override
  String get chatSent => 'Sendt';

  @override
  String get chatEditing => 'Redigerer melding';

  @override
  String get chatMessageOptions => 'Meldingsvalg';

  @override
  String get chatDeleteBody => 'Slette denne meldingen for alle?';

  @override
  String get chatClear => 'Tøm samtalen';

  @override
  String get chatClearBody =>
      'Slette alle meldinger i denne chatten for alle deltakerne?';

  @override
  String get chatGroupInfo => 'Gruppeinfo';

  @override
  String get chatGroupName => 'Gruppenavn';

  @override
  String chatMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmer',
      one: '1 medlem',
    );
    return '$_temp0';
  }

  @override
  String get chatOwner => 'Eier';

  @override
  String get chatAdmin => 'Administrator';

  @override
  String get chatMakeAdmin => 'Gjør til administrator';

  @override
  String get chatRemoveAdmin => 'Fjern som administrator';

  @override
  String get chatRemoveMember => 'Fjern fra gruppen';

  @override
  String get chatAddMember => 'Legg til folk';

  @override
  String get chatNobodyToAdd => 'Ingen flere å legge til.';

  @override
  String get chatLeave => 'Forlat gruppen';

  @override
  String get chatLeaveBody =>
      'Forlate denne gruppen? Noen må legge deg til igjen for at du skal bli med på nytt.';

  @override
  String get chatCreate => 'Opprett gruppe';

  @override
  String get chatPickMembers => 'Velg minst to venner';

  @override
  String chatNewMessageFrom(String name) {
    return 'Ny melding fra $name';
  }

  @override
  String get chatImageTooLarge => 'Bildet er over 8 MB.';

  @override
  String get chatImageUnsupported =>
      'Bare PNG-, JPEG-, GIF- og WebP-bilder kan sendes.';

  @override
  String get embeddedBrowserNotAvailable =>
      'Innebygd nettleser er ikke tilgjengelig på denne plattformen.';

  @override
  String get adminRestartServerConfirmation =>
      'Er du sikker på at du vil starte serveren på nytt?';

  @override
  String get adminShutdownServerConfirmation =>
      'Er du sikker på at du vil slå av serveren? Du må starte den manuelt igjen.';

  @override
  String get internal => 'Intern';

  @override
  String get idle => 'Inaktiv';

  @override
  String get os => 'OS';

  @override
  String get adminNoUsersFound => 'Fant ingen brukere';

  @override
  String get adminNoUsersMatchSearch => 'Ingen brukere samsvarer med søket';

  @override
  String get adminNoDevicesFound => 'Fant ingen enheter';

  @override
  String get adminNoDevicesMatchCurrentFilters =>
      'Ingen enheter samsvarer med gjeldende filtre';

  @override
  String get remoteAccess => 'Ekstern tilgang';

  @override
  String get localOnly => 'Kun lokalt';

  @override
  String get adminMediaAnalyticsLoadFailed =>
      'Kunne ikke laste inn medieanalysen';

  @override
  String get analyticsCombinedAcrossLibraries =>
      'Samlet analyse på tvers av alle mediebiblioteker.';

  @override
  String get analyticsTopArtists => 'Toppartister';

  @override
  String get analyticsTopAuthors => 'Toppforfattere';

  @override
  String get analyticsTopContributors => 'Toppbidragsytere';

  @override
  String analyticsLibrariesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count biblioteker',
      one: '1 bibliotek',
    );
    return '$_temp0';
  }

  @override
  String get analyticsNoIndexedMediaTotals =>
      'Ingen indekserte medietotaler er tilgjengelige for dette utvalget ennå.';

  @override
  String get analyticsLibraryDetails => 'Bibliotekdetaljer';

  @override
  String get analyticsLibraryBreakdown => 'Bibliotekfordeling';

  @override
  String get analyticsNoLibrariesAvailable =>
      'Ingen biblioteker er tilgjengelige.';

  @override
  String get analyticsLibraryShare => 'Andel elementer per bibliotek';

  @override
  String get analyticsTopRating => 'Vanligste aldersgrense';

  @override
  String get analyticsTypicalRuntime => 'Typisk spilletid';

  @override
  String analyticsShareOfItems(String percent) {
    return '$percent % av elementene';
  }

  @override
  String get adminServerAdministrationTitle => 'Serveradministrasjon';

  @override
  String get adminServerPathData => 'Data';

  @override
  String get adminServerPathImageCache => 'Bildebuffer';

  @override
  String get adminServerPathCache => 'Buffer';

  @override
  String get adminServerPathLogs => 'Logger';

  @override
  String get adminServerPathMetadata => 'Metadata';

  @override
  String get adminServerPathTranscode => 'Omkoding';

  @override
  String get adminServerPathWeb => 'Web';

  @override
  String get adminNoServerPathsReturned =>
      'Denne serveren returnerte ingen serverbaner.';

  @override
  String adminPercentUsed(int percent) {
    return '$percent % brukt';
  }

  @override
  String get userActivity => 'Brukeraktivitet';

  @override
  String get systemEvents => 'Systemhendelser';

  @override
  String get needsAttention => 'Krever oppmerksomhet';

  @override
  String get homeVideos => 'Hjemmevideoer';

  @override
  String get mixedContent => 'Blandet innhold';

  @override
  String get homeVideosAndPhotos => 'Hjemmevideoer og bilder';

  @override
  String get mixedMoviesAndShows => 'Blandede filmer og serier';

  @override
  String get dolbyVision => 'Dolby Vision';

  @override
  String get noRecordingsFound => 'Fant ingen opptak';

  @override
  String noImagePagesFoundInArchive(String extension) {
    return 'Fant ingen bildesider i .$extension-arkivet.';
  }

  @override
  String embeddedRendererFailed(int code, String description) {
    return 'Innebygd gjengiver mislyktes ($code): $description';
  }

  @override
  String epubRendererFailed(int code, String description) {
    return 'EPUB-gjengiver mislyktes ($code): $description';
  }

  @override
  String missingLocalFileForReader(String uri) {
    return 'Mangler lokal fil for leseren: $uri';
  }

  @override
  String httpStatusWhileOpeningBookData(int status, String uri) {
    return 'HTTP $status ved åpning av bokdata fra $uri';
  }

  @override
  String get noReadableBookEndpointAvailable =>
      'Ingen lesbart bokendepunkt er tilgjengelig';

  @override
  String unsupportedComicArchiveFormat(String extension) {
    return 'Tegneseriearkivformatet støttes ikke: .$extension';
  }

  @override
  String get cbrExtractionPluginUnavailable =>
      'Tillegget for CBR-utpakking er ikke tilgjengelig på denne plattformen.';

  @override
  String get failedToExtractCbrArchive => 'Kunne ikke pakke ut .cbr-arkivet.';

  @override
  String get cb7ExtractionUnavailable =>
      'CB7-utpakking er ikke tilgjengelig på denne plattformen.';

  @override
  String get cb7ExtractionPluginUnavailable =>
      'Tillegget for CB7-utpakking er ikke tilgjengelig på denne plattformen.';

  @override
  String get closeGenrePanel => 'Lukk sjangerpanelet';

  @override
  String get loadingShuffle => 'Laster inn tilfeldig rekkefølge...';

  @override
  String get libraryShuffleLabel => 'TILFELDIG FRA BIBLIOTEK';

  @override
  String get randomShuffleLabel => 'TILFELDIG UTVALG';

  @override
  String get genresShuffleLabel => 'TILFELDIG FRA SJANGRE';

  @override
  String get autoHdrSwitching => 'Automatisk HDR-bytte';

  @override
  String get autoHdrSwitchingDescription =>
      'Aktiver HDR automatisk ved avspilling av HDR-video, og gjenopprett visningsmodus ved avslutning.';

  @override
  String get whenFullscreen => 'Ved fullskjerm';

  @override
  String get changeArtwork => 'Endre bildemateriell';

  @override
  String get missing => 'Mangler';

  @override
  String get clearAllArtworkButton => 'Vil du fjerne alt bildemateriell?';

  @override
  String get clearAllArtworkWarning =>
      'Er du sikker på at du vil fjerne alt nedlastet bildemateriell?';

  @override
  String get confirmClear => 'Bekreft fjerning';

  @override
  String confirmClearMessage(String itemType) {
    return 'Er du sikker på at du vil fjerne følgende: $itemType?';
  }

  @override
  String get uploadButton => 'Vil du laste opp?';

  @override
  String get resolutionLabel => 'Oppløsning: ';

  @override
  String get onlyShowInterfaceLanguage =>
      'Vis bare bildemateriell på grensesnittspråket';

  @override
  String get confirmClearAll => 'Bekreft fjerning av alt';

  @override
  String get imageUploadSuccess => 'Bildet ble lastet opp!';

  @override
  String imageUploadFailed(String error) {
    return 'Kunne ikke laste opp bildet: $error';
  }

  @override
  String imageDownloadFailed(String error) {
    return 'Kunne ikke angi bildet: $error';
  }

  @override
  String imageDeleteFailed(String error) {
    return 'Kunne ikke slette bildet: $error';
  }

  @override
  String clearAllArtworkFailed(String error) {
    return 'Kunne ikke fjerne alt bildemateriell: $error';
  }

  @override
  String get yes => 'Ja';

  @override
  String get posterCategory => 'Plakat';

  @override
  String get backdropsCategory => 'Bakgrunnsbilder';

  @override
  String get bannerCategory => 'Banner';

  @override
  String get logoCategory => 'Logo';

  @override
  String get thumbnailCategory => 'Miniatyrbilde';

  @override
  String get artCategory => 'Grafikk';

  @override
  String get discArtCategory => 'Plategrafikk';

  @override
  String get screenshotCategory => 'Skjermbilde';

  @override
  String get boxCoverCategory => 'Boksomslag';

  @override
  String get boxRearCoverCategory => 'Boksomslag bak';

  @override
  String get menuArtCategory => 'Menygrafikk';

  @override
  String get confirmItemPoster => 'plakat';

  @override
  String get confirmItemBackdrop => 'bakgrunnsbilde';

  @override
  String get confirmItemBanner => 'banner';

  @override
  String get confirmItemLogo => 'logo';

  @override
  String get confirmItemThumbnail => 'miniatyrbilde';

  @override
  String get confirmItemArt => 'grafikk';

  @override
  String get confirmItemDiscArt => 'plategrafikk';

  @override
  String get confirmItemScreenshot => 'skjermbilde';

  @override
  String get confirmItemBoxCover => 'boksomslag';

  @override
  String get confirmItemBoxRearCover => 'boksomslag bak';

  @override
  String get confirmItemMenuArt => 'menygrafikk';

  @override
  String get resolutionAll => 'Alle';

  @override
  String get resolutionHigh => 'Høy (1080p+)';

  @override
  String get resolutionMedium => 'Middels (720p)';

  @override
  String get resolutionLow => 'Lav (<720p)';

  @override
  String get sources => 'Kilder';

  @override
  String get audiobookChapters => 'Kapitler';

  @override
  String get audiobookBookmarks => 'Bokmerker';

  @override
  String get audiobookNotes => 'Notater';

  @override
  String get audiobookQueue => 'Kø';

  @override
  String get audiobookTimeline => 'Tidslinje';

  @override
  String get audiobookTimelineEmpty => 'Tidslinjen er tom';

  @override
  String get audiobookFocusedTimeline => 'Fokusert tidslinje';

  @override
  String get audiobookFullTimeline => 'Hele tidslinjen';

  @override
  String get audiobookExportBookmarks => 'Eksporter bokmerker';

  @override
  String get audiobookExportNotes => 'Eksporter notater';

  @override
  String get audiobookExportAll => 'Eksporter alt';

  @override
  String audiobookExportSuccess(String path) {
    return 'Eksportert til $path';
  }

  @override
  String audiobookExportFailed(String error) {
    return 'Eksporten mislyktes: $error';
  }

  @override
  String get audiobookLyrics => 'Sangtekster';

  @override
  String get audiobookAddBookmark => 'Legg til bokmerke';

  @override
  String get audiobookAddNote => 'Legg til notat';

  @override
  String get audiobookEditNote => 'Rediger notat';

  @override
  String get audiobookNoteHint => 'Skriv et notat for dette øyeblikket';

  @override
  String get audiobookSleepTimer => 'Sovetidtaker';

  @override
  String get audiobookSleepOff => 'Av';

  @override
  String get audiobookSleepEndOfChapter => 'Slutten av kapitlet';

  @override
  String get audiobookSleepCustom => 'Egendefinert';

  @override
  String audiobookSleepRemaining(String remaining) {
    return '$remaining igjen';
  }

  @override
  String audiobookSleepMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get audiobookPlaybackSpeed => 'Avspillingshastighet';

  @override
  String get audiobookRemainingTime => 'Gjenstår';

  @override
  String get audiobookElapsedTime => 'Forløpt';

  @override
  String audiobookSkipBackSeconds(int seconds) {
    return 'Tilbake $seconds s';
  }

  @override
  String audiobookSkipForwardSeconds(int seconds) {
    return 'Fram $seconds s';
  }

  @override
  String get audiobookPreviousChapter => 'Forrige kapittel';

  @override
  String get audiobookNextChapter => 'Neste kapittel';

  @override
  String audiobookChapterIndicator(int current, int total) {
    return 'Kapittel $current av $total';
  }

  @override
  String get audiobookNoChapters => 'Ingen kapitler';

  @override
  String get audiobookNoBookmarks => 'Ingen bokmerker ennå';

  @override
  String get audiobookNoNotes => 'Ingen notater ennå';

  @override
  String audiobookBookmarkAdded(String position) {
    return 'Bokmerke lagt til ved $position';
  }

  @override
  String get audiobookSpeedReset => 'Tilbakestill til 1.0x';

  @override
  String audiobookSpeedCustomLabel(String value) {
    return '${value}x';
  }

  @override
  String get audiobookSave => 'Lagre';

  @override
  String get audiobookCancel => 'Avbryt';

  @override
  String get audiobookDelete => 'Slett';

  @override
  String get subtitlePreferencesDescription =>
      'Endre undertekstmoduser, standardspråk, utseende og gjengivelsesalternativer.';

  @override
  String get subtitleRendering => 'Undertekstgjengivelse';

  @override
  String get displayOptions => 'Visningsalternativer';

  @override
  String get releaseDateAscending => 'Utgivelsesdato (stigende)';

  @override
  String get releaseDateDescending => 'Utgivelsesdato (synkende)';

  @override
  String get groupContributions => 'Grupper bidrag';

  @override
  String get groupMultipleRoles => 'Grupper flere roller';

  @override
  String get libraryWriteAccessWarningTitle =>
      'Advarsel om skrivetilgang til biblioteket';

  @override
  String get libraryWriteAccessHowToFix => 'Slik løser du dette:';

  @override
  String get libraryWriteAccessFixSteps =>
      '1. Gi skrivetillatelser til Jellyfin-tjenestebrukeren (f.eks. jellyfin eller Docker PUID/PGID) for mediebibliotekmappene på serveren.\n\n2. Eller gå til Jellyfin-dashbordet -> Biblioteker, rediger dette biblioteket og deaktiver «Save artwork into media folders» for å lagre bildemateriell i Jellyfins interne database.';

  @override
  String get dismiss => 'Lukk';

  @override
  String libraryWriteAccessProactiveBody(
    String libraryName,
    String failedPath,
  ) {
    return 'Biblioteket \'$libraryName\' er konfigurert til å lagre bildemateriell direkte i mediemappene (\'Save artwork into media folders\' er aktivert). Jellyfin har imidlertid testet skrivetilgangen og har ikke tillatelse til å skrive filer til denne katalogen:\n\n$failedPath';
  }

  @override
  String get libraryWriteAccessReactiveBody =>
      'Det ser ut til at Jellyfin ikke klarte å oppdatere bildematerialet. Biblioteket ditt er konfigurert til å lagre bildemateriell direkte i mediemappene («Save artwork into media folders» er aktivert). Denne feilen oppstår vanligvis når Jellyfin-serverprosessen ikke har tillatelse til å skrive filer til mediekatalogene dine.';

  @override
  String get replay => 'Spill av på nytt';

  @override
  String get fileInformation => 'Filinformasjon';

  @override
  String fileSizeFormat(Object size, Object format) {
    return 'Størrelse: $size  •  Format: $format';
  }

  @override
  String dateCreatedFormat(Object date) {
    return 'Lagt til: $date';
  }

  @override
  String showAllAudioTracks(int count) {
    return 'Vis alle ($count) lydspor';
  }

  @override
  String showAllSubtitleTracks(int count) {
    return 'Vis alle ($count) undertekstspor';
  }

  @override
  String get checkingDirectPlay => 'Kontrollerer Direct Play-kapasitet...';

  @override
  String get directPlayCapabilityLabel => 'Direct Play-kapasitet: ';

  @override
  String get forced => 'Tvunget';

  @override
  String get transcodeContainerNotSupported =>
      'Containerformatet støttes ikke av spilleren.';

  @override
  String get transcodeVideoCodecNotSupported => 'Videokodeken støttes ikke.';

  @override
  String get transcodeAudioCodecNotSupported => 'Lydkodeken støttes ikke.';

  @override
  String get transcodeSubtitleCodecNotSupported =>
      'Undertekstformatet støttes ikke (må brennes inn).';

  @override
  String get transcodeAudioProfileNotSupported => 'Lydprofilen støttes ikke.';

  @override
  String get transcodeVideoProfileNotSupported => 'Videoprofilen støttes ikke.';

  @override
  String get transcodeVideoLevelNotSupported => 'Videonivået støttes ikke.';

  @override
  String get transcodeVideoResolutionNotSupported =>
      'Videooppløsningen støttes ikke av denne enheten.';

  @override
  String get transcodeVideoBitDepthNotSupported =>
      'Videoens bitdybde støttes ikke.';

  @override
  String get transcodeVideoFramerateNotSupported =>
      'Videoens bildefrekvens støttes ikke.';

  @override
  String get transcodeContainerBitrateExceedsLimit =>
      'Filens bitrate overskrider spillerens strømmegrense.';

  @override
  String get transcodeVideoBitrateExceedsLimit =>
      'Videoens bitrate overskrider strømmegrensen.';

  @override
  String get transcodeAudioBitrateExceedsLimit =>
      'Lydens bitrate overskrider strømmegrensen.';

  @override
  String get transcodeAudioChannelsNotSupported =>
      'Antall lydkanaler støttes ikke.';

  @override
  String transcodeAudioCodecWithCodec(String codec) {
    return 'Lydkodeken ($codec) støttes ikke direkte.';
  }

  @override
  String transcodeAudioCodecHintPassthrough(String codec) {
    return 'Tips: Hvis forsterkeren eller lydplanken støtter $codec, slår du på Passthrough for lyd under Lyd-innstillinger.';
  }

  @override
  String transcodeAudioChannelsExceeded(int channels) {
    return 'Antall lydkanaler ($channels kan.) er over grensen til spilleren.';
  }

  @override
  String get transcodeAudioChannelsHint =>
      'Tips: Juster «Maks lydkanaler» eller nedmiksing av flerkanalslyd under Lyd-innstillinger.';

  @override
  String get transcodeSubtitleBurnInAssDisabled =>
      'ASS/SSA-undertekster krever omkoding fordi direkteavspilling er slått av.';

  @override
  String get transcodeSubtitleBurnInAssHint =>
      'Tips: Slå på «Direkteavspilling av ASS/SSA» under Avspilling for å spille direkte uten omkoding.';

  @override
  String get transcodeSubtitleBurnInPgsDisabled =>
      'PGS-undertekster krever omkoding fordi direkteavspilling er slått av.';

  @override
  String get transcodeSubtitleBurnInPgsHint =>
      'Tips: Slå på «Direkteavspilling av PGS» under Avspilling for å spille direkte uten omkoding.';

  @override
  String transcodeSubtitleNotSupportedWithCodec(String codec) {
    return 'Undertekstformatet ($codec) støttes ikke direkte og må brennes inn.';
  }

  @override
  String transcodeBitrateExceededWithValues(
    String fileBitrate,
    String maxBitrate,
  ) {
    return 'Bithastigheten til filen ($fileBitrate) er over den innstilte strømmegrensen ($maxBitrate).';
  }

  @override
  String get transcodeBitrateHint =>
      'Tips: Øk «Maks bithastighet» under Avspilling for å tillate direkte strømming.';

  @override
  String get transcodeResolutionHint =>
      'Tips: Øk «Maks oppløsning» under Avspilling for å tillate direkte strømming.';

  @override
  String get transcodeVideoRangeNotSupported =>
      'Dynamisk område i videoen (f.eks. Dolby Vision / HDR) støttes ikke av denne skjermen.';

  @override
  String get transcodeDolbyVisionProfile7ElDisabled =>
      'Direkteavspilling av forbedringslaget i Dolby Vision Profil 7 er slått av.';

  @override
  String get transcodeDolbyVisionProfile7ElHint =>
      'Tips: Slå på «Direkteavspilling av Dolby Vision Profil 7» under Avspilling hvis skjermen støtter det.';

  @override
  String get transcodeDolbyVisionFallbackPreferenceTranscode =>
      'Omkoding er valgt som reserve for Dolby Vision i brukerinnstillingene.';

  @override
  String get transcodeDolbyVisionFallbackHint =>
      'Tips: Sett «Reserve for Dolby Vision» til «Spill som HDR10» under Avspilling for å unngå omkoding.';

  @override
  String get transcodeDisplayReportsNoHdr =>
      'Den tilkoblede skjermen oppgir ikke støtte for HDR eller Dolby Vision.';

  @override
  String get transcodeDisplayLacksHdr10ForFallback =>
      'Den tilkoblede skjermen mangler HDR10-støtten som trengs som reserve for Dolby Vision.';

  @override
  String get transcodeAudioSampleRateNotSupported =>
      'Samplingsfrekvensen for lyden støttes ikke.';

  @override
  String get transcodeAudioBitDepthNotSupported =>
      'Bitdybden for lyden støttes ikke.';

  @override
  String get transcodeRefFramesNotSupported =>
      'Referansebildene i videoen er over grensene til spilleren.';

  @override
  String get transcodeAnamorphicVideoNotSupported =>
      'Anamorfisk video støttes ikke.';

  @override
  String get transcodeInterlacedVideoNotSupported =>
      'Linjeflettet video støttes ikke.';

  @override
  String get transcodeSecondaryAudioNotSupported =>
      'Sekundært lydspor krever omkoding.';

  @override
  String get transcodeDirectPlayError =>
      'Direkteavspilling støttes ikke for dette medieformatet.';

  @override
  String get sortAlphabetical => 'Alfabetisk';

  @override
  String get sortReleaseAscending => 'Utgivelsesrekkefølge (stigende)';

  @override
  String get sortReleaseDescending => 'Utgivelsesrekkefølge (synkende)';

  @override
  String get sortCustomDragDrop => 'Egendefinert (dra og slipp)';

  @override
  String get playlistSortOptions => 'Sorteringsalternativer for spilleliste';

  @override
  String get resetSort => 'Tilbakestill sortering';

  @override
  String rewatchSeasonEpisode(int season, int episode) {
    return 'Se S$season:E$episode på nytt';
  }

  @override
  String get rewatchPlaylist => 'Se spillelisten på nytt';

  @override
  String get noSubtitlesFound => 'Fant ingen undertekster.';

  @override
  String get adminControls => 'Adminkontroller';

  @override
  String get impellerRendering => 'Gjengivelsesmotor (Impeller)';

  @override
  String get impellerRenderingSubtitle =>
      'Impeller er Flutters moderne GPU-gjengiver som gir jevnere animasjoner og mindre hakking. På enkelte TV-bokser og eldre GPU-er kan den forårsake feil eller svart video – slå den av hvis du opplever det. Automatisk velger den beste standardinnstillingen for enheten din. Start Tortugarr på nytt for å ta i bruk endringen.';

  @override
  String get impellerAuto => 'Automatisk';

  @override
  String get impellerOn => 'På';

  @override
  String get impellerOff => 'Av';

  @override
  String get impellerRestartTitle => 'Omstart kreves';

  @override
  String get impellerRestartMessage =>
      'Tortugarr må startes på nytt for å endre gjengivelsesmotoren. Lukk appen nå, og åpne den igjen for å ta i bruk endringen.';

  @override
  String get impellerCloseNow => 'Lukk appen nå';

  @override
  String get adminRefreshLibrary => 'Oppdater bibliotek';

  @override
  String get adminRefreshAllLibraries => 'Oppdater alle biblioteker';

  @override
  String get adminRepoSortDateOldest => 'Lagt til (eldste først)';

  @override
  String get adminRepoSortDateNewest => 'Lagt til (nyeste først)';

  @override
  String get adminRepoSortNameAsc => 'Alfabetisk (A til Å)';

  @override
  String get adminRepoSortNameDesc => 'Alfabetisk (Å til A)';

  @override
  String adminAnalyticsLoadingProgress(int percentage) {
    return 'Laster inn serveranalyse... $percentage %';
  }

  @override
  String get adminLibChapterImageResolutionMatchSource => 'Samme som kilden';

  @override
  String get imdbTop250Movies => 'IMDb topp 250 filmer';

  @override
  String get imdbTop250TvShows => 'IMDb topp 250 TV-serier';

  @override
  String get imdbMostPopularMovies => 'IMDb mest populære filmer';

  @override
  String get imdbMostPopularTvShows => 'IMDb mest populære TV-serier';

  @override
  String get imdbLowestRatedMovies => 'IMDb lavest rangerte filmer';

  @override
  String get imdbTopEnglishMovies => 'IMDb topprangerte engelske filmer';

  @override
  String get addToWatchlist => 'Legg til i visningslisten';

  @override
  String get removeFromWatchlist => 'Fjern fra visningslisten';

  @override
  String get watchlistUpdateFailed => 'Kunne ikke oppdatere visningslisten';

  @override
  String get adminSearchParameters => 'Søkeparametere';

  @override
  String get adminCurrentMetadata => 'Nåværende metadata';

  @override
  String get adminLabelYear => 'År';

  @override
  String get adminReplaceImages => 'Erstatt eksisterende bilder';

  @override
  String get adminBackToSearch => 'Tilbake til søkekriterier';

  @override
  String get grouping => 'Gruppering';

  @override
  String get groupByType => 'Grupper etter type';

  @override
  String get playlistTypes => 'Spillelistetyper';

  @override
  String get playlistTypeVideo => 'Video';

  @override
  String get playlistTypeMusicVideo => 'Musikkvideo';

  @override
  String get playlistTypeAudio => 'Lyd (musikk)';

  @override
  String get playlistTypeAudiobook => 'Lydbok';

  @override
  String get playlistTypeBook => 'Bok';

  @override
  String get playlistTypePhoto => 'Bilde';

  @override
  String get playlistTypeMixed => 'Blandet';

  @override
  String get videoPlaylistsSection => 'Videospillelister';

  @override
  String get musicVideoPlaylistsSection => 'Spillelister med musikkvideoer';

  @override
  String get audioPlaylistsSection => 'Lydspillelister';

  @override
  String get audiobookPlaylistsSection => 'Lydbokspillelister';

  @override
  String get bookPlaylistsSection => 'Bokspillelister';

  @override
  String get photoPlaylistsSection => 'Bildespillelister';

  @override
  String get mixedPlaylistsSection => 'Blandede spillelister';

  @override
  String get currentTime => 'Klokkeslett';

  @override
  String get playbackTimeDisplay => 'Tid ved fremdriftslinjen';

  @override
  String get settingsPlaybackTimeDisplayDescription =>
      'Velg hvilke tidsangivelser som vises rundt fremdriftslinjen.';

  @override
  String get playbackTimeTotal => 'Total varighet';

  @override
  String get playbackTimeRemaining => 'Gjenstående tid';

  @override
  String get playbackTimeEndsAt => 'Slutter kl.';

  @override
  String get playbackTimeElapsed => 'Tid brukt';

  @override
  String get playbackTimeVideoSection => 'Videospiller';

  @override
  String get playbackTimeMusicSection => 'Musikkspiller';

  @override
  String get playbackTimeSlotDescription =>
      'Velg hva som vises her, eller skjul det.';

  @override
  String get playbackTimeAboveBarLeft => 'Over linjen, venstre';

  @override
  String get playbackTimeAboveBarCenter => 'Over linjen, midten';

  @override
  String get playbackTimeAboveBarRight => 'Over linjen, høyre';

  @override
  String get playbackTimeBelowBarLeft => 'Under linjen, venstre';

  @override
  String get playbackTimeBelowBarCenter => 'Under linjen, midten';

  @override
  String get playbackTimeBelowBarRight => 'Under linjen, høyre';

  @override
  String get settingsMusicPlaybackTimeDescription =>
      'Velg hva som vises på høyre side av fremdriftslinjen for musikk.';

  @override
  String get groupByTitle => 'Grupper etter';

  @override
  String get groupByDecade => 'Tiår (år)';

  @override
  String get groupByParentalRating => 'Aldersgrense';

  @override
  String get groupByStudio => 'Studio';

  @override
  String get showAlphabeticalFilters => 'Vis alfabet';

  @override
  String get personalRatingStyle => 'Stil for egen vurdering';

  @override
  String get personalRatingThumbs => 'Liker / liker ikke';

  @override
  String get personalRatingStars => '5 stjerner';

  @override
  String get personalRatingNumeric => 'Tallkarakter av 10';

  @override
  String get rate => 'Vurder';

  @override
  String get like => 'Liker';

  @override
  String get dislike => 'Liker ikke';

  @override
  String get personalRatingClear => 'Fjern vurdering';

  @override
  String get personalRatingRated => 'Vurdert';

  @override
  String get personalRatingMine => 'Min vurdering';

  @override
  String get personalRatingSaveFailed => 'Kunne ikke lagre vurderingen';

  @override
  String get increase => 'Øk';

  @override
  String get decrease => 'Senk';

  @override
  String personalRatingOutOfTen(String rating) {
    return '$rating / 10';
  }

  @override
  String personalRatingOutOfFive(String rating) {
    return '$rating / 5';
  }

  @override
  String get filterInProgress => 'Påbegynt';

  @override
  String get filterUnreleased => 'Ikke utgitt';

  @override
  String get filterTrailers => 'Trailere';

  @override
  String get filterExtras => 'Ekstra';

  @override
  String get filterThemeSongs => 'Kjenningsmelodier';

  @override
  String get filterThemeVideos => 'Temavideoer';

  @override
  String get source => 'Kilde';

  @override
  String get years => 'År';

  @override
  String get audioLanguage => 'Lydspråk';

  @override
  String get subtitleLanguage => 'Undertekstspråk';

  @override
  String get clearFilters => 'Fjern filtre';

  @override
  String get seerrShortcutsRow => 'Utforsk Seerr';

  @override
  String get seerrReleased => 'Utgitt';

  @override
  String get seerrMinRating => 'Minste vurdering';

  @override
  String get seerrMinVotes => 'Minste antall stemmer';

  @override
  String get seerrOriginalLanguage => 'Originalspråk';

  @override
  String get seerrRuntime => 'Spilletid';

  @override
  String get subtitleHdrSeparate => 'Egen HDR-stil';

  @override
  String get subtitleHdrSeparateSubtitle =>
      'Hvitt er mye lysere i HDR enn i SDR, så en svakere stil her hindrer blending';

  @override
  String get scrollSensitivity => 'Rullefølsomhet';

  @override
  String get scrollSensitivitySubtitle =>
      'Hvor langt ett hakk på musehjulet ruller';

  @override
  String get mediaDetailsAndSpoilers => 'Mediedetaljer og spoilere';

  @override
  String get openTrailersExternally => 'Åpne trailere i ekstern app';

  @override
  String get openTrailersExternallySubtitle =>
      'Traileren åpnes i YouTube-appen eller nettleseren i stedet for den innebygde spilleren';

  @override
  String get hideDetailsMediaDescription => 'Skjul mediebeskrivelse';

  @override
  String get hideDetailsMediaDescriptionSubtitle =>
      'Skjul beskrivelsen av filmen eller episoden.';

  @override
  String get detailUseSeriesThumbnails => 'Bruk seriens miniatyrbilder';

  @override
  String get detailUseSeriesThumbnailsSubtitle =>
      'Erstatt alle miniatyrbilder på den klassiske detaljsiden med seriens miniatyrbilde';

  @override
  String get hideHomeMediaDescription => 'Skjul mediebeskrivelse';

  @override
  String get hideHomeMediaDescriptionSubtitle =>
      'Skjul beskrivelsen av filmen eller episoden.';

  @override
  String get continueWatchingAndNextUpHeader => 'Fortsett å se og Neste';

  @override
  String get setupSkip => 'Hopp over oppsett';

  @override
  String get setupNavbarQuestion => 'Hvor skal navigasjonen være?';

  @override
  String get setupMediaBarQuestion =>
      'Hvordan skal toppen av startskjermen se ut?';

  @override
  String get setupHomeRowsQuestion => 'Hvordan skal radene se ut?';

  @override
  String get setupDetailQuestion =>
      'Hvordan skal en film eller serie se ut når du åpner den?';

  @override
  String get setupTourQuestion => 'Du er klar. Her er hva mer som finnes.';

  @override
  String get setupPlaybackLanguages => 'Avspillingsspråk';

  @override
  String get setupOptional => 'Valgfritt';

  @override
  String get setupStyleClassic => 'Klassisk';

  @override
  String get setupStyleModern => 'Moderne';

  @override
  String get setupRowsClassicHint =>
      'Kompakt. Flere rader på skjermen samtidig.';

  @override
  String get setupRowsModernHint => 'Større kort med titler under.';

  @override
  String get setupDetailClassicHint => 'Alt midtstilt i én stabel.';

  @override
  String get setupDetailModernHint =>
      'Filmatisk, med faner for rolleliste og ekstra.';

  @override
  String get setupStyleSpotlight => 'Spotlight';

  @override
  String get setupDetailSpotlightHint =>
      'Stort bilde først, med sprettkort for rolleliste og ekstra.';

  @override
  String get setupStyleNouveau => 'Nouveau';

  @override
  String get setupDetailNouveauHint =>
      'Fullskjerm, med seksjoner stablet i stedet for faner.';

  @override
  String get setupStyleMinimalist => 'Minimalistisk';

  @override
  String get setupDetailMinimalistHint =>
      'Bilder, én avspillingsknapp og episodene.';

  @override
  String get setupNavbarStyleQuestion => 'Hvordan skal bunnlinjen se ut?';

  @override
  String get setupNavbarStyleDockHint =>
      'En flytende pille med etiketter under hver fane.';

  @override
  String get setupNavbarStyleSplitHint =>
      'Søk får egen knapp, og linjen krymper mens du ruller.';

  @override
  String get setupNavbarStyleStripHint =>
      'En linje over hele bredden langs nederkanten.';

  @override
  String get setupPickALook => 'Velg et utseende';

  @override
  String get setupTourMoreHeader => 'Det venter mer i Innstillinger';

  @override
  String get setupTourBulletRequests => 'Seerr-forespørsler';

  @override
  String get setupTourBulletSyncPlay => 'Felles visning med SyncPlay';

  @override
  String get setupTourBulletThemes => 'Egne temaer';

  @override
  String get setupTourBulletDownloads => 'Nedlastinger for frakoblet bruk';

  @override
  String get setupTourBulletMore => 'Og mye mer';

  @override
  String get runSetupAgain => 'Kjør oppsettet på nytt';

  @override
  String get serverMessages => 'Meldinger';

  @override
  String get serverMessagesEmpty => 'Ingen meldinger fra serveren ennå';

  @override
  String get serverMessagesMarkAllRead => 'Merk alle som lest';

  @override
  String get serverMessagesShowButton => 'Vis Meldinger-knappen';

  @override
  String get serverMessagesShowButtonSubtitle =>
      'Legger til en knapp i menyen for meldinger fra serveradministratoren';

  @override
  String get showBookDiscoverTab => 'Vis utforsking i bokbiblioteket';

  @override
  String get showBookDiscoverTabDescription =>
      'Bla i titler fra Open Library og LibriVox i bok- og lydbokbibliotekene';

  @override
  String get autoDownloadNewEpisodes => 'Last ned nye episoder automatisk';

  @override
  String get autoDownloadStop => 'Stopp automatisk nedlasting';

  @override
  String autoDownloadKeepUnwatchedSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Laster ned nye episoder, opptil $count usette om gangen',
      one: 'Laster ned nye episoder, opptil 1 usett om gangen',
      zero: 'Laster ned alle nye episoder',
    );
    return '$_temp0';
  }

  @override
  String autoDownloadStopSubtitle(String quality) {
    return 'På • $quality';
  }

  @override
  String get autoDownloadTranscodedForegroundNote =>
      'Omkodede kvaliteter lastes bare ned mens Tortugarr er åpen. Originalkvalitet lastes også ned i bakgrunnen.';

  @override
  String get autoDownloadTranscodedRunningNote =>
      'Omkodede nedlastinger kan ikke fortsette etter et avbrudd og starter på nytt fra begynnelsen. Originalkvalitet kan fortsette.';

  @override
  String get autoDownloadForegroundOnly =>
      'Laster bare ned mens Tortugarr er åpen';

  @override
  String get autoDownloadQualityTitle => 'Kvalitet for automatisk nedlasting';

  @override
  String autoDownloadEnabledFor(String title) {
    return 'Automatisk nedlasting slått på for $title';
  }

  @override
  String autoDownloadStoppedFor(String title) {
    return 'Automatisk nedlasting stoppet for $title';
  }

  @override
  String get smartDownloadsSection => 'Smarte nedlastinger';

  @override
  String get smartDownloadsEnable => 'Last ned neste episoder';

  @override
  String get smartDownloadsEnableDescription =>
      'Når du er ferdig med en episode på en hvilken som helst enhet, laster Tortugarr ned de neste. Episoder som lastes ned slik, slettes når de er sett.';

  @override
  String get smartDownloadsKeepReady => 'Episoder som holdes nedlastet';

  @override
  String smartDownloadsKeepReadySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Holder de neste $count episodene nedlastet',
      one: 'Holder neste episode nedlastet',
    );
    return '$_temp0';
  }

  @override
  String get smartDownloadsKeepReadyLowered =>
      'Episoder som allerede er lastet ned, blir liggende på enheten. Det nye antallet gjelder fremtidige nedlastinger.';

  @override
  String get autoDownloadSection => 'Automatiske nedlastinger';

  @override
  String get autoDownloadEnable => 'Slå på automatiske nedlastinger';

  @override
  String get autoDownloadEnableSubtitle =>
      'Laster ned nye episoder av seriene du følger. Eksisterende episoder kan fortsatt lastes ned manuelt.';

  @override
  String get autoDownloadKeepUnwatched => 'Behold usette episoder';

  @override
  String get autoDownloadKeepAll => 'Alle';

  @override
  String get autoDownloadDelete => 'Slett nedlastede episoder';

  @override
  String get autoDownloadDeleteFollowedSubtitle =>
      'Når episoder lastet ned for serier du følger, skal fjernes etter at du har sett dem';

  @override
  String get removeWatchedDownloads => 'Fjern sette nedlastinger';

  @override
  String get removeWatchedDownloadsSubtitle =>
      'Når episoder og filmer du har lastet ned selv, skal fjernes. Bare de du ser etter at dette er slått på, fjernes';

  @override
  String get keepDownloaded => 'Behold nedlastet';

  @override
  String get keepDownloadedSubtitle =>
      'Fjern aldri dette automatisk etter visning';

  @override
  String get autoDownloadDeleteNever => 'Aldri';

  @override
  String get autoDownloadDeleteImmediately => 'Rett etter visning';

  @override
  String get autoDownloadDeleteAfterDay => '1 dag etter visning';

  @override
  String get autoDownloadDeleteAfterWeek => '1 uke etter visning';

  @override
  String get autoDownloadBackgroundRefresh => 'Sjekk i bakgrunnen';

  @override
  String get autoDownloadBackgroundRefreshSubtitle =>
      'La systemet se etter nye episoder jevnlig mens Tortugarr er lukket';

  @override
  String get autoDownloadBackgroundRefreshDenied =>
      'Oppdatering i bakgrunnen er slått av for Tortugarr. Slå det på i iOS-innstillingene.';

  @override
  String get autoDownloadBackgroundRestrictedAndroid =>
      'Bakgrunnsbruk er begrenset for Tortugarr i Android-innstillingene.';

  @override
  String get autoDownloadCheckNow => 'Sjekk nå';

  @override
  String get autoDownloadChecking => 'Sjekker …';

  @override
  String get autoDownloadNeverChecked => 'Ikke sjekket ennå';

  @override
  String autoDownloadLastCheck(String when, int queued) {
    String _temp0 = intl.Intl.pluralLogic(
      queued,
      locale: localeName,
      other: '$queued episoder lagt i kø',
      one: '1 episode lagt i kø',
      zero: 'ingenting nytt',
    );
    return 'Sist sjekket $when: $_temp0';
  }

  @override
  String autoDownloadLastCheckFailed(String when, String error) {
    return 'Sjekken $when mislyktes: $error';
  }

  @override
  String get autoDownloadFollowedSeries => 'Fulgte serier';

  @override
  String get autoDownloadNoSubscriptions =>
      'Åpne en serie og velg «Last ned nye episoder automatisk» i nedlastingsmenyen';

  @override
  String get autoDownloadRemove => 'Slutt å følge';

  @override
  String get autoDownloadStorageFull => 'Ikke nok lagringsplass';

  @override
  String get autoDownloadWaitingForWifi => 'Venter på Wi-Fi';

  @override
  String get downloadNotificationRunning => 'Laster ned';

  @override
  String downloadNotificationRunningBatch(int done, int total) {
    return 'Laster ned ($done/$total)';
  }

  @override
  String downloadNotificationProgress(String name, int percent) {
    return '$name — $percent %';
  }

  @override
  String downloadNotificationTransfer(
    String name,
    String progress,
    String timeRemaining,
  ) {
    return '$name — $progress · $timeRemaining';
  }

  @override
  String downloadNotificationStarting(String name) {
    return '$name …';
  }

  @override
  String downloadNotificationCompleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nedlastinger fullført',
      one: 'Nedlasting fullført',
    );
    return '$_temp0';
  }

  @override
  String downloadNotificationSaved(String name) {
    return '$name lagret for frakoblet bruk';
  }

  @override
  String downloadNotificationSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementer lagret for frakoblet bruk',
      one: '1 element lagret for frakoblet bruk',
    );
    return '$_temp0';
  }

  @override
  String downloadNotificationSeriesEpisodes(String series, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episoder',
      one: '1 episode',
    );
    return '$series: $_temp0';
  }

  @override
  String get downloadNotificationFailedTitle => 'Nedlasting mislyktes';

  @override
  String downloadNotificationFailedBody(String name, String error) {
    return '$name: $error';
  }

  @override
  String get serverMessagesNotificationTitle => 'Melding fra serveren';

  @override
  String get serverMessagesNotificationReceived => 'Melding mottatt';

  @override
  String get downloadStorageLimitReached =>
      'Lagringsgrensen er nådd. Frigjør plass eller øk grensen.';

  @override
  String downloadNotEnoughStorage(String needed, String free) {
    return 'Ikke nok lagringsplass: $needed trengs, $free ledig';
  }

  @override
  String get autoDownloadStorageFullTitle =>
      'Ikke nok lagringsplass til nye episoder';

  @override
  String autoDownloadStorageFullBody(int count, String name, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episoder venter på plass.',
      one: '$name trenger $size.',
    );
    return '$_temp0 Frigjør plass eller øk nedlastingsgrensen.';
  }

  @override
  String get pageTransitions => 'Sideoverganger';

  @override
  String get pageTransitionsSubtitle =>
      'Justerer tonetiden når du bytter mellom sider';

  @override
  String get navigationSpeed => 'Navigasjonshastighet';

  @override
  String get navigationSpeedSubtitle =>
      'Justerer hvor raskt fokusmarkøren flytter seg mellom elementer og rader';

  @override
  String get modernCardsTransitionSpeed =>
      'Overgangshastighet for moderne kort';

  @override
  String get modernCardsTransitionSpeedSubtitle =>
      'Justerer animasjonshastigheten når fokuserte moderne kort utvides';

  @override
  String get delayCardExpansionOnRapidScroll =>
      'Utsett kortutvidelse ved rask rulling';

  @override
  String get delayCardExpansionOnRapidScrollSubtitle =>
      'Venter til fokuset stopper opp før moderne kort utvides';

  @override
  String get animationSpeedExtraSlow => 'Ekstra sakte';

  @override
  String get animationSpeedSlow => 'Sakte';

  @override
  String get animationSpeedMedium => 'Middels';

  @override
  String get animationSpeedFast => 'Rask';

  @override
  String get animationSpeedOff => 'Av';

  @override
  String get pageTransitionFadeNone => 'Ingen toning';

  @override
  String get pageTransitionFadeShort => 'Kort toning';

  @override
  String get pageTransitionFadeMedium => 'Middels toning';

  @override
  String get pageTransitionFadeLong => 'Lang toning';

  @override
  String get siriRemoteSwipeSensitivity => 'Sveipefølsomhet på styreflaten';

  @override
  String get siriRemoteSwipeSensitivityDescription =>
      'Hvor langt fokuset flytter seg for hvert sveip på styreflaten til Siri Remote';

  @override
  String get appleTvHomeScreen => 'Apple TV-hjemskjerm';

  @override
  String get topShelf => 'Top Shelf';

  @override
  String get topShelfDescription =>
      'Hva Apple TV-hjemskjermen viser over Tortugarr-ikonet når det er valgt. Denne innstillingen gjelder bare denne enheten.';

  @override
  String get topShelfLatestMedia => 'Nyeste medier';

  @override
  String get topShelfAppBanner => 'Tortugarr-banner';

  @override
  String get keepVideoClearOfDynamicIsland =>
      'Hold videoen unna Dynamic Island';

  @override
  String get keepVideoClearOfDynamicIslandDescription =>
      'I liggende modus dekker kamerahuset den ene kanten av skjermen. Dette holder bildet unna det, noe som bare har betydning for video som er bred nok til å nå så langt.';

  @override
  String get bottomNavbarStyle => 'Stil på bunnlinjen';

  @override
  String get bottomNavbarStyleDock => 'Dokk';

  @override
  String get bottomNavbarStyleSplit => 'Delt';

  @override
  String get bottomNavbarStyleStrip => 'Stripe';

  @override
  String get bottomNavbarTabs => 'Faner på bunnlinjen';

  @override
  String get bottomNavbarTabsDescription =>
      'Fest opptil 3 faner mellom Hjem og Du. Alt annet ligger i navigasjonsknutepunktet nederst.';

  @override
  String get bottomNavbarTabsAutomatic => 'Automatisk';

  @override
  String get bottomNavbarTabsPinned => 'Festet';

  @override
  String get bottomNavbarTabsAvailable => 'Tilgjengelige';

  @override
  String get bottomNavbarTabsReset => 'Tilbakestill til automatisk';

  @override
  String get bottomNavbarTabsLimit =>
      'Du kan feste opptil 3 faner. Fjern én for å feste en annen.';

  @override
  String get bottomNavbarTabTurnedOff => 'Slått av under Knapper';

  @override
  String get bottomNavbarSplitSearchNote =>
      'I Delt-stilen har Søk alltid sin egen knapp.';

  @override
  String get bottomNavbarButtonsNote =>
      'Disse bestemmer hva som vises i navigasjonsknutepunktet nederst, og hvilke faner du kan feste til bunnlinjen. Faner som allerede ligger på linjen, vises ikke her.';

  @override
  String get navYou => 'Du';

  @override
  String get detailsPage => 'Detaljside';

  @override
  String get storageAndDownloads => 'Lagring og nedlastinger';

  @override
  String get integrations => 'Integrasjoner';

  @override
  String get settingsSync => 'Synkronisering av innstillinger';

  @override
  String get settingsSyncSubtitle =>
      'Synkronisering og tilpasningsprofiler med Moonbase-tillegget';

  @override
  String get navigationBar => 'Navigasjonslinje';

  @override
  String get homeRows => 'Rader';

  @override
  String get homeRowsSubtitle => 'Slå rader av eller på og endre rekkefølgen';

  @override
  String get rowOptions => 'Radvalg';

  @override
  String get rowOptionsSubtitle => 'Sortering og innhold for hver rad';

  @override
  String get imageTypePerRow => 'Bildetype per rad';

  @override
  String get externalSources => 'Eksterne kilder';

  @override
  String get qualityAndDecoding => 'Bilde og lydanlegg';

  @override
  String get qualityAndDecodingSubtitle =>
      'Avspillingsmotor, 4K, HDR, Dolby Vision og tunneling. Se her hvis filmer hakker';

  @override
  String get skippingAndAutoplay => 'Hopp over og automatisk avspilling';

  @override
  String get advancedPlayback => 'Avansert avspilling';

  @override
  String get advancedPlaybackSubtitle =>
      'Spillerruting, eksterne spillere og mpv';

  @override
  String get settingsAccountSubtitle =>
      'Pålogging, PIN-kode, barnemodus, foreldrekontroll og synkronisering av innstillinger';

  @override
  String get settingsGeneralSubtitle => 'Klokke, inndata og ytelse';

  @override
  String get settingsAppearanceSubtitle =>
      'Navigasjon, startskjerm, biblioteker, detaljside og temaer';

  @override
  String get settingsHomeScreenSubtitle =>
      'Rader, mediefelt, utseende og eksterne kilder';

  @override
  String get settingsLibrariesEntrySubtitle =>
      'Synlighet, rekkefølge og bibliotekssider';

  @override
  String get settingsDetailsPageSubtitle =>
      'Oppsett, knapper, seksjoner, vurderinger og temamusikk';

  @override
  String get settingsPlaybackSubtitle =>
      'Spiller, kvalitet, lyd, undertekster, hopp over og SyncPlay';

  @override
  String get settingsStorageSubtitle =>
      'Nedlastinger, lagringssted og bildebuffer';

  @override
  String get settingsServicesSubtitle => 'Seerr og Achievement Badges';

  @override
  String get settingsSignInSection => 'Pålogging';

  @override
  String get settingsFamilySection => 'Familie';

  @override
  String get settingsServersSection => 'Servere';

  @override
  String get settingsLanguageSection => 'Språk';

  @override
  String get settingsInputSection => 'Inndata';

  @override
  String get settingsMotionSection => 'Bevegelse';

  @override
  String get settingsContentsSection => 'Innhold';

  @override
  String get settingsLooksSection => 'Utseende';

  @override
  String get settingsAudioAndSubtitlesSection => 'Lyd og undertekster';

  @override
  String get settingsSkippingAndQueueSection => 'Hopp over og kø';

  @override
  String get settingsWatchTogetherSection => 'Se sammen';

  @override
  String get settingsAdvancedSection => 'Avansert';

  @override
  String get playerSettingsSubtitle =>
      'Kontroller, spoling, spillerknapper og forhåndsvisning ved spoling';

  @override
  String get playlistSortReleaseDate => 'Utgivelsesdato';

  @override
  String get playlistSortCriticRating => 'Kritikervurdering';

  @override
  String get playlistSortRuntime => 'Spilletid';

  @override
  String get playlistSortLastPlayed => 'Sist spilt';

  @override
  String get playlistSortPlayCount => 'Antall avspillinger';

  @override
  String get playlistSortRandom => 'Tilfeldig';

  @override
  String playlistFilterActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktive',
      one: '1 aktivt',
    );
    return '$_temp0';
  }

  @override
  String get playlistNoMatchingTracks =>
      'Ingen spor passer med de aktive filtrene';

  @override
  String get librarySortPlaylistOrder => 'Spillelisterekkefølge';

  @override
  String get librarySortDateAdded => 'Dato lagt til';

  @override
  String get librarySortDateEpisodeAdded => 'Dato episode lagt til';

  @override
  String get librarySortParentalRating => 'Aldersgrense';

  @override
  String get librarySortMyRating => 'Min vurdering';

  @override
  String get librarySortAlbumArtist => 'Albumartist';

  @override
  String get librarySortAlbum => 'Album';

  @override
  String get librarySortArtist => 'Artist';

  @override
  String get librarySortTrackNumber => 'Spornummer';

  @override
  String get librarySortGenre => 'Sjanger';

  @override
  String get librarySortFoldersFirst => 'Mapper først';

  @override
  String get librarySortLength => 'Lengde';

  @override
  String get seerrFilterNotSupported => 'Filteret støttes ikke';

  @override
  String get seerrFilterNotSupportedDetail =>
      'Dette nettverks- eller studiofilteret er ikke tilgjengelig fordi de interne ID-ene ikke stemmer overens. Bruk filtermenyen i stedet.';

  @override
  String get showAll => 'Vis alle';

  @override
  String get settingsBuiltOnOriginal => 'Bygget på Moonfin';

  @override
  String get tgMissing => 'Mangler';

  @override
  String get tgComing => 'Kommer';

  @override
  String tgComingOn(String date) {
    return 'Kommer $date';
  }

  @override
  String get tgDownloading => 'Lastes ned';

  @override
  String get tgReadySoon => 'Klar snart';

  @override
  String get tgRequested => 'Bestilt';

  @override
  String get tgClose => 'Lukk';

  @override
  String get tgCancel => 'Avbryt';

  @override
  String get tgBack => 'Tilbake';

  @override
  String get tgYes => 'Ja';

  @override
  String get tgNo => 'Nei';

  @override
  String get tgSearch => 'Søk';

  @override
  String get tgHide => 'Skjul';

  @override
  String get tgAll => 'Alle';

  @override
  String get tgNone => 'Ingen';

  @override
  String get tgMovies => 'Filmer';

  @override
  String get tgSeries => 'Serier';

  @override
  String get tgMovieTag => 'Film';

  @override
  String get tgSeriesTag => 'Serie';

  @override
  String get tgCanTakeAMinute => 'Kan ta opptil ett minutt';

  @override
  String get tgToday => 'i dag';

  @override
  String get tgYesterday => 'i går';

  @override
  String tgDaysAgo(int days) {
    return '$days dager siden';
  }

  @override
  String tgMonthsAgo(int months) {
    return '$months mnd siden';
  }

  @override
  String tgYearsAgo(int years) {
    return '$years år siden';
  }

  @override
  String tgYearsMonthsAgo(int years, int months) {
    return '$years år og $months mnd siden';
  }

  @override
  String get tgFindSubtitles => 'Finn undertekster';

  @override
  String get tgFreeUpSpace => 'Frigjør plass';

  @override
  String get tgDownloads => 'Nedlastinger';

  @override
  String tgDownloadsCount(int count) {
    return 'Nedlastinger ($count)';
  }

  @override
  String tgNoVideoRemoved(String title, String files) {
    return '«$title»: nedlastingen inneholdt ingen videofil ($files). Den er fjernet og blokkert – prøv en annen fil.';
  }

  @override
  String tgNoVideoNotRemoved(String title, String files) {
    return '«$title»: nedlastingen inneholdt ingen videofil ($files), men kunne ikke fjernes automatisk.';
  }

  @override
  String tgAiredOn(String date) {
    return 'Sendt $date';
  }

  @override
  String get tgTapToFindFiles => 'Trykk for å finne filer';

  @override
  String get tgWholeSeason => 'Hele sesongen';

  @override
  String tgEpisodesMissingFindPack(int count) {
    return '$count episoder mangler – finn en sesongpakke';
  }

  @override
  String get tgAddToSonarrTitle =>
      'Legg til i Sonarr for å se manglende episoder';

  @override
  String get tgAddToSonarrSubtitle =>
      'Serien legges til uten å laste ned noe av seg selv';

  @override
  String get tgMissingEpisodesUnavailable =>
      'Manglende episoder kan ikke vises nå';

  @override
  String tgReasonTapRetry(String reason) {
    return '$reason · Trykk for å prøve igjen';
  }

  @override
  String get tgSeasonPackBadge => 'Hel sesong';

  @override
  String tgMonitorSeasonTitle(int season) {
    return 'Overvåk sesong $season';
  }

  @override
  String tgMonitorSeasonQuestion(int season) {
    return 'Skal Sonarr hente manglende episoder i sesong $season nå?\n\nNei: bare nye episoder blir hentet når de kommer.';
  }

  @override
  String tgSonarrSearchingSeason(int season) {
    return 'Sonarr søker etter sesong $season';
  }

  @override
  String get tgMonitored => 'Overvåkes';

  @override
  String get tgNotMonitored => 'Ikke overvåket';

  @override
  String tgSeasonStateLabel(int season, String state) {
    return 'Sesong $season: $state';
  }

  @override
  String tgLabelMissing(String label) {
    return '$label mangler';
  }

  @override
  String tgNotAiredYet(String code) {
    return '$code er ikke sendt ennå.';
  }

  @override
  String tgNotAiredYetComing(String code, String date) {
    return '$code er ikke sendt ennå – kommer $date.';
  }

  @override
  String tgAlreadyDownloading(String code) {
    return '$code lastes allerede ned.';
  }

  @override
  String tgDownloadedAppearsSoon(String code) {
    return '$code er lastet ned og dukker opp i biblioteket om litt.';
  }

  @override
  String tgSearchingFor(String label) {
    return 'Søker etter $label …';
  }

  @override
  String tgSeasonLower(int season) {
    return 'sesong $season';
  }

  @override
  String tgWholeLabel(String label) {
    return 'Hele $label';
  }

  @override
  String tgSeasonNoEpisodes(int season) {
    return 'Sesong $season – ingen episoder i biblioteket';
  }

  @override
  String get tgNoTvdbId => 'Serien mangler TVDB-id, så Sonarr finner den ikke.';

  @override
  String get tgAddingToSonarr => 'Legger til i Sonarr …';

  @override
  String get tgAddToSonarrFailed =>
      'Fikk ikke lagt serien til i Sonarr. Prøv igjen senere.';

  @override
  String tgSendingToDownload(String label) {
    return 'Sender «$label» til nedlasting …';
  }

  @override
  String tgDownloadDidNotStart(String error) {
    return 'Nedlastingen startet ikke: $error';
  }

  @override
  String tgDownloadingAppearsWhenDone(String label, String size) {
    return '«$label» lastes ned ($size). Den dukker opp i biblioteket når den er ferdig.';
  }

  @override
  String get tgSonarrUnreachableRetry =>
      'Fikk ikke kontakt med Sonarr. Prøv igjen litt senere.';

  @override
  String get tgNoUsableFiles =>
      'Fant ingen brukbare filer. Prøv igjen senere – nye dukker ofte opp etter noen timer.';

  @override
  String tgFilesCount(int count) {
    return '$count filer';
  }

  @override
  String tgFilesRecommended(int count, int recommended) {
    return '$count filer – $recommended passer kvalitetsprofilen, resten er nederst';
  }

  @override
  String get tgOutsideQualityProfile => 'Utenfor kvalitetsprofilen';

  @override
  String get tgLargerThanProfile => 'Større enn profilen tillater';

  @override
  String get tgSmallerThanProfile => 'Mindre enn profilen tillater';

  @override
  String get tgAlreadyExists => 'Finnes allerede';

  @override
  String get tgMayNotFitDisk => 'Får kanskje ikke plass på disken';

  @override
  String get tgSonarrUnreachable => 'Fikk ikke kontakt med Sonarr';

  @override
  String tgSonarrUnreachableAt(String host) {
    return 'Fikk ikke kontakt med Sonarr på $host';
  }

  @override
  String get tgSonarrRejectedChange => 'Sonarr godtok ikke endringen';

  @override
  String get tgSeasonMonitoredNoSearch =>
      'Sesongen overvåkes, men Sonarr startet ikke søket';

  @override
  String get tgSonarrCantSearch => 'Sonarr kunne ikke søke nå';

  @override
  String get tgSearchExpired => 'Søkeresultatet er utløpt – søk på nytt';

  @override
  String tgSonarrRejectedDownload(String status) {
    return 'Sonarr tok ikke imot nedlastingen (HTTP $status)';
  }

  @override
  String get tgSonarrNoSeries => 'Sonarr har ikke serien';

  @override
  String tgCouldNotChangeMonitoring(String error) {
    return 'Kunne ikke endre overvåkingen: $error';
  }

  @override
  String get tgJellyfinNoIds =>
      'Jellyfin har ikke kjent igjen serien (mangler TVDB- og TMDB-id)';

  @override
  String tgSomethingWentWrong(String error) {
    return 'Noe gikk galt: $error';
  }

  @override
  String get tgDeleteReadOnly =>
      'Filen styres ikke av Radarr/Sonarr, og Jellyfin har bare lesetilgang til mappen. Slett den i Utforsker.';

  @override
  String get tgSonarrRequiredPerEpisode =>
      'Sonarr er ikke tilgjengelig, eller serien er ikke lagt til der. Per-episode nedlasting krever Sonarr.';

  @override
  String tgEpisodesNotFound(String title, int count) {
    return 'Kunne ikke finne de valgte episodene i Sonarr for «$title» (fant $count episoder totalt). Legg serien til i Sonarr og prøv igjen.';
  }

  @override
  String get tgPartOfCollectionPrefix => 'Del av filmserien ';

  @override
  String tgViewingPartOf(int current, int total) {
    return '  ·  du ser del $current av $total';
  }

  @override
  String tgPartOf(int number, int total) {
    return 'Del $number av $total';
  }

  @override
  String get tgUnknownTitle => 'Ukjent tittel';

  @override
  String get tgMovieCollection => 'Filmserie';

  @override
  String tgNotReleasedYet(String title) {
    return '«$title» er ikke kommet ut ennå';
  }

  @override
  String get tgScreensaverModeVideo => 'Video';

  @override
  String get tgScreensaverModeLogo => 'Logo';

  @override
  String get tgScreensaverSound => 'Lyd i skjermsparer';

  @override
  String get tgScreensaverSoundSubtitle =>
      'Av: trailerne i skjermspareren spilles uten lyd';

  @override
  String get tgScreensaverLogo => 'Logo';

  @override
  String get tgLogoBadge => 'Tortugarr-merket';

  @override
  String get tgLogoVhs => 'Papegøye på VHS-kassetter';

  @override
  String get tgLogoSign => 'Papegøye på skilt';

  @override
  String tgHiddenBadge(String code) {
    return 'SKJULES · $code';
  }

  @override
  String get tgDiskSpace => 'Diskplass';

  @override
  String get tgDiskSpaceSubtitle => 'Frigjør plass til nye nedlastinger';

  @override
  String get tgAdultTitle => 'Voksenfilmer (XXX)';

  @override
  String get tgAdultSubtitle => 'Vis eller skjul XXX-biblioteket (PIN)';

  @override
  String get tgHideForeign => 'Skjul utenlandsk innhold';

  @override
  String get tgHideForeignOn =>
      'På: Trending og Populært viser bare engelsk, norsk, svensk, dansk, tysk og fransk';

  @override
  String get tgHideForeignOff => 'Av: Trending og Populært viser alle språk';

  @override
  String get tgShowHidden => 'Vis hva som skjules';

  @override
  String get tgShowHiddenOn =>
      'På: titler som ellers skjules vises med rød SKJULES-merking';

  @override
  String get tgShowHiddenOff =>
      'Feilsøk: vis skjulte titler med rød merking i stedet for å fjerne dem';

  @override
  String get tgShowAllSubLangs => 'Vis alle undertekstspråk';

  @override
  String get tgShowAllSubLangsOn => 'På: undertekstmenyen viser alle språk';

  @override
  String get tgShowAllSubLangsOff =>
      'Av: undertekstmenyen viser bare norsk og engelsk';

  @override
  String get tgShowAllSubLangsOffChosen =>
      'Av: undertekstmenyen viser bare språkene du har valgt';

  @override
  String get tgSubtitleLanguages => 'Undertekstspråk';

  @override
  String tgSubtitleLanguagesSubtitle(String languages) {
    return 'Vises i undertekstmenyen: $languages';
  }

  @override
  String get tgPreviewSound => 'Lyd i forhåndsvisninger';

  @override
  String get tgPreviewSoundOn =>
      'På: klippet som spilles når du stopper på en tittel har lyd';

  @override
  String get tgPreviewSoundOff => 'Av: klipp spilles uten lyd mens du blar';

  @override
  String get tgScreensaver => 'Skjermsparer';

  @override
  String get tgScreensaverSubtitle => 'Video eller logo, lyd og bilde';

  @override
  String get tgShowMissingEpisodes => 'Vis manglende episoder';

  @override
  String get tgShowMissingEpisodesOn =>
      'På: sesonger viser episoder du ikke har, klare til nedlasting';

  @override
  String get tgShowMissingEpisodesOff =>
      'Av: sesonger viser bare episodene du har';

  @override
  String get tgShowCollections => 'Vis filmserier';

  @override
  String get tgShowCollectionsOn =>
      'På: filmer viser de andre filmene i serien, også de du mangler';

  @override
  String get tgShowCollectionsOff => 'Av: filmsiden viser ikke filmserien';

  @override
  String get tgNoActiveDownloads => 'Ingen aktive nedlastinger.';

  @override
  String get tgPickDownloadToOpen =>
      'Velg en nedlasting for å åpne forespørslene.';

  @override
  String get tgRefreshLibrary => 'Oppdater bibliotek';

  @override
  String get tgAskingJellyfinScan => 'Ber Jellyfin skanne biblioteket …';

  @override
  String get tgHideAll => 'Skjul alle';

  @override
  String get tgImporting => 'Importerer';

  @override
  String get tgSubsNotManaged =>
      'Denne tittelen styres ikke av Radarr/Sonarr, så Bazarr kan ikke finne undertekster til den.';

  @override
  String get tgBazarrUnreachable =>
      'Fikk ikke kontakt med Bazarr. Prøv igjen litt senere.';

  @override
  String get tgSubsFoundNothing =>
      'Fant ingenting ennå. Bazarr prøver igjen automatisk hver dag, eller du kan velge selv.';

  @override
  String tgSubsFound(String languages) {
    return 'Fant $languages – kan ta et øyeblikk før den dukker opp i undertekstmenyen.';
  }

  @override
  String get tgAnd => 'og';

  @override
  String get tgSubsDownloaded =>
      'Lastet ned – kan ta et øyeblikk før den dukker opp i undertekstmenyen.';

  @override
  String get tgAskingBazarr => 'Spør Bazarr …';

  @override
  String get tgHaveAll => 'Har alt';

  @override
  String get tgSearchAutoNow => 'Søk automatisk nå';

  @override
  String get tgSearchingUpToMinute => 'Søker … kan ta opptil ett minutt';

  @override
  String get tgPickYourself => 'Velg selv';

  @override
  String get tgAskingProviders =>
      'Spør undertekstkildene … kan ta opptil ett minutt';

  @override
  String get tgNoProviderSubs =>
      'Ingen kilder har undertekster til denne ennå.';

  @override
  String tgLangHas(String language) {
    return '$language: har';
  }

  @override
  String tgLangMissing(String language) {
    return '$language: mangler';
  }

  @override
  String get tgNoReleaseName => '(uten utgivelsesnavn)';

  @override
  String tgHearingImpaired(String provider) {
    return '$provider · for hørselshemmede';
  }

  @override
  String get tgLangNorwegian => 'Norsk';

  @override
  String get tgLangEnglish => 'Engelsk';

  @override
  String get tgBazarrUnknownTitle => 'Bazarr kjenner ikke denne tittelen ennå';

  @override
  String tgBazarrError(int code) {
    return 'Bazarr svarte med en feil (HTTP $code)';
  }

  @override
  String tgLowSpaceSnack(String drive, String free) {
    return 'Lite plass på $drive: ($free ledig). Nedlastingen kan stoppe — si fra til den som styrer serveren.';
  }

  @override
  String get tgNoQbitForSpace =>
      'Fikk ikke kontakt med qBittorrent for å sjekke plassen';

  @override
  String get tgNotEnoughSpace => 'Ikke nok plass';

  @override
  String tgDriveHasFree(String drive, String free) {
    return '$drive: har $free ledig';
  }

  @override
  String get tgCopyInDownloads =>
      'Kopi i Downloads · ligger allerede i biblioteket';

  @override
  String tgLastWatched(String ago) {
    return 'Sist sett $ago';
  }

  @override
  String tgNeverWatchedAdded(String ago) {
    return 'Aldri sett · lagt til $ago';
  }

  @override
  String get tgNeverWatched => 'Aldri sett';

  @override
  String tgNothingSafeToDelete(String drive) {
    return 'Fant ingenting på $drive: som kan slettes trygt (alt er nylig lagt til, nylig sett eller favoritter).';
  }

  @override
  String tgDeleteTitlesQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slette $count titler?',
      one: 'Slette 1 tittel?',
    );
    return '$_temp0';
  }

  @override
  String tgDeletedForGood(String size) {
    return '$size slettes for godt. Dette kan ikke angres.';
  }

  @override
  String get tgYesDelete => 'Ja, slett';

  @override
  String tgDeletingProgress(int done, int total) {
    return 'Sletter $done/$total …';
  }

  @override
  String tgNowHasFree(String drive, String free) {
    return ' · $drive: har nå $free ledig';
  }

  @override
  String tgDeletedTitles(int count, String extra) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slettet $count titler',
      one: 'Slettet 1 tittel',
    );
    return '$_temp0$extra';
  }

  @override
  String tgDeletedFailed(int count, String failed, String extra) {
    return 'Slettet $count, feilet: $failed$extra';
  }

  @override
  String tgFreeGb(int gb) {
    return 'Frigjør $gb GB';
  }

  @override
  String get tgDownloadCopies => 'Nedlastingskopier';

  @override
  String get tgLookingForUnwatched =>
      'Ser etter det som ikke er sett på lenge …';

  @override
  String tgSuggestionEnough(String size) {
    return 'Forslag: $size · nok plass ✓';
  }

  @override
  String tgSuggestionOf(String size, String target) {
    return 'Forslag: $size av $target som trengs';
  }

  @override
  String get tgPickToSayNo =>
      'Velg en for å si nei — neste forslag kommer inn automatisk.';

  @override
  String get tgOtherCandidates => 'Andre kandidater';

  @override
  String get tgDownloadAnyway => 'Last ned likevel';

  @override
  String tgDeleteCountSize(int count, String size) {
    return 'Slett $count ($size)';
  }

  @override
  String tgDriveHasFreeDot(String drive, String free) {
    return '$drive: har $free ledig.';
  }

  @override
  String tgFileDoubleSpace(String size, String buffer) {
    return 'Filen er $size og tar dobbelt plass (nedlasting + kopi i biblioteket), pluss $buffer i reserve.';
  }

  @override
  String tgFileSize(String size, String buffer) {
    return 'Filen er $size, pluss $buffer i reserve.';
  }

  @override
  String tgPendingNeeds(String size) {
    return 'Pågående nedlastinger trenger $size til.';
  }

  @override
  String tgShortBy(String size) {
    return 'Mangler $size.';
  }

  @override
  String tgOnlyEarlyFiles(int count) {
    return 'Fant bare filer publisert før filmen kom ut digitalt ($count) — de er nesten alltid falske.';
  }

  @override
  String get tgNoDigitalDate => 'har ingen digital utgivelsesdato ennå';

  @override
  String tgDigitalOn(String date) {
    return 'kommer digitalt $date';
  }

  @override
  String get tgNotOutDigitally => 'Ikke ute digitalt ennå';

  @override
  String tgTitleWhen(String title, String when) {
    return '«$title» $when.';
  }

  @override
  String get tgNotOutExplain =>
      'Det som finnes nå, er som regel kinoopptak eller en annen film med samme navn. Av og til finnes en tidlig kopi i lavere kvalitet, gjerne med innbrente undertekster. «Vis filer likevel» viser hva som finnes. Radarr henter den ordentlige versjonen selv når den kommer.';

  @override
  String get tgShowFilesAnyway => 'Vis filer likevel';

  @override
  String get tgPickSeasonsEpisodes => 'Velg sesonger og episoder';

  @override
  String tgNoEpisodeInfo(String season) {
    return '$season: ingen episodeinfo';
  }

  @override
  String get tgAppliesAllDevices =>
      'Gjelder alle enheter som bruker denne kontoen';

  @override
  String get tgNoXxxLibrary => 'Fant ikke noe bibliotek som heter XXX.';

  @override
  String get tgSearchingEachWord =>
      'Søker etter hvert ord for seg … (kan ta et halvt minutt)';

  @override
  String tgSentToQbit(String title, String size) {
    return 'Sendt «$title» ($size) til qBittorrent';
  }

  @override
  String tgDownloadFailed(String error) {
    return 'Nedlasting feilet: $error';
  }

  @override
  String tgXxxNoVideoRemoved(String title) {
    return '«$title» inneholdt ingen videofil og er fjernet.';
  }

  @override
  String tgXxxNoVideoNotRemoved(String title) {
    return '«$title» inneholdt ingen videofil og er IKKE fjernet.';
  }

  @override
  String get tgAdultOffOnServer =>
      'Voksenbiblioteket er slått av på serveren, så det er ingenting å vise eller søke i. En administrator slår det på i Jellyfin i en nettleser: Dashboard > Plugins > Tortugarr > Adult library > Lagre, og kjører så \'sudo tortugarr repair\'.';

  @override
  String get tgSearchNewXxx => 'Søk etter nye XXX';

  @override
  String get tgXxxSearchHint => 'Navn, studio …';

  @override
  String get tgChecking => 'Sjekker …';

  @override
  String get tgXxxVisible =>
      'Synlig nå. XXX vises i bibliotekene, søk og på forsiden.';

  @override
  String get tgXxxHidden => 'Skjult. XXX vises ingen steder i appen.';

  @override
  String get tgShowWithPin => 'Vis (PIN)';

  @override
  String get tgChangePin => 'Endre PIN';

  @override
  String tgNoLibraryList(String code) {
    return 'Fikk ikke bibliotekslisten (HTTP $code)';
  }

  @override
  String tgNoUserSettings(String code) {
    return 'Fikk ikke brukerinnstillingene (HTTP $code)';
  }

  @override
  String tgJellyfinRejectedChange(String code) {
    return 'Jellyfin avviste endringen (HTTP $code)';
  }

  @override
  String tgDeleteFailed(String code) {
    return 'Sletting feilet (HTTP $code)';
  }

  @override
  String tgXxxAddFailed(String title) {
    return 'Fikk ikke lagt «$title» til i qBittorrent';
  }

  @override
  String tgSeasonEpisodeLower(int season, int episode) {
    return 'sesong $season, episode $episode';
  }

  @override
  String get tgSearchInSeerr => 'Søk i Seerr';

  @override
  String get tgSeerrSearchHint =>
      'Søk etter filmer og serier (f.eks. «Lost S02E05»)';

  @override
  String get tgMissingInThisSeason => 'Mangler i denne sesongen';

  @override
  String tgMissingSeasonsOpenSeries(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mangler sesonger',
      one: 'Mangler sesong',
    );
    return '$_temp0 $list - åpne serien for å se alle sesonger';
  }

  @override
  String get tgProjectOnGitHub => 'Tortugarr på GitHub';

  @override
  String get tgProjectOnGitHubSubtitle =>
      'Kildekode, utgivelser og feilmeldinger';

  @override
  String get tgBuiltOnMoonfinCredit =>
      'Tortugarr er bygget på Moonfin (GPL), laget av Moonfin-utviklerne.';

  @override
  String get tgCredits => 'Takk til';

  @override
  String get tgCreditsThanks =>
      'Med ydmyk takk: uten disse prosjektene og menneskene bak dem hadde ikke Tortugarr eksistert.';

  @override
  String get tgAboutProjectTitle => 'Bak seilene';

  @override
  String get tgAboutProjectBody =>
      'Tortugarr ble født av frustrasjon over de kommersielle strømmetjenestene. Letingen etter én samlet alt-i-ett-løsning førte ingen vei, så oppsettet begynte å rulle som en snøball: først Moonfin, så Sonarr, Radarr og resten. Å sy dem sammen og få dem til faktisk å snakke med hverandre var et rent mareritt; det er et lite mirakel at det virket i det hele tatt. Da alt endelig var koblet sammen, ble den første lavinen av feillogger smart nok ignorert en stund.\n\nDet som gjorde utslaget, var den tradisjonelle forespørselsflyten: be om en tittel i Seerr, vente på at en admin godkjenner, og så stole på at noe i bakgrunnen sjekker hvert X. minutt. Å laste ned en torrent manuelt og trykke «Cast til enhet» fra Windows til TV-en ga feilfritt bilde og lyd langt raskere. Men da gikk man glipp av hele poenget.\n\nPoenget var full kontroll i én enkelt app: søke etter titler, slette filer og oppdatere biblioteket i samme sekund som en nedlasting er ferdig, uten å vente på neste sjekk.\n\nIngen dresser, ingen investorer og ingen unødvendige mellomledd. Bygget som en TV-tilpasset fork av Moonfin-Core, med fokus på sømløs lokal automatisering.\n\nKildekode, utgivelser og oppsettguider ligger på GitHub. Fant du en feil? Meld den der. Papegøyen kommer til å kjefte på den.';

  @override
  String get tgCreditMoonfin => 'Appen Tortugarr er bygget på (GPL)';

  @override
  String get tgCreditJellyfin => 'Medieserver';

  @override
  String get tgCreditSeerr => 'Oppdagelse og forespørsler';

  @override
  String get tgCreditRadarr => 'Filmer';

  @override
  String get tgCreditSonarr => 'Serier';

  @override
  String get tgCreditProwlarr => 'Indekseringsstyring';

  @override
  String get tgCreditBazarr => 'Undertekster';

  @override
  String get tgCreditFlareSolverr => 'Cloudflare-hjelper for indekserere';

  @override
  String get tgCreditQbittorrent =>
      'Nedlastingsklient, installasjonens standardvalg';

  @override
  String get tgCreditTmdb => 'Film- og seriedata, plakater og bilder';

  @override
  String get tgCreditOpenSubtitles => 'Undertekster, hentet via Bazarr';

  @override
  String get tgTmdbNotice =>
      'Dette produktet bruker TMDB-API-et, men er ikke godkjent eller sertifisert av TMDB.';

  @override
  String get tgLoadingLogoSize => 'Størrelse på lastelogo';

  @override
  String get tgLoadingLogoSizeSubtitle =>
      'Logoen som snurrer mens en video laster';

  @override
  String get tgDiscoveryLanguages => 'Språk i Trending og Populært';

  @override
  String tgDiscoveryLanguagesSubtitle(String languages) {
    return 'Vises: $languages';
  }

  @override
  String get tgHideForeignOnChosen =>
      'På: Trending og Populært viser bare språkene du har valgt';

  @override
  String get tgShowLanguageBadges => 'Vis språkmerker';

  @override
  String get tgShowLanguageBadgesOn =>
      'På: titlene viser språket sitt (EN, NO, SE …)';

  @override
  String get tgShowLanguageBadgesOff => 'Av: ingen språkmerker på titlene';

  @override
  String tgDeleteMovieMessage(Object title) {
    return 'Slette filmen «$title» og fila?';
  }

  @override
  String tgDeleteSeriesMessage(Object title) {
    return 'Slette HELE serien «$title», alle sesonger og episoder?';
  }

  @override
  String tgDeleteSeasonMessage(int season, Object title) {
    return 'Slette sesong $season av «$title» med alle episodene?';
  }

  @override
  String tgDeleteEpisodeMessage(Object episode, Object title) {
    return 'Slette episode $episode av «$title»?';
  }

  @override
  String get tgTitleGone => 'Denne tittelen finnes ikke lenger i biblioteket.';

  @override
  String get tgTitleGoneBody => 'Den er slettet eller flyttet på serveren.';

  @override
  String get tgCouldNotLoadTitle =>
      'Fikk ikke lastet tittelen. Sjekk at serveren er tilgjengelig.';

  @override
  String get tgShortIntro => 'Kort intro';

  @override
  String get tgShortIntroOn =>
      'På: den korte introen (ca. 4 sekunder) spilles ved oppstart';

  @override
  String get tgShortIntroOff =>
      'Av: hele introen (ca. 10 sekunder) spilles ved oppstart';

  @override
  String get tgShowSdReleases => 'Vis SD-utgivelser';

  @override
  String get tgShowSdReleasesOn =>
      'På: filer i lav kvalitet (SD) vises også, merket som det';

  @override
  String get tgShowSdReleasesOff =>
      'Av: bare 720p og bedre, eller en god kilde';

  @override
  String tgOnlySdFound(int count) {
    return '$count funnet, alle SD (lav kvalitet). Slå på «Vis SD-utgivelser» i Settings for å se dem.';
  }

  @override
  String tgNothingKeptReasons(int count, Object reasons) {
    return '$count funnet, ingen brukbare: $reasons';
  }

  @override
  String get tgDownloadsButton => 'Nedlastinger';

  @override
  String get tgAlwaysShowDownloads => 'Vis alltid nedlastinger til serveren';

  @override
  String get tgAlwaysShowDownloadsSubtitle =>
      'Av: knappen Nedlastinger er bare i menyen mens noe lastes ned';

  @override
  String tgIndexersUnavailable(Object names) {
    return '$names er utilgjengelig nå: bare treff fra de andre indekserne.';
  }

  @override
  String get tgAdultSearchInMenu => 'XXX-søk i menyen';

  @override
  String get tgAdultSearchButton => 'Søk XXX';

  @override
  String get tgLanguageGroup => 'Språk';

  @override
  String get tgLanguageGroupSubtitle =>
      'Appens språk, utenlandske titler og undertekstspråk';

  @override
  String get tgAdminGroupSubtitle =>
      'Jellyfin-adminpanelet, diskplass, XXX og SD-utgivelser';

  @override
  String get tgAdminPanel => 'Jellyfin-adminpanelet';

  @override
  String get tgStartupSection => 'Oppstart';

  @override
  String get tgBrowsingSection => 'Når du blar';

  @override
  String get tgSetupLanguagesQuestion =>
      'Hvilke titler skal Trending og Populært vise?';

  @override
  String get tgSetupLanguagesMine => 'Bare titler på mine språk';

  @override
  String get tgSetupLanguagesAll => 'Alle språk';

  @override
  String get tgSetupLanguagesAllHint => 'Også anime, K-drama og alt annet';

  @override
  String get tgSetupLanguagesLater =>
      'Du kan endre dette når som helst under Innstillinger › Språk.';

  @override
  String get tgDiagReportSent => 'Rapport sendt til serveren';

  @override
  String tgDiagReportSentFile(String fileName) {
    return 'Rapport sendt til serveren: $fileName';
  }

  @override
  String tgDiagSendFailed(String detail) {
    return 'Kunne ikke sende rapport: $detail';
  }

  @override
  String get tgDiagLogsCopied => 'Logger kopiert til utklippstavlen';

  @override
  String get tgDiagEntryCopied => 'Oppføring kopiert til utklippstavlen';

  @override
  String get tgDiagLogsCleared => 'Logger tømt';

  @override
  String get tgDiagAllCategories => 'Alle kategorier';

  @override
  String get tgDiagnosticsLogging => 'Diagnostikk og logging';

  @override
  String get tgLogging => 'Logging';

  @override
  String get tgDiagLoggingTitle => 'Diagnostisk logging';

  @override
  String get tgDiagLoggingSubtitle =>
      'Samle inn media, Seerr-innlogging, nettverk og annen diagnostikk som kan sendes til serveren som en rapport.';

  @override
  String get tgDiagCrashReports => 'Send krasjrapporter til serveren';

  @override
  String get tgDiagCrashReportsSubtitle =>
      'Lagre en rapport når appen krasjer, og send den til din egen server neste gang den kobler til. Ingenting sendes noe annet sted.';

  @override
  String tgDiagReportsCount(int count) {
    return 'Rapporter ($count oppføringer samlet inn)';
  }

  @override
  String get tgDiagReports => 'Rapporter';

  @override
  String get tgDiagSendReport => 'Send rapport til serveren';

  @override
  String get tgDiagCopyAll => 'Kopier alle logger';

  @override
  String get tgDiagCopyAllSubtitle =>
      'Kopier hele rapporten til utklippstavlen.';

  @override
  String get tgDiagClearLogs => 'Tøm innsamlede logger';

  @override
  String get tgDiagClearLogsSubtitle => 'Forkast alt i gjeldende buffer.';

  @override
  String get tgDiagRecentLogs => 'Nylige logger';

  @override
  String tgDiagRecentLogsCount(int shown, int total) {
    return 'Nylige logger ($shown av $total)';
  }

  @override
  String get tgFilter => 'Filter';

  @override
  String get tgDiagEnableFirst => 'Slå på diagnostisk logging først.';

  @override
  String get tgDiagNoEntriesYet => 'Ingen oppføringer samlet inn ennå.';

  @override
  String get tgDiagUploadSubtitle =>
      'Last opp de innsamlede loggene til den aktive serveren.';

  @override
  String tgDiagEmptyFiltered(String category, int total) {
    return 'Ingen oppføringer for $category. $total samlet inn i andre kategorier. Trykk Filter for å endre.';
  }

  @override
  String get tgDiagEmptyEnabled =>
      'Ingen loggoppføringer ennå. Gjenskap feilen, og send så en rapport.';

  @override
  String get tgDiagEmptyOff =>
      'Logging er av. Slå den på, gjenskap feilen, og send så en rapport til serveren.';

  @override
  String get tgLogCatMedia => 'Media';

  @override
  String get tgLogCatSeerr => 'Seerr-innlogging';

  @override
  String get tgLogCatSync => 'Synkronisering';

  @override
  String get tgLogCatArtwork => 'Bilder';

  @override
  String get tgCoreNotDownloaded => 'Denne kjernen er ikke lastet ned ennå.';

  @override
  String get tgCoreSettingsUnreadable =>
      'Innstillingene for denne kjernen kan ikke leses på denne enheten. Du kan fortsatt tilbakestille dem til standard nedenfor.';

  @override
  String get tgCoreSettingsReadFailed =>
      'Kunne ikke lese innstillingene for denne kjernen.';

  @override
  String get tgCoreSettingsSaveFailed =>
      'Kunne ikke lagre disse innstillingene.';

  @override
  String get tgCoreSettingsResetDone =>
      'Innstillingene er tilbakestilt til standard.';

  @override
  String get tgCoreSettingsResetFailed =>
      'Kunne ikke tilbakestille disse innstillingene.';

  @override
  String tgCoreSettingsTitle(String system) {
    return 'Innstillinger for $system';
  }

  @override
  String get tgCoreSettingsWarning =>
      'Dette er emulatorkjernens egne innstillinger. Noen kombinasjoner kan hindre et spill i å starte, eller lukke appen mens det kjører. Hvis noe går galt, bruk Tilbakestill til standard nedenfor.';

  @override
  String get tgAudioRedetect => 'Finn lyd på nytt og bruk anbefalt';

  @override
  String get tgAudioRedetectSubtitle =>
      'Kjør lydgjenkjenning på nytt og tilbakestill til anbefalte innstillinger.';

  @override
  String tgAudioRedetected(String route) {
    return 'Lyd funnet på nytt: $route';
  }

  @override
  String get tgAudioStream => 'Lydspor';

  @override
  String get tgAudioOutput => 'Lydutgang';

  @override
  String get tgPassthroughSettings => 'Passthrough-innstillinger';

  @override
  String get tgAdvanced => 'Avansert';

  @override
  String get tgDecodingRendering => 'Dekoding og visning';

  @override
  String get tgAboutDiagnosticsSubtitle =>
      'Samle inn media-, innloggings- og nettverkslogger og send dem til serveren som en rapport';

  @override
  String get tgRewatch => 'Se igjen';

  @override
  String get tgDisplayRewatchRow => 'Vis Se igjen-raden';

  @override
  String get tgDisplayRewatchRowSubtitle =>
      'Vis Se igjen-raden i Hjem-seksjonene';

  @override
  String get tgRewatchSortDescription =>
      'Velg sortering for fullførte elementer';

  @override
  String get tgIncludeMovies => 'Ta med filmer';

  @override
  String get tgRewatchIncludeMoviesSubtitle =>
      'Vis sette filmer i Se igjen-raden';

  @override
  String get tgIncludeShows => 'Ta med serier';

  @override
  String get tgRewatchIncludeShowsSubtitle =>
      'Vis sette TV-serier i Se igjen-raden';

  @override
  String get tgIncludeCollections => 'Ta med samlinger';

  @override
  String get tgRewatchIncludeCollectionsSubtitle =>
      'Vis sette samlinger i Se igjen-raden';

  @override
  String get tgSinceYouWatched => 'Fordi du så';

  @override
  String get tgDisplaySinceYouWatchedRows => 'Vis Fordi du så-rader';

  @override
  String get tgDisplaySinceYouWatchedRowsSubtitle =>
      'Vis og tilpass Fordi du så-rader i Hjem-seksjonene.';

  @override
  String get tgRecommendationSource => 'Kilde for anbefalinger';

  @override
  String get tgRecommendationSourceDescription =>
      'Velg kilde for anbefalinger (Tortugarr anbefaler med egen lokal algoritme, Jellyfin anbefaler med servermotoren, eller TMDbs likhetsmål. Merk: Anbefalinger på nett krever Seerr-integrasjon).';

  @override
  String get tgSourceType => 'Kildetype';

  @override
  String get tgSourceTypeDescription =>
      'Velg hvilken type elementer som skal anbefales';

  @override
  String get tgSourceItem => 'Kildeelement';

  @override
  String get tgSourceItemDescription =>
      'Velg hvilket element anbefalingene skal bygge på';

  @override
  String get tgNumberOfRowsToAdd => 'Antall rader';

  @override
  String get tgNumberOfRowsToAddDescription =>
      'Velg hvor mange Fordi du så-rader som skal vises (1–5)';

  @override
  String get tgIncludePreviouslyWatched => 'Ta med tidligere sett';

  @override
  String get tgIncludePreviouslyWatchedSubtitle =>
      'Ta med sette elementer i anbefalingene';

  @override
  String tgErrorLoadingStudios(String error) {
    return 'Feil ved lasting av studioer: $error';
  }

  @override
  String get tgNoStudiosFound => 'Fant ingen studioer i biblioteket.';

  @override
  String get tgFavoriteMovies => 'Favorittfilmer';

  @override
  String get tgFavoriteSeries => 'Favorittserier';

  @override
  String get tgFavoriteEpisodes => 'Favorittepisoder';

  @override
  String get tgFavoritePeople => 'Favorittpersoner';

  @override
  String get tgFavoriteArtists => 'Favorittartister';

  @override
  String get tgFavoriteMusicVideos => 'Favorittmusikkvideoer';

  @override
  String get tgFavoriteAlbums => 'Favorittalbum';

  @override
  String get tgFavoriteSongs => 'Favorittsanger';

  @override
  String get tgRowUpcomingMoviesRadarr => 'Kommende filmer (Radarr)';

  @override
  String get tgRowUpcomingTvSonarr => 'Kommende TV-serier (Sonarr)';

  @override
  String get tgRowTopRatedMovies => 'Best rangerte filmer';

  @override
  String get tgRowNowPlayingMovies => 'På kino nå';

  @override
  String get tgRowPopularTv => 'Populære TV-serier';

  @override
  String get tgRowTopRatedTv => 'Best rangerte TV-serier';

  @override
  String get tgRowAiringTodayTv => 'Sendes i dag';

  @override
  String get tgRowOnTheAirTv => 'Går på TV nå';

  @override
  String get tgRowTrendingMoviesDaily => 'Trendende filmer (i dag)';

  @override
  String get tgRowTrendingMoviesWeekly => 'Trendende filmer (denne uken)';

  @override
  String get tgRowTrendingTvDaily => 'Trendende TV (i dag)';

  @override
  String get tgRowTrendingTvWeekly => 'Trendende TV (denne uken)';

  @override
  String get tgRowTrendingAllWeekly => 'Alt som trender (denne uken)';

  @override
  String tgRowSinceYouWatchedNumber(int number) {
    return 'Fordi du så – rad $number';
  }

  @override
  String get tgRowSinceYouWatched => 'Fordi du så';

  @override
  String get tgRowUpcomingReleases => 'Kommende utgivelser';

  @override
  String get tgReleaseCinema => 'Kino';

  @override
  String get tgReleaseDigital => 'Digitalt';

  @override
  String get tgReleasePhysical => 'Fysisk';

  @override
  String tgReleaseOnDate(String type, String date) {
    return '$type: $date';
  }

  @override
  String tgNextEpisodeDateCode(String date, String code) {
    return 'Neste episode: $date ($code)';
  }

  @override
  String tgNextEpisodeDate(String date) {
    return 'Neste episode: $date';
  }

  @override
  String tgNextEpisodeCode(String code) {
    return 'Neste episode: ($code)';
  }

  @override
  String get tgAudioRow => 'Lydrad';

  @override
  String get tgImdbList => 'IMDb-liste';

  @override
  String get tgTmdbLists => 'TMDB-lister';

  @override
  String tgCollectionsRowFrom(String server) {
    return 'Samlingsrad fra $server';
  }

  @override
  String get tgCollectionsRow => 'Samlingsrad';

  @override
  String get tgGenresRow => 'Sjangerrad';

  @override
  String get tgPlaylistsRow => 'Spillelisterad';

  @override
  String get tgCustomList => 'Egen liste';

  @override
  String get tgWatchlistLabel => 'Se senere';

  @override
  String get tgFilms => 'Filmer';

  @override
  String get tgAwardsEvents => 'Priser/arrangementer';

  @override
  String get tgMovieCollectionTitle => 'Filmsamling';

  @override
  String tgFetchingList(String title) {
    return 'Henter $title';
  }

  @override
  String get tgDownloadingFromMoonbase =>
      'Laster ned listen fra Moonbase og lagrer den lokalt …';

  @override
  String tgFetchFromMoonbaseFailed(String title, String error) {
    return 'Kunne ikke hente $title fra Moonbase: $error';
  }

  @override
  String get tgUpcomingCalendars => 'Utgivelseskalendere';

  @override
  String get tgEnableRadarrCalendar => 'Slå på Radarr-kalenderen';

  @override
  String get tgShowCinemaReleases => 'Vis kommende kinopremierer';

  @override
  String get tgShowDigitalReleases => 'Vis kommende digitale utgivelser';

  @override
  String get tgShowPhysicalReleases => 'Vis kommende fysiske utgivelser';

  @override
  String get tgShowReleaseDateOnHome => 'Vis utgivelsesdato på Hjem';

  @override
  String get tgEnableSonarrCalendar => 'Slå på Sonarr-kalenderen';

  @override
  String get tgDisplayEpisodeInfo => 'Vis episodeinformasjon';

  @override
  String get tgMergeCalendars => 'Slå sammen Sonarr- og Radarr-kalenderne';

  @override
  String get tgSeerrRows => 'Seerr-rader';

  @override
  String get tgSeerrHomePageRows => 'Seerr-rader på Hjem';

  @override
  String get tgDeleteCustomRow => 'Slett egen rad';

  @override
  String tgDeleteCustomRowConfirm(String name) {
    return 'Er du sikker på at du vil slette «$name»?';
  }

  @override
  String get tgListLabel => 'Liste';

  @override
  String get tgListFromUserId => 'Liste fra bruker-ID';

  @override
  String get tgListFromUrl => 'Liste fra URL';

  @override
  String get tgDiary => 'Dagbok';

  @override
  String get tgCompleteFilms => 'Alle filmer';

  @override
  String get tgListFromTmdbIdOrUrl => 'Liste fra TMDB-liste-ID eller URL';

  @override
  String get tgCollectionFromTmdbIdOrUrl =>
      'Samling fra TMDB-samlings-ID eller URL';

  @override
  String get tgCustomRows => 'Egne rader';

  @override
  String get tgAddNewCustomHomeRow => 'Legg til en ny egen rad på Hjem';

  @override
  String get tgAddCustomRowSubtitle =>
      'Lag en egen rad fra TMDB, Letterboxd eller MDBList.';

  @override
  String get tgSavedCustomHomeRows => 'Lagrede egne rader på Hjem';

  @override
  String get tgCustomRow => 'Egen rad';

  @override
  String tgCustomRowSourceType(String source, String type) {
    return 'Kilde: $source | Type: $type';
  }

  @override
  String get tgDiscardChanges => 'Forkaste endringene?';

  @override
  String get tgDiscardChangesWizard =>
      'Endringene er ikke lagret. Vil du avslutte veiviseren?';

  @override
  String get tgCustomRowValidationFailed =>
      'Advarsel: Kontroll av egen rad mislyktes';

  @override
  String get tgCustomRowFetchFailed =>
      'Kunne ikke hente elementer til den egne raden.';

  @override
  String tgErrorDetails(String error) {
    return 'Feildetaljer: $error';
  }

  @override
  String get tgEditCustomHomeRow => 'Rediger egen rad på Hjem';

  @override
  String get tgAddCustomHomeRow => 'Legg til egen rad på Hjem';

  @override
  String get tgSourceLabel => 'Kilde';

  @override
  String get tgLetterboxdUsername => 'Letterboxd-brukernavn';

  @override
  String get tgLetterboxdTmdbWarning =>
      'ADVARSEL: En TMDB API-nøkkel må settes opp i innstillingene for å finne elementene i Letterboxd-lister.';

  @override
  String get tgTmdbCollectionIdOrUrl => 'TMDB-samlings-ID eller URL';

  @override
  String get tgTmdbListIdOrUrl => 'TMDB-liste-ID eller URL';

  @override
  String get tgTmdbCollectionHint =>
      '12345 ELLER https://www.themoviedb.org/collection/12345';

  @override
  String get tgTmdbListHint =>
      '12345 ELLER https://www.themoviedb.org/list/12345';

  @override
  String get tgTmdbApiKeyWarning =>
      'ADVARSEL: En TMDB API-nøkkel må settes opp i innstillingene for å hente TMDB-lister.';

  @override
  String get tgMdblistUsername => 'MDBList-brukernavn';

  @override
  String get tgMdblistUrlHint =>
      'f.eks. https://mdblist.com/lists/username/list-slug';

  @override
  String get tgListNameSlug => 'Listenavn (slug)';

  @override
  String get tgMdblistApiKeyWarning =>
      'ADVARSEL: En MDBList API-nøkkel må settes opp i innstillingene (eller for hele serveren av administratoren) for å hente MDBList-lister.';

  @override
  String get tgSortOrder => 'Sorteringsrekkefølge';

  @override
  String get tgSortDefaultWhenAdded => 'Standard (når lagt til)';

  @override
  String get tgSortFilmName => 'Filmnavn';

  @override
  String get tgSortFilmPopularity => 'Filmens popularitet';

  @override
  String get tgSortAverageRating => 'Gjennomsnittlig vurdering';

  @override
  String get tgAToZ => 'A til Å';

  @override
  String get tgZToA => 'Å til A';

  @override
  String get tgNewestFirst => 'Nyeste først';

  @override
  String get tgEarliestFirst => 'Eldste først';

  @override
  String get tgMostPopularFirst => 'Mest populære først';

  @override
  String get tgLeastPopularFirst => 'Minst populære først';

  @override
  String get tgHighestFirst => 'Høyeste først';

  @override
  String get tgLowestFirst => 'Laveste først';

  @override
  String get tgShowUserRatings => 'Vise brukervurderinger?';

  @override
  String get tgHomeRowCustomName => 'Eget navn på raden';

  @override
  String get tgEnterRowName => 'Skriv inn radnavn …';

  @override
  String get tgRefreshingCustomRows => 'Oppdaterer egne rader';

  @override
  String get tgRefreshingCustomRowsBody =>
      'Oppdaterer de egne radene og hurtigbufferne deres …';

  @override
  String get tgRefreshedCustomRows => 'De egne radene er oppdatert.';

  @override
  String tgRefreshCustomRowsFailed(String error) {
    return 'Kunne ikke oppdatere egne rader: $error';
  }

  @override
  String get tgImdbLists => 'IMDb-lister';

  @override
  String get tgImdbListsSubtitle =>
      'Sett opp IMDb Topp 250, Populære og andre lister.';

  @override
  String get tgTmdbListsSubtitle =>
      'Sett opp TMDB-listene Populære, Best rangerte og Trendende.';

  @override
  String get tgTmdbApiKeyRequired =>
      'En TMDB API-nøkkel må settes opp i Moonbase-innstillingene for å bruke denne funksjonen.';

  @override
  String get tgUpcomingCalendarsSubtitle =>
      'Slå utgivelseskalendere fra Radarr/Sonarr av eller på.';

  @override
  String get tgSeerrRowsSubtitle => 'Sett opp Seerr-oppdagelsesrader.';

  @override
  String get tgCustomRowsSubtitle =>
      'AVANSERT: Sett opp egne rader på Hjem fra ulike kilder.';

  @override
  String get tgMediaTypeBadges => 'Merker for medietype';

  @override
  String get tgMediaTypeBadgesDescription =>
      'Vis FILM / SERIE-merker på kort fra eksterne rader på Hjem';

  @override
  String get tgRefreshCustomRows => 'Oppdater egne rader';

  @override
  String get tgRefreshCustomRowsSubtitle =>
      'Tving en full oppdatering av hurtigbufferne for egne rader.';

  @override
  String get tgStillWatchingDescription =>
      'Spør om du vil fortsette å se etter et antall episoder på rad.';

  @override
  String tgEpisodeCount(int count) {
    return '$count episoder';
  }

  @override
  String get tgSyncPlayOptions => 'SyncPlay-valg';

  @override
  String get tgActiveSessions => 'Aktive økter';

  @override
  String get tgOpenInExternalPlayer => 'Åpne i ekstern spiller';

  @override
  String get tgTranscodeHigh => 'Omkod strømmen: Høy kvalitet (1080p)';

  @override
  String get tgTranscodeMedium => 'Omkod strømmen: Middels kvalitet (720p)';

  @override
  String get tgTranscodeLow => 'Omkod strømmen: Lav kvalitet (480p)';

  @override
  String get tgAdvancedPlayback => 'Avansert avspilling';

  @override
  String get tgDownloadNow => 'Last ned nå';

  @override
  String tgNotFoundOnDownloadService(String title) {
    return 'Fant ikke «$title» i nedlastingstjenesten';
  }

  @override
  String get tgSearchingReleases => 'Søker etter utgivelser …';

  @override
  String tgSendingToDownloadClient(String title) {
    return 'Sender «$title» til nedlastingsklienten …';
  }

  @override
  String tgSentToQbittorrent(String title, String size) {
    return 'Sendte «$title» ($size) til qBittorrent';
  }

  @override
  String tgNoTvdbIdForTitle(String title) {
    return '«$title» har ingen TVDB-id og kan derfor ikke lastes ned her';
  }

  @override
  String get tgWorking => 'Jobber …';

  @override
  String tgDownloadingTitle(String title, String size) {
    return 'Laster ned «$title» ($size)';
  }

  @override
  String tgCountTooEarly(int count) {
    return '$count for tidlig';
  }

  @override
  String get tgNoReleasesFound => 'Fant ingen utgivelser';

  @override
  String get tgPluginNotAdmin =>
      'Bare administratorer kan laste ned på denne serveren';

  @override
  String get tgPluginFeatureOff => 'Nedlastinger er slått av på denne serveren';

  @override
  String get tgPluginNotConfigured =>
      'Serveren er ikke satt opp for nedlastinger ennå';

  @override
  String get tgPluginSearchExpired => 'Søket er for gammelt, søk på nytt';

  @override
  String get tgPluginTimeout => 'Søket tok for lang tid, prøv igjen';

  @override
  String tgPluginNoIndexers(String detail) {
    return 'Ingen søkekilder er aktive på serveren$detail. Sjekk indekserne i Prowlarr. Feiler testen til en indekser med en Cloudflare-feil (1337x og andre)? Skriv flaresolverr under Tags nederst i innstillingene dens, og test på nytt.';
  }

  @override
  String get tgAlreadyDownloaded =>
      'Allerede lastet ned: nedlastingsklienten har denne filen fra før';

  @override
  String tgAlreadyDownloadingPercent(int percent) {
    return 'Lastes allerede ned ($percent %)';
  }

  @override
  String get tgNoReasonGiven => 'Ingen grunn oppgitt';

  @override
  String get tgDownloadAnywayQuestion => 'Laste ned likevel?';

  @override
  String tgServerWouldNotPick(String reasons) {
    return 'Serveren ville ikke valgt denne filen selv:\n$reasons';
  }

  @override
  String get tgNoReleasesOnProwlarr => 'Fant ingen utgivelser i Prowlarr';

  @override
  String tgChooseFileResults(int count) {
    return 'Velg fil ($count treff)';
  }

  @override
  String tgChooseFileResultsNote(int count, String note) {
    return 'Velg fil ($count treff) · $note';
  }

  @override
  String get tgSdLowQuality => 'SD · lav kvalitet';

  @override
  String tgSeedersCount(int count) {
    return '$count delere';
  }

  @override
  String get tgTierAll => 'alle';

  @override
  String get tgTierOther => 'andre';

  @override
  String tgSearchingReleasesElapsed(String elapsed) {
    return 'Søker etter utgivelser … $elapsed';
  }

  @override
  String get tgSearchSlowIndexerNote =>
      'Serveren spør alle indekserne. En treg en (for eksempel bak Cloudflare) kan gjøre at dette tar noen minutter.';

  @override
  String tgSeerrActiveCount(int count) {
    return 'Seerr · $count aktive';
  }

  @override
  String get tgRefreshJellyfinLibrary => 'Oppdater Jellyfin-biblioteket';

  @override
  String tgMoreCount(int count) {
    return '+ $count til';
  }

  @override
  String tgSortLabel(String value) {
    return 'Sortering: $value';
  }

  @override
  String tgFilterLabel(String value) {
    return 'Filter: $value';
  }

  @override
  String tgCountOfTotal(int count, int total) {
    return '$count av $total';
  }

  @override
  String get tgEndOfTrack => 'Slutten av sporet';

  @override
  String get tgSaveQueueAsPlaylist => 'Lagre køen som spilleliste';

  @override
  String tgSavedName(String name) {
    return 'Lagret «$name»';
  }

  @override
  String tgSavePlaylistFailed(String error) {
    return 'Kunne ikke lagre spillelisten: $error';
  }

  @override
  String get tgMyPlaylist => 'Min spilleliste';

  @override
  String get tgSoundSystem => 'Lydanlegg';

  @override
  String get tgSoundSystemLink => 'Forsterker og passthrough';

  @override
  String get tgSoundSystemLinkSubtitle =>
      'Dolby, DTS og Atmos til forsterkeren, nattmodus';

  @override
  String get tgShowSavedDownloadsSubtitle =>
      'Filmer og episoder lagret på denne enheten, til å se uten internett';

  @override
  String get tgPlayerMenu => 'Avspiller';

  @override
  String get tgPlayerAutomatic => 'Automatisk (anbefalt)';

  @override
  String tgPlayerAutomaticNow(String engine, String reason) {
    return 'Nå: $engine – $reason';
  }

  @override
  String get tgAutoReasonTitle => 'valgt for denne tittelen';

  @override
  String get tgAutoReasonSetting => 'fra Innstillinger';

  @override
  String get tgAutoReasonBluetooth => 'Bluetooth-lyd';

  @override
  String get tgAutoReasonLearned => 'virket best med denne filtypen før';

  @override
  String get tgAutoReasonHeavy => '4K-, HDR- eller HEVC-fil';

  @override
  String get tgAutoReasonLight => 'vanlig 1080p-fil';

  @override
  String get tgPlayerMedia3Hint => 'TV-ens egen videospiller';

  @override
  String get tgPlayerMedia3Tunneling => 'Media3 + tunneling';

  @override
  String get tgPlayerMedia3TunnelingHint => 'For 4K-filmer som hakker';

  @override
  String get tgPlayerMpvHint => 'Jevn takt for vanlige filmer';

  @override
  String tgAutoPlayerSwitching(String engine) {
    return 'Avspillingen hakker – bytter til $engine';
  }

  @override
  String get tgAutoPlayerTitle => 'Automatisk avspiller';

  @override
  String get tgAutoPlayerSubtitle =>
      'Velger Media3 eller mpv for hver film, bytter hvis det hakker og husker hva som virket. Endre per film med Avspiller-knappen i avspilleren.';

  @override
  String get tgAutoReasonStutter => 'byttet etter hakking';
}
