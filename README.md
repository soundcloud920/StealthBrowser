# StealthBrowser

**Stealth** — приватный браузер на движке Mozilla Firefox, собранный в один установщик под Windows 10/11. Не форк. Не «сборка с вирусами». Готовый профиль, политики движка, лаунчер и автообновление — всё из коробки.

**Текущая версия: `1.0.0-beta`**

---

## СКАЧАТЬ

[Последний релиз на GitHub](https://github.com/soundcloud920/StealthBrowser/releases/latest)

| Файл | Для кого |
|------|----------|
| **`StealthBrowser-Setup-v1.0.0-beta.exe`** | Обычная установка — двойной клик |
| **`StealthBrowser-setup-v1.0.0-beta.zip`** | Портатив / разработчики |

---

## ТРЕБОВАНИЯ

1. **Windows 10/11 x64** — без WSL, без костылей. Нативный `.exe`.
2. **PowerShell 5.1+** — уже есть в системе.
3. **.NET Framework 4.x** — для лаунчера `Stealth.exe`; в Windows по умолчанию.
4. **Интернет** — один раз, чтобы скачать официальный движок Mozilla **151.0.3 (ru)**. Дальше движок лежит локально в `%LocalAppData%\StealthBrowser\Engine\`.
5. **Мозг** — если после прочтения README вы всё ещё спрашиваете «а это безопасно?», сначала прочитайте таблицу ниже и раздел «Пруфы из кода». Stealth не шлёт телеметрию в Mozilla/Google по дефолту — это не магия, это `user.js` + `policies.json`.

---

## ВВЕДЕНИЕ

Обычный Firefox из коробки — это:

- телеметрия, Normandy, Nimbus, crash reporter;
- Safe Browsing (хеши URL уходят к Google/Mozilla);
- Enhanced Tracking Protection (дополнительный слой в движке);
- Pocket, спонсорские подсказки, Firefox Suggest, ML-фичи;
- светлая тема, системный шрифт, newtab с лентой;
- фоновые проверки обновлений и prefetch/speculative connect.

**Stealth** берёт тот же бинарник Mozilla, патчит брендинг (`Stealth.exe`, иконка, AUMID для таскбара), кладёт **отдельный профиль** `*.stealth` и накатывает конфиг, который вы бы руками писали неделю — если бы вообще знали, что эти префы существуют.

Профиль **изолирован**: ваш `default-release` и другие установки Firefox не трогаются.

---

## STEALTH VS FIREFOX — ТАБЛИЦА

| | Firefox (сток) | Stealth |
|---|----------------|---------|
| **Установка** | Скачать, 20 вкладок настроек, расширения вручную | Один `.exe` → готово |
| **Профиль** | `default-release`, общий с другими инсталляциями | Отдельный `*.stealth`, `-no-remote` |
| **Телеметрия** | Включена (можно вырубить, но 99% не вырубают) | **Вырублена** в `user.js` + `DisableTelemetry` в политиках |
| **Normandy / Nimbus / Studies** | Активны | `app.normandy.enabled=false`, `nimbus.rollouts.enabled=false`, `DisableFirefoxStudies` |
| **Crash reporter** | Шлёт отчёты | `breakpad.reportURL=""`, отправка отключена |
| **Safe Browsing** | Запросы к Google/Mozilla | **Отключён** — URL не уходят на проверку |
| **ETP (Tracking Protection)** | Включён в движке | **Выключен** — фильтрация через **uBlock Origin** + **LocalCDN** (меньше дублирования работы в content process) |
| **Pocket / спонсоры / Suggest** | Включены | Pocket, Contile, QuickSuggest, ML-chat — off |
| **Поиск по умолчанию** | Google / региональный | **SearXNG** (`searx.tiekoetter.com`), ru-RU, чёрная тема |
| **New Tab** | Лента, реклама, телеметрия ленты | **Выключен** — `blanktab.html` |
| **Сессии / автовосстановление** | Агрессивный sessionstore | `restore_on_demand`, интервал записи **60 с**, меньше дискового IO |
| **Prefetch / speculative** | Включены | `network.prefetch-next=false`, `speculative-parallel-limit=0`, `urlbar.speculativeConnect=false` |
| **Фоновые обновления** | `app.update.background.enabled` | **false** в профиле |
| **Тема UI** | Proton, светлая/системная | **Полностью чёрный** chrome + content |
| **Шрифт** | Системный | **LLG_Relicus** — UI и страницы |
| **Расширения** | Ставишь сам | **uBlock Origin**, **LocalCDN**, **SponsorBlock**, ru-langpack — предустановлены |
| **Таскбар Windows** | Иконка Firefox, Jump Lists | **Stealth** AUMID, Jump Lists отключены (меньше фоновой работы Explorer) |
| **Проверка обновлений Stealth** | — | **Только при запуске** ярлыка; браузер стартует **сразу**; кэш 24 ч; таймаут GitHub **4 с** |
| **about:config** | Доступен | Доступен |

---

## ПОЧЕМУ STEALTH, А НЕ «ПРОСТО ПОТЮНИЛ FIREFOX»

### 1. Телеметрия — не галочка в настройках, а вырезание по корню

В стоке Firefox телеметрия — отдельные подсистемы: unified telemetry, ping-centre, SERP telemetry, coverage, healthreport. В Stealth это закрыто пачкой префов **и** политикой движка.

Пруф (`user.js`):

```javascript
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("nimbus.rollouts.enabled", false);
user_pref("app.normandy.enabled", false);
```

Пруф (`distribution/policies.json`):

```json
"DisableTelemetry": true,
"DisableFirefoxStudies": true,
"DisableRemoteImprovements": true
```

Mozilla документирует telemetry как отдельный канал данных — Stealth его не открывает. Период.

### 2. Safe Browsing — удобство за счёт утечки метаданных запросов

Safe Browsing сверяет URL/хеши с облачными списками. Для параноика и для тех, кому важна **локальность сетевого стека**, это лишний исходящий трафик и лишняя работа в network thread.

Пруф (`user.js`):

```javascript
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.provider.google.updateURL", "");
```

**Тейк:** Stealth не притворяется антивирусом. За вредоносные сайты отвечают ваш мозг + uBlock. Зато браузер не дёргает Google на каждый чих.

### 3. ETP выключен намеренно — не «хуже приватность», а другая архитектура

Enhanced Tracking Protection — встроенный в движок слой блокировки. Когда сверху стоит **uBlock Origin** (cosmetic + network filtering) и **LocalCDN** (локальная подмена CDN-скриптов), ETP даёт **дублирование**: два механизма бьют по одним и тем же запросам, content process делает лишнюю работу.

Пруф (`user.js`):

```javascript
user_pref("privacy.trackingprotection.enabled", false);
user_pref("privacy.trackingprotection.socialtracking.enabled", false);
```

**Тейк:** приватность Stealth = расширения + жёсткие префы, а не встроенный ETP + расширения одновременно. Меньше слоёв — меньше накладных расходов на страницу.

### 4. Session store и диск — Firefox любит писать на диск. Stealth — нет

`browser.sessionstore` на большом числе вкладок — постоянные fsync-подобные записи. Stealth поднимает интервал до **60 секунд**, включает `restore_on_demand`, режет undo-стек вкладок.

Пруф:

```javascript
user_pref("browser.sessionstore.interval", 60000);
user_pref("browser.sessionstore.restore_on_demand", true);
user_pref("browser.sessionstore.max_tabs_undo", 5);
```

**Тейк:** при 50+ вкладках разница в дисковой активности ощутима. Это не «бенчмарк на 3 вкладках», это реальное использование.

### 5. Сеть — prefetch и speculative connect съедают бюджет до клика

Firefox заранее открывает соединения «на всякий случай». Stealth это режет.

Пруф:

```javascript
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("network.predictor.enabled", false);
```

**Тейк:** меньше фоновых TCP/TLS handshake — меньше конкуренции с тем, что вы реально открыли. Особенно на слабом CPU или при игре на том же ПК.

### 6. RAM — image cache 10 МБ, не дефолтные сотни

```javascript
user_pref("image.cache.size", 10485760);
```

Декодированные картинки в кэше — память. Stealth сознательно держит кэш **10 МБ**, а не раздувает его под «удобство» возврата на тяжёлые страницы.

### 7. UI — чёрный chrome без анимаций

`userChrome.css` + `userContent.css` — полный чёрный Proton, кастомный urlbar, без cosmetic animations:

```javascript
user_pref("toolkit.cosmeticAnimations.enabled", false);
```

Ошибки сети (`about:neterror`), все `about:` страницы, SearXNG — единый стиль, шрифт LLG_Relicus, без лисы на экране ошибки.

### 8. Поиск — SearXNG, не Google в политике движка

Политика **на уровне движка** (не «пользователь забыл сменить»):

```json
"SearchEngines": {
  "Default": "SearXNG",
  "Add": [{ "Name": "SearXNG", "URLTemplate": "https://searx.tiekoetter.com/search?q={searchTerms}&language=ru-RU" }]
}
```

На главной SearXNG автодополнение **отключено** (CSS + JS) — меньше лишних XHR при наборе. На `/search` — остаётся.

### 9. Лаунчер и автообновление — не фоновый мусор

Схема запуска (`StealthLauncher.cs`):

1. Читает `config.json`
2. **Сразу** стартует `firefox.exe` с `-no-remote -profile`
3. **После** — проверка GitHub (кэш 24 ч, таймаут **4 с**)
4. Диалог: Да / Нет / Не напоминать
5. При «Да» — **видимое** окно PowerShell (`-WindowStyle Normal`), не hidden-процесс

**Тейк:** автоапдейтер **не крутится в фоне**, **не трогает** уже открытый браузер, **не вешает** scheduled task. Проверка — один раз за запуск ярлыка. Нет сети — браузер уже работает, лаунчер отваливается молча.

### 10. Расширения из коробки

| Расширение | Зачем |
|------------|-------|
| **uBlock Origin** | Сетевой и косметический фильтр — основной слой блокировки |
| **LocalCDN** | Локальная подмена популярных CDN — меньше внешних запросов |
| **SponsorBlock** | Сегменты спонсоров на YouTube — меньше мусора в видеопотоке |
| **langpack-ru** | Русский UI движка |

---

## УСТАНОВКА

1. Закрой **Stealth** и **Firefox** полностью (проверь диспетчер задач).
2. Скачай **`StealthBrowser-Setup-v1.0.0-beta.exe`** из [Releases](https://github.com/soundcloud920/StealthBrowser/releases/latest).
3. Запусти → **Install** → мастер StealthBrowser → **Установить**.
4. Браузер откроется с профилем `*.stealth`.
5. Дальше — ярлык **Stealth** на рабочем столе / в Пуске.

Тихая установка:

```bat
StealthBrowser-Setup-v1.0.0-beta.exe /install
```

### Только обновить профиль (движок уже стоит)

`Setup.cmd` → **«Только обновить профиль»**, или `Update-Profile.cmd`.

Маркер версии: `chrome/stealth-setup.json` в профиле.

---

## ОБНОВЛЕНИЯ

При запуске через ярлык **Stealth**:

| Кнопка | Действие |
|--------|----------|
| **Да** | Скачать zip с GitHub, применить, видимое окно установки |
| **Нет** | Браузер уже открыт — просто работаешь |
| **Отмена** | Запомнить версию в `dismissedVersion`, не напоминать |

Кэш проверки: **24 часа** (`lastUpdateCheckUtc` в `%LocalAppData%\StealthBrowser\config.json`).

---

## КУДА ВСЁ СТАВИТСЯ

| Что | Путь |
|-----|------|
| Движок | `%LocalAppData%\StealthBrowser\Engine\firefox.exe` |
| Лаунчер / скрипты | `%LocalAppData%\StealthBrowser\` |
| Профиль | `%APPDATA%\Mozilla\Firefox\Profiles\*.stealth` |
| Политики движка | `Engine\distribution\policies.json` |

---

## СБОРКА (РАЗРАБОТЧИКАМ)

```powershell
.\scripts\build-release.ps1
```

Артефакты в `dist/`:

- `StealthBrowser-Setup-v1.0.0-beta.exe`
- `StealthBrowser-setup-v1.0.0-beta.zip`

Тег `v*` на GitHub → CI собирает и публикует в Releases.

---

## BETA

`1.0.0-beta` — первый публичный срез после перезапуска репозитория. Ожидай:

- возможные баги в edge-case сайтах;
- обновления профиля через Releases;
- обратную связь через Issues на GitHub.

Не beta: движок Mozilla официальный, подписанный инсталлятор Mozilla CDN.

---

## СТРУКТУРА РЕПОЗИТОРИЯ

```
StealthBrowser/
├── StealthLauncher.cs          # Stealth.exe — запуск + проверка обновлений
├── StealthSetup.cs             # Однофайловый bootstrap-установщик
├── Install-Stealth.ps1         # Ядро установки
├── Stealth-Update.ps1          # GitHub releases API
├── Stealth-ApplyUpdate.ps1     # Применение обновления (видимая консоль)
├── Stealth-Engine.ps1          # Брендинг движка
├── version.json                # 1.0.0-beta
├── bundle/                     # Шаблоны профиля (LFS)
│   └── templates/
│       ├── user.js
│       ├── userChrome.css / .js
│       ├── userContent.css
│       └── distribution/policies.json
└── scripts/
    └── build-release.ps1
```

---

## ЛИЦЕНЗИЯ

Скрипты установки — MIT. Шрифты и ассеты — права их авторов. Mozilla Firefox — лицензия MPL.

---

**StealthBrowser** · Relicyos · `1.0.0-beta`
