export const EXAMPLE_CASE = {
  "title": "Zamknięty antykwariat",
  "docket": "RSD 114/25",
  "place": "Toruń",
  "date": "3 marca 2025",
  "brief": [
    "W poniedziałek o 8:10 Paweł Rudnik, asystent antykwariatu „Pod Wagą” przy ul. Szerokiej w Toruniu, zgłosił śmierć właściciela. Edward Malicki (67 l.) leżał na zapleczu z raną tłuczoną głowy. Sejf był otwarty.",
    "Zniknęła kolekcja dziewiętnastowiecznych zegarków kieszonkowych, wyceniona przez ubezpieczyciela na 180 tys. zł. Malicki mieszkał sam, w mieszkaniu nad sklepem. W niedzielę antykwariat był zamknięty dla klientów."
  ],
  "suspects": [
    {
      "id": "kinga",
      "name": "Kinga Malicka",
      "age": 34,
      "role": "bratanica, jedyna spadkobierczyni",
      "statement": [
        "Wujek dzwonił do mnie w niedzielę wieczorem, chyba przed ósmą. Pytał, czy przyjadę na jego urodziny. O dwudziestej byłam już w kinie w Bydgoszczy, seans trwał do 22:10. Bilet mam w telefonie.",
        "Wiem, jak to wygląda. Dziedziczę wszystko. Ale ja nawet nie mam kluczy do sklepu."
      ]
    },
    {
      "id": "pawel",
      "name": "Paweł Rudnik",
      "age": 29,
      "role": "asystent w antykwariacie od sześciu lat",
      "statement": [
        "W niedzielę w ogóle nie byłem na Starówce. Siedziałem w domu i grałem na konsoli, sam.",
        "Rano przyszedłem jak zwykle. Drzwi były zamknięte na klucz, otworzyłem swoim. Klucze mamy tylko my dwaj, pan Edward był na tym punkcie przewrażliwiony. Ktoś musiał wejść przez okno albo pan Edward sam kogoś wpuścił."
      ]
    },
    {
      "id": "igor",
      "name": "Igor Sawa",
      "age": 52,
      "role": "kolekcjoner z Gdańska",
      "statement": [
        "Tak, kłóciliśmy się w zeszłym miesiącu o Patka Philippe, którego mi sprzedał. Twierdziłem, że ma wymieniony mechanizm.",
        "Ale w niedzielę o wpół do dziesiątej rozmawialiśmy już spokojnie przez telefon. Umówiliśmy się na poniedziałek, miał mi oddać część pieniędzy. Dzwoniłem z domu, z Gdańska. Potem poszedłem spać."
      ]
    }
  ],
  "evidence": [
    {
      "id": "e1",
      "title": "Protokół oględzin",
      "text": "Drzwi wejściowe zamknięte na zamek wpuszczany. Okna zamknięte od wewnątrz, bez śladów podważenia. Klucz ofiary w kieszeni marynarki. Sejf otwarty kluczem, nie siłą. Klucz do sejfu ofiara trzymała w szufladzie biurka na zapleczu.",
      "hint": false
    },
    {
      "id": "e2",
      "title": "Opinia medyka sądowego",
      "text": "Zgon w niedzielę między 21:00 a 23:00. Jedno uderzenie ciężkim, tępym narzędziem w tył głowy. Brak śladów obrony.",
      "hint": false
    },
    {
      "id": "e3",
      "title": "Billing telefonu stacjonarnego antykwariatu",
      "text": "Niedziela, 19:52: połączenie wychodzące do Kingi Malickiej (3 min 40 s). 21:31: połączenie przychodzące z numeru stacjonarnego Igora Sawy w Gdańsku (6 min 12 s).",
      "hint": false
    },
    {
      "id": "e4",
      "title": "Zeznanie ślusarza",
      "text": "Zamek wymieniałem w 2019 roku. Pan Malicki zamówił dwa klucze: jeden dla siebie, drugi dla pracownika. To system z kartą kodową, bez karty nikt nie dorobi kopii.",
      "hint": false
    },
    {
      "id": "e5",
      "title": "Monitoring miejski, ul. Szeroka",
      "text": "22:47. Mężczyzna w kapturze, z plecakiem, wychodzi z bramy antykwariatu i zamyka drzwi kluczem. Twarzy nie widać.",
      "hint": true
    },
    {
      "id": "e6",
      "title": "Sytuacja finansowa asystenta",
      "text": "W piątek bank odrzucił wniosek Pawła Rudnika o pożyczkę 40 000 zł. W aplikacji bukmacherskiej saldo przegranych z ostatniego roku: 41 300 zł.",
      "hint": true
    }
  ],
  "motives": [
    {
      "id": "spadek",
      "label": "Spadek po wuju"
    },
    {
      "id": "dlugi",
      "label": "Długi hazardowe"
    },
    {
      "id": "patek",
      "label": "Spór o podrobiony zegarek"
    },
    {
      "id": "zwolnienie",
      "label": "Zemsta za zwolnienie z pracy"
    }
  ],
  "deduction": [
    {
      "uses": ["e1"],
      "conclusion": "Drzwi zamknięto od zewnątrz kluczem, a klucz ofiary został w jej kieszeni: sprawca miał drugi klucz."
    },
    {
      "uses": ["e4", "pawel"],
      "conclusion": "Istniały tylko dwa klucze i nie da się ich dorobić. Drugi miał Paweł Rudnik, który kłamie o oknie i wpuszczonym gościu."
    }
  ],
  "false_leads": [
    {
      "suspect_id": "kinga",
      "points_to_them": ["kinga"],
      "cleared_by": ["e4", "e1"]
    }
  ],
  "solution": {
    "culprit": "pawel",
    "motive": "dlugi",
    "evidence": [
      "e1",
      "e4"
    ],
    "explain": [
      "Drzwi były zamknięte na klucz, a klucz ofiary leżał w jej kieszeni. Okna były nienaruszone. Ktokolwiek wyszedł z antykwariatu po zabójstwie, zamknął drzwi drugim kluczem.",
      "Ślusarz potwierdza, że istniały tylko dwa klucze i bez karty kodowej nie da się dorobić kopii. Drugi klucz miał Paweł Rudnik. Jego wersja o oknie albo wpuszczonym gościu nie trzyma się protokołu oględzin.",
      "Kinga ma bilet do kina i nie ma klucza. Igor Sawa o 21:31 dzwonił ze swojego stacjonarnego telefonu w Gdańsku, a nawet gdyby zdążył dojechać, nie zamknąłby drzwi. Rudnik tonął w długach u bukmachera, a bank w piątek odmówił mu pożyczki."
    ]
  },
  "innocence_check": [
    {
      "suspect_id": "kinga",
      "excluded_by": [
        "e4",
        "e1"
      ],
      "reason": "Nie ma klucza (ślusarz: tylko dwa klucze), a drzwi zamknięto od zewnątrz."
    },
    {
      "suspect_id": "igor",
      "excluded_by": [
        "e3",
        "e1",
        "e4"
      ],
      "reason": "O 21:31 dzwonił z Gdańska; nie miał klucza, którym zamknięto drzwi."
    }
  ]
};
