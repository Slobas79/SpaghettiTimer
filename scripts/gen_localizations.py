#!/usr/bin/env python3
"""Generates the String Catalogs for SpaghettiTimer.

Run from the repo root:  python3 scripts/gen_localizations.py

Emits:
  SpaghettiTimer/Localizable.xcstrings        (main app + shared AppIntents)
  SpaghettiTimerWidget/Localizable.xcstrings   (widget UI + shared AppIntents)
  SpaghettiTimer/InfoPlist.xcstrings           (AlarmKit usage description)

Source language is English; the key itself is the English value, so no "en"
localization entries are written.
"""

import json
import os

# Target language codes (order is cosmetic).
LANGS = [
    "ar", "bg", "cs", "da", "de", "el", "es", "fi", "fr", "hu", "it", "ja",
    "nb", "nl", "pl", "pt-PT", "ro", "ru", "sk", "sl", "sr", "sv",
]

# key -> {lang: value}
T = {
    "New Timer": {
        "ar": "مؤقّت جديد", "bg": "Нов таймер", "cs": "Nový časovač", "da": "Ny timer",
        "de": "Neuer Timer", "el": "Νέο χρονόμετρο", "es": "Nuevo temporizador",
        "fi": "Uusi ajastin", "fr": "Nouveau minuteur", "hu": "Új időzítő",
        "it": "Nuovo timer", "ja": "新しいタイマー", "nb": "Ny tidtaker", "nl": "Nieuwe timer",
        "pl": "Nowy minutnik", "pt-PT": "Novo temporizador", "ro": "Temporizator nou",
        "ru": "Новый таймер", "sk": "Nový časovač", "sl": "Nov časovnik",
        "sr": "Нови тајмер", "sv": "Ny timer",
    },
    "Cancel": {
        "ar": "إلغاء", "bg": "Отказ", "cs": "Zrušit", "da": "Annuller", "de": "Abbrechen",
        "el": "Άκυρο", "es": "Cancelar", "fi": "Peruuta", "fr": "Annuler", "hu": "Mégse",
        "it": "Annulla", "ja": "キャンセル", "nb": "Avbryt", "nl": "Annuleer", "pl": "Anuluj",
        "pt-PT": "Cancelar", "ro": "Anulează", "ru": "Отменить", "sk": "Zrušiť",
        "sl": "Prekliči", "sr": "Откажи", "sv": "Avbryt",
    },
    "Start": {
        "ar": "ابدأ", "bg": "Старт", "cs": "Spustit", "da": "Start", "de": "Starten",
        "el": "Έναρξη", "es": "Iniciar", "fi": "Aloita", "fr": "Démarrer", "hu": "Indítás",
        "it": "Avvia", "ja": "開始", "nb": "Start", "nl": "Start", "pl": "Start",
        "pt-PT": "Iniciar", "ro": "Pornește", "ru": "Старт", "sk": "Spustiť",
        "sl": "Začni", "sr": "Покрени", "sv": "Starta",
    },
    "Name": {
        "ar": "الاسم", "bg": "Име", "cs": "Název", "da": "Navn", "de": "Name",
        "el": "Όνομα", "es": "Nombre", "fi": "Nimi", "fr": "Nom", "hu": "Név",
        "it": "Nome", "ja": "名前", "nb": "Navn", "nl": "Naam", "pl": "Nazwa",
        "pt-PT": "Nome", "ro": "Nume", "ru": "Название", "sk": "Názov",
        "sl": "Ime", "sr": "Назив", "sv": "Namn",
    },
    "Duration": {
        "ar": "المدة", "bg": "Продължителност", "cs": "Trvání", "da": "Varighed",
        "de": "Dauer", "el": "Διάρκεια", "es": "Duración", "fi": "Kesto", "fr": "Durée",
        "hu": "Időtartam", "it": "Durata", "ja": "継続時間", "nb": "Varighet",
        "nl": "Duur", "pl": "Czas trwania", "pt-PT": "Duração", "ro": "Durată",
        "ru": "Длительность", "sk": "Trvanie", "sl": "Trajanje", "sr": "Трајање",
        "sv": "Varaktighet",
    },
    "Options": {
        "ar": "خيارات", "bg": "Опции", "cs": "Možnosti", "da": "Valg", "de": "Optionen",
        "el": "Επιλογές", "es": "Opciones", "fi": "Valinnat", "fr": "Options",
        "hu": "Beállítások", "it": "Opzioni", "ja": "オプション", "nb": "Valg", "nl": "Opties",
        "pl": "Opcje", "pt-PT": "Opções", "ro": "Opțiuni", "ru": "Параметры",
        "sk": "Možnosti", "sl": "Možnosti", "sr": "Опције", "sv": "Alternativ",
    },
    "Auto-restart after finish": {
        "ar": "إعادة التشغيل تلقائيًا بعد الانتهاء", "bg": "Рестартиране след край",
        "cs": "Restartovat po dokončení", "da": "Genstart efter afslutning",
        "de": "Nach Ablauf neu starten", "el": "Αυτόματη επανεκκίνηση μετά τη λήξη",
        "es": "Reiniciar al terminar", "fi": "Käynnistä uudelleen lopetuksen jälkeen",
        "fr": "Redémarrer après la fin", "hu": "Újraindítás befejezés után",
        "it": "Riavvia al termine", "ja": "終了後に自動で再開",
        "nb": "Start på nytt etter fullføring", "nl": "Opnieuw starten na afloop",
        "pl": "Restart po zakończeniu", "pt-PT": "Reiniciar após terminar",
        "ro": "Repornește după finalizare", "ru": "Перезапуск после завершения",
        "sk": "Reštartovať po dokončení", "sl": "Samodejni vnovični zagon po koncu",
        "sr": "Аутоматско поновно покретање по завршетку", "sv": "Starta om efter slut",
    },
    "Re-run this timer automatically after a cooldown delay.": {
        "ar": "إعادة تشغيل هذا المؤقّت تلقائيًا بعد فترة توقّف.",
        "bg": "Автоматично рестартиране на този таймер след пауза.",
        "cs": "Po prodlevě tento časovač automaticky spustí znovu.",
        "da": "Kør denne timer automatisk igen efter en pause.",
        "de": "Diesen Timer nach einer Abkühlpause automatisch erneut starten.",
        "el": "Αυτόματη επανεκτέλεση αυτού του χρονομέτρου μετά από μια παύση.",
        "es": "Vuelve a ejecutar este temporizador automáticamente tras un retardo.",
        "fi": "Käynnistä tämä ajastin automaattisesti uudelleen tauon jälkeen.",
        "fr": "Relance automatiquement ce minuteur après un délai de pause.",
        "hu": "Az időzítő automatikus újraindítása egy szünet után.",
        "it": "Riavvia automaticamente questo timer dopo un intervallo di pausa.",
        "ja": "クールダウン後にこのタイマーを自動的に再実行します。",
        "nb": "Kjør denne tidtakeren automatisk på nytt etter en pause.",
        "nl": "Voer deze timer automatisch opnieuw uit na een pauze.",
        "pl": "Automatycznie uruchom ten minutnik ponownie po przerwie.",
        "pt-PT": "Voltar a executar este temporizador automaticamente após uma pausa.",
        "ro": "Repornește automat acest temporizator după o pauză.",
        "ru": "Автоматически перезапускать этот таймер после паузы.",
        "sk": "Po prestávke tento časovač automaticky spustí znova.",
        "sl": "Po premoru samodejno znova zaženi ta časovnik.",
        "sr": "Аутоматски поново покрени овај тајмер након паузе.",
        "sv": "Kör den här timern automatiskt igen efter en paus.",
    },
    "Pin timer": {
        "ar": "تثبيت المؤقّت", "bg": "Закачи таймера", "cs": "Připnout časovač",
        "da": "Fastgør timer", "de": "Timer anheften", "el": "Καρφίτσωμα χρονομέτρου",
        "es": "Fijar temporizador", "fi": "Kiinnitä ajastin", "fr": "Épingler le minuteur",
        "hu": "Időzítő rögzítése", "it": "Fissa timer", "ja": "タイマーを固定",
        "nb": "Fest tidtaker", "nl": "Timer vastmaken", "pl": "Przypnij minutnik",
        "pt-PT": "Fixar temporizador", "ro": "Fixează temporizatorul",
        "ru": "Закрепить таймер", "sk": "Pripnúť časovač", "sl": "Pripni časovnik",
        "sr": "Закачи тајмер", "sv": "Fäst timer",
    },
    "Keep this timer permanently available.": {
        "ar": "إبقاء هذا المؤقّت متاحًا بشكل دائم.",
        "bg": "Дръжте този таймер винаги достъпен.",
        "cs": "Mít tento časovač trvale k dispozici.",
        "da": "Hold denne timer permanent tilgængelig.",
        "de": "Diesen Timer dauerhaft verfügbar halten.",
        "el": "Διατηρήστε αυτό το χρονόμετρο πάντα διαθέσιμο.",
        "es": "Mantén este temporizador siempre disponible.",
        "fi": "Pidä tämä ajastin aina saatavilla.",
        "fr": "Gardez ce minuteur disponible en permanence.",
        "hu": "Az időzítő állandó elérhetővé tétele.",
        "it": "Mantieni questo timer sempre disponibile.",
        "ja": "このタイマーを常に使えるようにします。",
        "nb": "Hold denne tidtakeren permanent tilgjengelig.",
        "nl": "Houd deze timer permanent beschikbaar.",
        "pl": "Zachowaj ten minutnik zawsze dostępny.",
        "pt-PT": "Manter este temporizador sempre disponível.",
        "ro": "Păstrează acest temporizator mereu disponibil.",
        "ru": "Этот таймер всегда будет доступен.",
        "sk": "Mať tento časovač trvalo k dispozícii.",
        "sl": "Ohrani ta časovnik vedno na voljo.",
        "sr": "Нека овај тајмер увек буде доступан.",
        "sv": "Håll den här timern permanent tillgänglig.",
    },
    "Cooldown delay": {
        "ar": "مدة التوقّف", "bg": "Изчакване", "cs": "Prodleva", "da": "Pausetid",
        "de": "Abkühlpause", "el": "Καθυστέρηση παύσης", "es": "Retardo de espera",
        "fi": "Tauon kesto", "fr": "Délai de pause", "hu": "Szünet ideje",
        "it": "Intervallo di pausa", "ja": "クールダウン時間", "nb": "Pausetid",
        "nl": "Pauzeduur", "pl": "Czas przerwy", "pt-PT": "Atraso da pausa",
        "ro": "Întârziere pauză", "ru": "Задержка перед перезапуском", "sk": "Prestávka",
        "sl": "Čas premora", "sr": "Пауза пре поновног покретања", "sv": "Paustid",
    },
    "Immediately": {
        "ar": "فورًا", "bg": "Веднага", "cs": "Okamžitě", "da": "Med det samme",
        "de": "Sofort", "el": "Αμέσως", "es": "Inmediatamente", "fi": "Heti",
        "fr": "Immédiatement", "hu": "Azonnal", "it": "Immediatamente", "ja": "すぐに",
        "nb": "Umiddelbart", "nl": "Onmiddellijk", "pl": "Natychmiast",
        "pt-PT": "Imediatamente", "ro": "Imediat", "ru": "Сразу", "sk": "Okamžite",
        "sl": "Takoj", "sr": "Одмах", "sv": "Omedelbart",
    },
    "e.g. Pasta": {
        "ar": "مثال: معكرونة", "bg": "напр. Паста", "cs": "např. Těstoviny",
        "da": "f.eks. Pasta", "de": "z. B. Pasta", "el": "π.χ. Ζυμαρικά",
        "es": "p. ej. Pasta", "fi": "esim. Pasta", "fr": "ex. Pâtes", "hu": "pl. Tészta",
        "it": "es. Pasta", "ja": "例：パスタ", "nb": "f.eks. Pasta", "nl": "bijv. Pasta",
        "pl": "np. Makaron", "pt-PT": "ex.: Massa", "ro": "ex. Paste", "ru": "напр. Паста",
        "sk": "napr. Cestoviny", "sl": "npr. Testenine", "sr": "нпр. Паста",
        "sv": "t.ex. Pasta",
    },
    "Resume timer": {
        "ar": "استئناف المؤقّت", "bg": "Възобнови таймера", "cs": "Pokračovat v časovači",
        "da": "Genoptag timer", "de": "Timer fortsetzen", "el": "Συνέχιση χρονομέτρου",
        "es": "Reanudar temporizador", "fi": "Jatka ajastinta", "fr": "Reprendre le minuteur",
        "hu": "Időzítő folytatása", "it": "Riprendi timer", "ja": "タイマーを再開",
        "nb": "Gjenoppta tidtaker", "nl": "Timer hervatten", "pl": "Wznów minutnik",
        "pt-PT": "Retomar temporizador", "ro": "Reia temporizatorul",
        "ru": "Возобновить таймер", "sk": "Pokračovať v časovači", "sl": "Nadaljuj časovnik",
        "sr": "Настави тајмер", "sv": "Återuppta timer",
    },
    "Pause timer": {
        "ar": "إيقاف المؤقّت مؤقتًا", "bg": "Пауза на таймера", "cs": "Pozastavit časovač",
        "da": "Sæt timer på pause", "de": "Timer pausieren", "el": "Παύση χρονομέτρου",
        "es": "Pausar temporizador", "fi": "Keskeytä ajastin",
        "fr": "Mettre en pause le minuteur", "hu": "Időzítő szüneteltetése",
        "it": "Metti in pausa timer", "ja": "タイマーを一時停止",
        "nb": "Sett tidtaker på pause", "nl": "Timer pauzeren", "pl": "Wstrzymaj minutnik",
        "pt-PT": "Pausar temporizador", "ro": "Pune temporizatorul pe pauză",
        "ru": "Приостановить таймер", "sk": "Pozastaviť časovač",
        "sl": "Začasno ustavi časovnik", "sr": "Паузирај тајмер", "sv": "Pausa timer",
    },
    "Dismiss timer": {
        "ar": "تجاهل المؤقّت", "bg": "Затвори таймера", "cs": "Zavřít časovač",
        "da": "Afvis timer", "de": "Timer schließen", "el": "Απόρριψη χρονομέτρου",
        "es": "Descartar temporizador", "fi": "Hylkää ajastin", "fr": "Ignorer le minuteur",
        "hu": "Időzítő elvetése", "it": "Ignora timer", "ja": "タイマーを閉じる",
        "nb": "Avvis tidtaker", "nl": "Timer sluiten", "pl": "Zamknij minutnik",
        "pt-PT": "Ignorar temporizador", "ro": "Închide temporizatorul",
        "ru": "Закрыть таймер", "sk": "Zavrieť časovač", "sl": "Opusti časovnik",
        "sr": "Затвори тајмер", "sv": "Avfärda timer",
    },
    "Auto-restart": {
        "ar": "إعادة تشغيل تلقائية", "bg": "Автоматичен рестарт", "cs": "Automatický restart",
        "da": "Automatisk genstart", "de": "Auto-Neustart", "el": "Αυτόματη επανεκκίνηση",
        "es": "Reinicio automático", "fi": "Automaattinen uudelleenkäynnistys",
        "fr": "Redémarrage automatique", "hu": "Automatikus újraindítás",
        "it": "Riavvio automatico", "ja": "自動再開", "nb": "Automatisk omstart",
        "nl": "Automatisch herstarten", "pl": "Automatyczny restart",
        "pt-PT": "Reinício automático", "ro": "Repornire automată", "ru": "Автоперезапуск",
        "sk": "Automatický reštart", "sl": "Samodejni vnovični zagon",
        "sr": "Аутоматско поновно покретање", "sv": "Automatisk omstart",
    },
    "Unpin timer": {
        "ar": "إلغاء تثبيت المؤقّت", "bg": "Откачи таймера", "cs": "Odepnout časovač",
        "da": "Frigør timer", "de": "Timer lösen", "el": "Ξεκαρφίτσωμα χρονομέτρου",
        "es": "Dejar de fijar temporizador", "fi": "Poista ajastimen kiinnitys",
        "fr": "Détacher le minuteur", "hu": "Időzítő rögzítésének feloldása",
        "it": "Rimuovi timer", "ja": "タイマーの固定を解除", "nb": "Løsne tidtaker",
        "nl": "Timer losmaken", "pl": "Odepnij minutnik",
        "pt-PT": "Desafixar temporizador", "ro": "Anulează fixarea temporizatorului",
        "ru": "Открепить таймер", "sk": "Odopnúť časovač", "sl": "Odpni časovnik",
        "sr": "Откачи тајмер", "sv": "Lossa timer",
    },
    "Quick start": {
        "ar": "بدء سريع", "bg": "Бърз старт", "cs": "Rychlý start", "da": "Hurtig start",
        "de": "Schnellstart", "el": "Γρήγορη έναρξη", "es": "Inicio rápido",
        "fi": "Pikakäynnistys", "fr": "Démarrage rapide", "hu": "Gyorsindítás",
        "it": "Avvio rapido", "ja": "クイックスタート", "nb": "Hurtigstart", "nl": "Snelstart",
        "pl": "Szybki start", "pt-PT": "Início rápido", "ro": "Pornire rapidă",
        "ru": "Быстрый старт", "sk": "Rýchly štart", "sl": "Hitri zagon",
        "sr": "Брзо покретање", "sv": "Snabbstart",
    },
    "Running": {
        "ar": "قيد التشغيل", "bg": "Активен", "cs": "Běží", "da": "Kører", "de": "Läuft",
        "el": "Σε εξέλιξη", "es": "En curso", "fi": "Käynnissä", "fr": "En cours",
        "hu": "Fut", "it": "In corso", "ja": "実行中", "nb": "Pågår", "nl": "Actief",
        "pl": "Trwa", "pt-PT": "Em curso", "ro": "În curs", "ru": "Идёт", "sk": "Beží",
        "sl": "Poteka", "sr": "У току", "sv": "Pågår",
    },
    "Done": {
        "ar": "تم", "bg": "Готово", "cs": "Hotovo", "da": "Færdig", "de": "Fertig",
        "el": "Έτοιμο", "es": "Listo", "fi": "Valmis", "fr": "Terminé", "hu": "Kész",
        "it": "Fatto", "ja": "完了", "nb": "Ferdig", "nl": "Klaar", "pl": "Gotowe",
        "pt-PT": "Concluído", "ro": "Gata", "ru": "Готово", "sk": "Hotovo",
        "sl": "Končano", "sr": "Готово", "sv": "Klar",
    },
    "Timer": {
        "ar": "مؤقّت", "bg": "Таймер", "cs": "Časovač", "da": "Timer", "de": "Timer",
        "el": "Χρονόμετρο", "es": "Temporizador", "fi": "Ajastin", "fr": "Minuteur",
        "hu": "Időzítő", "it": "Timer", "ja": "タイマー", "nb": "Tidtaker", "nl": "Timer",
        "pl": "Minutnik", "pt-PT": "Temporizador", "ro": "Temporizator", "ru": "Таймер",
        "sk": "Časovač", "sl": "Časovnik", "sr": "Тајмер", "sv": "Timer",
    },
    "%@ running": {
        "ar": "%@ قيد التشغيل", "bg": "%@ активен", "cs": "%@ běží", "da": "%@ kører",
        "de": "%@ läuft", "el": "%@ σε εξέλιξη", "es": "%@ en curso", "fi": "%@ käynnissä",
        "fr": "%@ en cours", "hu": "%@ fut", "it": "%@ in corso", "ja": "%@ 実行中",
        "nb": "%@ pågår", "nl": "%@ actief", "pl": "%@ w toku", "pt-PT": "%@ em curso",
        "ro": "%@ în curs", "ru": "%@ идёт", "sk": "%@ beží", "sl": "%@ poteka",
        "sr": "%@ у току", "sv": "%@ pågår",
    },
    "Start your favorite timers right from the Home Screen.": {
        "ar": "ابدأ مؤقّتاتك المفضّلة مباشرةً من الشاشة الرئيسية.",
        "bg": "Стартирайте любимите си таймери директно от началния екран.",
        "cs": "Spouštějte oblíbené časovače přímo z plochy.",
        "da": "Start dine foretrukne timere direkte fra hjemmeskærmen.",
        "de": "Starte deine Lieblingstimer direkt vom Home-Bildschirm.",
        "el": "Ξεκινήστε τα αγαπημένα σας χρονόμετρα απευθείας από την οθόνη Αφετηρίας.",
        "es": "Inicia tus temporizadores favoritos desde la pantalla de inicio.",
        "fi": "Käynnistä suosikkiajastimesi suoraan Koti-valikosta.",
        "fr": "Démarrez vos minuteurs favoris depuis l'écran d'accueil.",
        "hu": "Indítsd kedvenc időzítőidet közvetlenül a kezdőképernyőről.",
        "it": "Avvia i tuoi timer preferiti direttamente dalla schermata Home.",
        "ja": "お気に入りのタイマーをホーム画面からすぐに開始できます。",
        "nb": "Start favorittidtakerne dine rett fra Hjem-skjermen.",
        "nl": "Start je favoriete timers direct vanaf het beginscherm.",
        "pl": "Uruchamiaj ulubione minutniki bezpośrednio z ekranu początkowego.",
        "pt-PT": "Inicie os seus temporizadores favoritos diretamente do ecrã principal.",
        "ro": "Pornește temporizatoarele favorite direct din ecranul principal.",
        "ru": "Запускайте любимые таймеры прямо с экрана «Домой».",
        "sk": "Spúšťajte obľúbené časovače priamo z plochy.",
        "sl": "Zaženite priljubljene časovnike kar z začetnega zaslona.",
        "sr": "Покрените омиљене тајмере директно са почетног екрана.",
        "sv": "Starta dina favorittimers direkt från hemskärmen.",
    },
    # --- AppIntents (Shared/, compiled into both targets) ---
    "Cancel Timer": {
        "ar": "إلغاء المؤقّت", "bg": "Отказ на таймера", "cs": "Zrušit časovač",
        "da": "Annuller timer", "de": "Timer abbrechen", "el": "Ακύρωση χρονομέτρου",
        "es": "Cancelar temporizador", "fi": "Peruuta ajastin", "fr": "Annuler le minuteur",
        "hu": "Időzítő megszakítása", "it": "Annulla timer", "ja": "タイマーをキャンセル",
        "nb": "Avbryt tidtaker", "nl": "Timer annuleren", "pl": "Anuluj minutnik",
        "pt-PT": "Cancelar temporizador", "ro": "Anulează temporizatorul",
        "ru": "Отменить таймер", "sk": "Zrušiť časovač", "sl": "Prekliči časovnik",
        "sr": "Откажи тајмер", "sv": "Avbryt timer",
    },
    "Cancels the running countdown timer.": {
        "ar": "يلغي مؤقّت العدّ التنازلي قيد التشغيل.",
        "bg": "Отменя текущия таймер за обратно броене.",
        "cs": "Zruší běžící odpočítávací časovač.",
        "da": "Annullerer den kørende nedtællingstimer.",
        "de": "Bricht den laufenden Countdown-Timer ab.",
        "el": "Ακυρώνει το χρονόμετρο αντίστροφης μέτρησης που εκτελείται.",
        "es": "Cancela el temporizador de cuenta atrás en curso.",
        "fi": "Peruuttaa käynnissä olevan ajastimen.",
        "fr": "Annule le minuteur en cours.",
        "hu": "Megszakítja a futó visszaszámláló időzítőt.",
        "it": "Annulla il timer del conto alla rovescia in corso.",
        "ja": "実行中のカウントダウンタイマーをキャンセルします。",
        "nb": "Avbryter den pågående nedtellingstidtakeren.",
        "nl": "Annuleert de actieve afteltimer.",
        "pl": "Anuluje trwający minutnik odliczający.",
        "pt-PT": "Cancela o temporizador de contagem decrescente em curso.",
        "ro": "Anulează temporizatorul în curs.",
        "ru": "Отменяет запущенный таймер обратного отсчёта.",
        "sk": "Zruší bežiaci odpočítavací časovač.",
        "sl": "Prekliče potekajoči odštevalni časovnik.",
        "sr": "Отказује покренути одбројавајући тајмер.",
        "sv": "Avbryter den pågående nedräkningstimern.",
    },
    "Pause Timer": {
        "ar": "إيقاف المؤقّت مؤقتًا", "bg": "Пауза на таймера", "cs": "Pozastavit časovač",
        "da": "Sæt timer på pause", "de": "Timer pausieren", "el": "Παύση χρονομέτρου",
        "es": "Pausar temporizador", "fi": "Keskeytä ajastin",
        "fr": "Mettre en pause le minuteur", "hu": "Időzítő szüneteltetése",
        "it": "Metti in pausa timer", "ja": "タイマーを一時停止",
        "nb": "Sett tidtaker på pause", "nl": "Timer pauzeren", "pl": "Wstrzymaj minutnik",
        "pt-PT": "Pausar temporizador", "ro": "Pune temporizatorul pe pauză",
        "ru": "Приостановить таймер", "sk": "Pozastaviť časovač",
        "sl": "Začasno ustavi časovnik", "sr": "Паузирај тајмер", "sv": "Pausa timer",
    },
    "Pauses the running countdown timer.": {
        "ar": "يوقف مؤقّت العدّ التنازلي قيد التشغيل مؤقتًا.",
        "bg": "Поставя на пауза текущия таймер за обратно броене.",
        "cs": "Pozastaví běžící odpočítávací časovač.",
        "da": "Sætter den kørende nedtællingstimer på pause.",
        "de": "Pausiert den laufenden Countdown-Timer.",
        "el": "Διακόπτει προσωρινά το χρονόμετρο αντίστροφης μέτρησης που εκτελείται.",
        "es": "Pausa el temporizador de cuenta atrás en curso.",
        "fi": "Keskeyttää käynnissä olevan ajastimen.",
        "fr": "Met en pause le minuteur en cours.",
        "hu": "Szünetelteti a futó visszaszámláló időzítőt.",
        "it": "Mette in pausa il timer del conto alla rovescia in corso.",
        "ja": "実行中のカウントダウンタイマーを一時停止します。",
        "nb": "Setter den pågående nedtellingstidtakeren på pause.",
        "nl": "Pauzeert de actieve afteltimer.",
        "pl": "Wstrzymuje trwający minutnik odliczający.",
        "pt-PT": "Pausa o temporizador de contagem decrescente em curso.",
        "ro": "Pune pe pauză temporizatorul în curs.",
        "ru": "Приостанавливает запущенный таймер обратного отсчёта.",
        "sk": "Pozastaví bežiaci odpočítavací časovač.",
        "sl": "Začasno ustavi potekajoči odštevalni časovnik.",
        "sr": "Паузира покренути одбројавајући тајмер.",
        "sv": "Pausar den pågående nedräkningstimern.",
    },
    "Repeat Timer": {
        "ar": "تكرار المؤقّت", "bg": "Повтори таймера", "cs": "Opakovat časovač",
        "da": "Gentag timer", "de": "Timer wiederholen", "el": "Επανάληψη χρονομέτρου",
        "es": "Repetir temporizador", "fi": "Toista ajastin", "fr": "Répéter le minuteur",
        "hu": "Időzítő ismétlése", "it": "Ripeti timer", "ja": "タイマーを繰り返す",
        "nb": "Gjenta tidtaker", "nl": "Timer herhalen", "pl": "Powtórz minutnik",
        "pt-PT": "Repetir temporizador", "ro": "Repetă temporizatorul",
        "ru": "Повторить таймер", "sk": "Opakovať časovač", "sl": "Ponovi časovnik",
        "sr": "Понови тајмер", "sv": "Upprepa timer",
    },
    "Restarts the same timer from the beginning.": {
        "ar": "يعيد تشغيل المؤقّت نفسه من البداية.",
        "bg": "Рестартира същия таймер от началото.",
        "cs": "Restartuje stejný časovač od začátku.",
        "da": "Genstarter den samme timer fra begyndelsen.",
        "de": "Startet denselben Timer von vorn.",
        "el": "Επανεκκινεί το ίδιο χρονόμετρο από την αρχή.",
        "es": "Reinicia el mismo temporizador desde el principio.",
        "fi": "Käynnistää saman ajastimen alusta.",
        "fr": "Redémarre le même minuteur depuis le début.",
        "hu": "Újraindítja ugyanazt az időzítőt az elejétől.",
        "it": "Riavvia lo stesso timer dall'inizio.",
        "ja": "同じタイマーを最初から再開します。",
        "nb": "Starter den samme tidtakeren på nytt fra begynnelsen.",
        "nl": "Start dezelfde timer opnieuw vanaf het begin.",
        "pl": "Ponownie uruchamia ten sam minutnik od początku.",
        "pt-PT": "Reinicia o mesmo temporizador desde o início.",
        "ro": "Repornește același temporizator de la început.",
        "ru": "Перезапускает тот же таймер с начала.",
        "sk": "Reštartuje rovnaký časovač od začiatku.",
        "sl": "Znova zažene isti časovnik od začetka.",
        "sr": "Поново покреће исти тајмер од почетка.",
        "sv": "Startar om samma timer från början.",
    },
    "Resume Timer": {
        "ar": "استئناف المؤقّت", "bg": "Възобнови таймера", "cs": "Pokračovat v časovači",
        "da": "Genoptag timer", "de": "Timer fortsetzen", "el": "Συνέχιση χρονομέτρου",
        "es": "Reanudar temporizador", "fi": "Jatka ajastinta", "fr": "Reprendre le minuteur",
        "hu": "Időzítő folytatása", "it": "Riprendi timer", "ja": "タイマーを再開",
        "nb": "Gjenoppta tidtaker", "nl": "Timer hervatten", "pl": "Wznów minutnik",
        "pt-PT": "Retomar temporizador", "ro": "Reia temporizatorul",
        "ru": "Возобновить таймер", "sk": "Pokračovať v časovači", "sl": "Nadaljuj časovnik",
        "sr": "Настави тајмер", "sv": "Återuppta timer",
    },
    "Resumes the paused countdown timer.": {
        "ar": "يستأنف مؤقّت العدّ التنازلي المتوقّف مؤقتًا.",
        "bg": "Възобновява поставения на пауза таймер за обратно броене.",
        "cs": "Obnoví pozastavený odpočítávací časovač.",
        "da": "Genoptager den pausede nedtællingstimer.",
        "de": "Setzt den pausierten Countdown-Timer fort.",
        "el": "Συνεχίζει το χρονόμετρο αντίστροφης μέτρησης που έχει διακοπεί.",
        "es": "Reanuda el temporizador de cuenta atrás en pausa.",
        "fi": "Jatkaa keskeytettyä ajastinta.",
        "fr": "Reprend le minuteur en pause.",
        "hu": "Folytatja a szüneteltetett visszaszámláló időzítőt.",
        "it": "Riprende il timer del conto alla rovescia in pausa.",
        "ja": "一時停止中のカウントダウンタイマーを再開します。",
        "nb": "Gjenopptar den pausede nedtellingstidtakeren.",
        "nl": "Hervat de gepauzeerde afteltimer.",
        "pl": "Wznawia wstrzymany minutnik odliczający.",
        "pt-PT": "Retoma o temporizador de contagem decrescente em pausa.",
        "ro": "Reia temporizatorul aflat în pauză.",
        "ru": "Возобновляет приостановленный таймер обратного отсчёта.",
        "sk": "Obnoví pozastavený odpočítavací časovač.",
        "sl": "Nadaljuje začasno ustavljeni odštevalni časovnik.",
        "sr": "Наставља паузирани одбројавајући тајмер.",
        "sv": "Återupptar den pausade nedräkningstimern.",
    },
    "Start Timer": {
        "ar": "بدء المؤقّت", "bg": "Стартирай таймера", "cs": "Spustit časovač",
        "da": "Start timer", "de": "Timer starten", "el": "Έναρξη χρονομέτρου",
        "es": "Iniciar temporizador", "fi": "Käynnistä ajastin", "fr": "Démarrer le minuteur",
        "hu": "Időzítő indítása", "it": "Avvia timer", "ja": "タイマーを開始",
        "nb": "Start tidtaker", "nl": "Timer starten", "pl": "Uruchom minutnik",
        "pt-PT": "Iniciar temporizador", "ro": "Pornește temporizatorul",
        "ru": "Запустить таймер", "sk": "Spustiť časovač", "sl": "Zaženi časovnik",
        "sr": "Покрени тајмер", "sv": "Starta timer",
    },
    "Starts a countdown timer for the selected preset.": {
        "ar": "يبدأ مؤقّت عدّ تنازلي للإعداد المحدّد.",
        "bg": "Стартира таймер за обратно броене за избраната настройка.",
        "cs": "Spustí odpočítávací časovač pro vybranou předvolbu.",
        "da": "Starter en nedtællingstimer for den valgte forudindstilling.",
        "de": "Startet einen Countdown-Timer für die ausgewählte Vorgabe.",
        "el": "Ξεκινά ένα χρονόμετρο αντίστροφης μέτρησης για την επιλεγμένη προεπιλογή.",
        "es": "Inicia un temporizador de cuenta atrás para el ajuste seleccionado.",
        "fi": "Käynnistää ajastimen valitulle esiasetukselle.",
        "fr": "Démarre un minuteur pour le préréglage sélectionné.",
        "hu": "Visszaszámláló időzítőt indít a kiválasztott beállításhoz.",
        "it": "Avvia un timer del conto alla rovescia per il preset selezionato.",
        "ja": "選択したプリセットのカウントダウンタイマーを開始します。",
        "nb": "Starter en nedtellingstidtaker for det valgte forhåndsvalget.",
        "nl": "Start een afteltimer voor de geselecteerde voorinstelling.",
        "pl": "Uruchamia minutnik odliczający dla wybranego ustawienia.",
        "pt-PT": "Inicia um temporizador de contagem decrescente para a predefinição selecionada.",
        "ro": "Pornește un temporizator pentru presetarea selectată.",
        "ru": "Запускает таймер обратного отсчёта для выбранной настройки.",
        "sk": "Spustí odpočítavací časovač pre vybranú predvoľbu.",
        "sl": "Zažene odštevalni časovnik za izbrano prednastavitev.",
        "sr": "Покреће одбројавајући тајмер за изабрану поставку.",
        "sv": "Startar en nedräkningstimer för den valda förinställningen.",
    },
    "Stop Timer": {
        "ar": "إيقاف المؤقّت", "bg": "Спри таймера", "cs": "Zastavit časovač",
        "da": "Stop timer", "de": "Timer stoppen", "el": "Διακοπή χρονομέτρου",
        "es": "Detener temporizador", "fi": "Pysäytä ajastin", "fr": "Arrêter le minuteur",
        "hu": "Időzítő leállítása", "it": "Ferma timer", "ja": "タイマーを停止",
        "nb": "Stopp tidtaker", "nl": "Timer stoppen", "pl": "Zatrzymaj minutnik",
        "pt-PT": "Parar temporizador", "ro": "Oprește temporizatorul",
        "ru": "Остановить таймер", "sk": "Zastaviť časovač", "sl": "Ustavi časovnik",
        "sr": "Заустави тајмер", "sv": "Stoppa timer",
    },
    "Stops the running countdown timer and clears its widget indicator.": {
        "ar": "يوقف المؤقّت قيد التشغيل ويمسح مؤشّره في الأداة.",
        "bg": "Спира текущия таймер и премахва индикатора му в джаджата.",
        "cs": "Zastaví běžící časovač a odstraní jeho indikátor ve widgetu.",
        "da": "Stopper den kørende nedtællingstimer og fjerner dens widgetindikator.",
        "de": "Stoppt den laufenden Countdown-Timer und entfernt seine Widget-Anzeige.",
        "el": "Σταματά το χρονόμετρο που εκτελείται και αφαιρεί την ένδειξή του στο widget.",
        "es": "Detiene el temporizador en curso y borra su indicador en el widget.",
        "fi": "Pysäyttää käynnissä olevan ajastimen ja poistaa sen widget-merkinnän.",
        "fr": "Arrête le minuteur en cours et efface son indicateur dans le widget.",
        "hu": "Leállítja a futó visszaszámláló időzítőt, és törli a widgetjelzőjét.",
        "it": "Ferma il timer in corso e rimuove il suo indicatore nel widget.",
        "ja": "実行中のカウントダウンタイマーを停止し、ウィジェットのインジケータを消去します。",
        "nb": "Stopper den pågående nedtellingstidtakeren og fjerner indikatoren i widgeten.",
        "nl": "Stopt de actieve afteltimer en wist de indicator in de widget.",
        "pl": "Zatrzymuje trwający minutnik i usuwa jego wskaźnik w widżecie.",
        "pt-PT": "Para o temporizador em curso e remove o respetivo indicador no widget.",
        "ro": "Oprește temporizatorul în curs și elimină indicatorul din widget.",
        "ru": "Останавливает запущенный таймер и убирает его индикатор в виджете.",
        "sk": "Zastaví bežiaci časovač a odstráni jeho indikátor vo widgete.",
        "sl": "Ustavi potekajoči časovnik in odstrani njegov pokazatelj v pripomočku.",
        "sr": "Зауставља покренути тајмер и уклања његов индикатор у виџету.",
        "sv": "Stoppar den pågående nedräkningstimern och tar bort dess widgetindikator.",
    },
}

# AlarmKit usage description (InfoPlist.xcstrings).
INFO_PLIST = {
    "NSAlarmKitUsageDescription": {
        "en": "SpaghettiTimer uses alarms to ring when your timers finish.",
        "ar": "يستخدم SpaghettiTimer المنبّهات للرنين عند انتهاء مؤقّتاتك.",
        "bg": "SpaghettiTimer използва аларми, за да звъни, когато таймерите ви приключат.",
        "cs": "SpaghettiTimer používá budíky, aby zazvonil, když vaše časovače skončí.",
        "da": "SpaghettiTimer bruger alarmer til at ringe, når dine timere er færdige.",
        "de": "SpaghettiTimer verwendet Wecker, um zu klingeln, wenn deine Timer ablaufen.",
        "el": "Το SpaghettiTimer χρησιμοποιεί ξυπνητήρια για να ηχήσει όταν λήγουν τα χρονόμετρά σας.",
        "es": "SpaghettiTimer usa alarmas para sonar cuando tus temporizadores terminan.",
        "fi": "SpaghettiTimer käyttää hälytyksiä soittaakseen, kun ajastimesi päättyvät.",
        "fr": "SpaghettiTimer utilise des alarmes pour sonner à la fin de vos minuteurs.",
        "hu": "A SpaghettiTimer riasztásokat használ, hogy jelezzen, amikor az időzítőid lejárnak.",
        "it": "SpaghettiTimer usa le sveglie per suonare quando i tuoi timer terminano.",
        "ja": "SpaghettiTimer はタイマー終了時に鳴らすためアラームを使用します。",
        "nb": "SpaghettiTimer bruker alarmer for å ringe når tidtakerne dine er ferdige.",
        "nl": "SpaghettiTimer gebruikt wekkers om af te gaan wanneer je timers aflopen.",
        "pl": "SpaghettiTimer używa alarmów, aby dzwonić po zakończeniu Twoich minutników.",
        "pt-PT": "O SpaghettiTimer usa alarmes para tocar quando os seus temporizadores terminam.",
        "ro": "SpaghettiTimer folosește alarme pentru a suna când temporizatoarele tale se termină.",
        "ru": "SpaghettiTimer использует будильники, чтобы звонить по завершении таймеров.",
        "sk": "SpaghettiTimer používa budíky, aby zazvonil, keď vaše časovače skončia.",
        "sl": "SpaghettiTimer uporablja budilke, da zazvoni, ko se vaši časovniki iztečejo.",
        "sr": "SpaghettiTimer користи аларме да зазвони када се ваши тајмери заврше.",
        "sv": "SpaghettiTimer använder larm för att ringa när dina timers är klara.",
    },
}

# Keys used only by the widget target.
WIDGET_ONLY = {
    "Quick start", "Running", "Done", "Timer", "%@ running",
    "Start your favorite timers right from the Home Screen.",
}
# Keys used only by the main app target.
APP_ONLY = {
    "New Timer", "Cancel", "Start", "Name", "Duration", "Options",
    "Auto-restart after finish",
    "Re-run this timer automatically after a cooldown delay.",
    "Pin timer", "Keep this timer permanently available.", "Cooldown delay",
    "Immediately", "e.g. Pasta", "Resume timer", "Pause timer", "Dismiss timer",
    "Unpin timer",
}
# Shared AppIntent strings (both targets) + "Auto-restart" (both).
SHARED = {
    "Auto-restart",
    "Cancel Timer", "Cancels the running countdown timer.",
    "Pause Timer", "Pauses the running countdown timer.",
    "Repeat Timer", "Restarts the same timer from the beginning.",
    "Resume Timer", "Resumes the paused countdown timer.",
    "Start Timer", "Starts a countdown timer for the selected preset.",
    "Stop Timer", "Stops the running countdown timer and clears its widget indicator.",
}

# Brand strings: present in the widget but never translated (fall back to source).
WIDGET_BRAND = ["Spaghetti Timer", "SpaghettiTimer"]


def string_entry(translations):
    locs = {}
    for lang in LANGS:
        value = translations.get(lang)
        if value is None:
            raise SystemExit(f"Missing {lang} for: {translations}")
        locs[lang] = {"stringUnit": {"state": "translated", "value": value}}
    return {"extractionState": "manual", "localizations": locs}


def brand_entry():
    return {"extractionState": "manual", "shouldTranslate": False}


def build_catalog(keys, brands=None):
    strings = {}
    for key in sorted(keys):
        strings[key] = string_entry(T[key])
    for b in (brands or []):
        strings[b] = brand_entry()
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def build_infoplist():
    strings = {}
    for key, tr in INFO_PLIST.items():
        locs = {"en": {"stringUnit": {"state": "translated", "value": tr["en"]}}}
        for lang in LANGS:
            locs[lang] = {"stringUnit": {"state": "translated", "value": tr[lang]}}
        strings[key] = {"extractionState": "manual", "localizations": locs}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def write_json(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote", path)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    app = build_catalog(APP_ONLY | SHARED)
    write_json(os.path.join(root, "SpaghettiTimer", "Localizable.xcstrings"), app)

    # Brand strings ("Spaghetti Timer", "SpaghettiTimer") are intentionally left
    # out of the catalog: they are never translated, and including both collides
    # under STRING_CATALOG_GENERATE_SYMBOLS. The code literals fall back to source.
    widget = build_catalog(WIDGET_ONLY | SHARED)
    write_json(os.path.join(root, "SpaghettiTimerWidget", "Localizable.xcstrings"), widget)

    info = build_infoplist()
    write_json(os.path.join(root, "SpaghettiTimer", "InfoPlist.xcstrings"), info)


if __name__ == "__main__":
    main()
