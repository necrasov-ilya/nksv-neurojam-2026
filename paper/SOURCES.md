# Каталог миров: исходники и готовые сборки

## Что перенесено

Перенос сделан **9 октября 2026**. По последнему решению участника для недостающих миров достаточно готовой сборки: обыгрываем запуск и переходы. Уже перенесённые исходники сохранены. Это независимые игры, ещё не интегрированные с лабораторией.

| Игра | Каталог | Тип поставки и содержимое | Происхождение |
| --- | --- | --- | --- |
| DUSTFALL | `games/dustfall/` | `src/main.ts`, `player.ts`, `world.ts`, `enemies.ts`, `operator.ts`, `loadout.ts`, `data.ts`, `audio.ts`, CSS и шрифты; `package.json`, `package-lock.json`, `tsconfig.json` | Собственный `../nksv-ml-bench-src/dustfall/` |
| DEAD PARADE — Lead the dead. | `games/dead-parade/` | `src/main.ts`, `core/`, `game/Simulation.ts`, `rendering/`, `ui/`, `audio/`, `utils/`; манифест, lock-файл, TS/Vite-конфигурация | Собственный `../nksv-ml-bench-src/dead-parade/` |
| Terrarium No 11 | `games/wow-terrarium-glm53-flash/` | `index.html`: 1256 строк читаемого inline JS/GLSL, функции генерации, `knock`, `setRain`, `setGlass`, цикл рендера | [alesha-pro/bench-portal](https://github.com/alesha-pro/bench-portal/tree/984d1b035125dad8cff96436862b96a92122a042/games/wow-terrarium-glm53-flash) |
| Tidebreak: Corsair Run | `games/boat-astra-deepseek/` | Готовая сборка: entry HTML, JS/CSS, favicon, обложка, метаданные и notice Three.js | [boat-astra-deepseek](https://github.com/alesha-pro/bench-portal/tree/984d1b035125dad8cff96436862b96a92122a042/games/boat-astra-deepseek) |
| FOGLINE — Bodycam // Sector 7 | `games/fogline/` | Готовая сборка: entry HTML, все 13 JS chunks, CSS, обложка и метаданные | [fogline](https://github.com/alesha-pro/bench-portal/tree/984d1b035125dad8cff96436862b96a92122a042/games/fogline) |

### Ревизии и точность переноса

- `nksv-ml-bench-src`: **`039fb9807f53b18abb6ae0bb1868a481913d4804`**. В DUSTFALL сохранены все 29 исходных файлов, в DEAD PARADE — все 25. Точное сравнение относительных путей и SHA-256 не выявило пропусков или изменений. Дополнительно в каждый каталог скопирован родительский MIT `LICENSE`; всего 30 и 26 файлов до установки зависимостей/сборки. Исходный соседний репозиторий не изменён.
- `bench-portal`: **`984d1b035125dad8cff96436862b96a92122a042`**. Все три файла террариума сверены с Git blob SHA-1 immutable upstream и перенесены побайтно.
- Из собственного репозитория `.git`, `node_modules`, готовые `dist/build` и кэши не переносились. Генерируемые локально зависимости/билды игнорируются в `.gitignore`; `games/.gdignore` исключает независимые веб-проекты из Godot-импорта. Опубликованные сборки катера и FOGLINE добавлены по обновлённому запросу отдельно, без изменения JS/CSS.

| Файл террариума | SHA-256 |
| --- | --- |
| `index.html` | `1307f63cc5ac5573c550a71095379f40827433ebc7a6647cef21d6bc64b653f5` |
| `game.json` | `7df608a9c4ae2aae4120a05d1914fb72f765f5a7f36ee347905f4c3704c308f3` |
| `cover.webp` | `3f3fb8743dc720cd6523f581e9d19ff98280186b4a072cbd05ad29424746f6ac` |

## Tidebreak и FOGLINE: поставка готовыми играми

Названия из концепта сопоставлены точно: **Tidebreak: Corsair Run — `boat-astra-deepseek`**, **FOGLINE — `fogline`**. Другие варианты катера не подставлялись.

- Катер: полностью перенесены **7 файлов**. Entry `index.html` использует относительные `./assets/index-OuvEgTv3.js` и `./assets/index-XdEcjRPf.css`; сохраняются favicon, cover, game.json и `licenses/three-MIT.txt`.
- FOGLINE: полностью перенесены **17 файлов**, включая все динамические JS chunks. Entry `index.html` использует `./assets/index-DxzvcXmo.js`. Переход в игровые экраны должен проверять динамические импорты, а не только стартовое меню.
- Все **24 файла** скачаны с immutable upstream-коммита `984d1b035125dad8cff96436862b96a92122a042`; суммарно **2435464 байта**. Главные JS-файлы совпадают с опубликованными Git blob hashes.
- SHA-256 катера, `assets/index-OuvEgTv3.js`: `1195f91caa9096249d1efe6cbd3359268ab0b630294a2c4bb0d124e012750853`.
- SHA-256 FOGLINE, `assets/index-DxzvcXmo.js`: `d18394af61103daa8b294a30c5e9ce953224da82f5c0d8b6c11e2b357390f541`.

В этих каталогах нет оригинальных `src`, манифестов/lock-файлов и source maps; это минифицированные production bundles, **не оригинальные исходные проекты**. Ранее проверены дерево/история портала, публичные источники владельца и ссылки — оригиналы не найдены. По обновлённому решению участника это больше не блокирует перенос.

Не обещать API завершения/параметров, изменение противников или аномалий внутри этих игр: такой контракт не подтверждён. Сначала ставим сюжетные переходы и запуск/возврат на уровне будущей оболочки. Внутреннюю минифицированную логику не правили.

## Лицензии и допуск

- DUSTFALL и DEAD PARADE: родительская **MIT License, Copyright (c) 2026 NKSV_ILYA** скопирована в оба проекта. DUSTFALL также сохраняет `public/CREDITS.md`, лицензию Three.js и SIL OFL 1.1 для Barlow/Barlow Condensed. Все девять локальных TTF-шрифтов перенесены.
- В опубликованном `bench-portal` нет общей лицензии на игровой код. **9 октября 2026 участник подтвердил, что договорился с владельцами и все выбранные игры можно использовать.** Это отдельное разрешение по сообщению участника, не лицензия MIT/CC и не вывод из публичности GitHub. Сохранить авторство и notices; повторно запрашивать уже подтверждённое разрешение не нужно.
- `licenses/three-MIT.txt` в катере разрешает использование Three.js, не самой игры. CDN-версия Three.js террариума тоже MIT: [лицензия 0.170.0](https://cdn.jsdelivr.net/npm/three@0.170.0/LICENSE).
- При упаковке зависимостей сохранить их license notices. Возможность использования выбранных игр подтверждена участником; в PDF такая договорённость не описана, см. [JAM_PLAN.md](JAM_PLAN.md).

## Запуск и сборка

Команды выполняются из корня LATENTPUNK. Установки и билды создают игнорируемые `node_modules/` и `dist/`; они не заменяют исходники.

### DUSTFALL

```bash
npm --prefix games/dustfall ci
npm --prefix games/dustfall run build
npm --prefix games/dustfall run preview -- --host 127.0.0.1 --port 4177 --strictPort
```

Открыть `http://127.0.0.1:4177/`. Для разработки: `npm --prefix games/dustfall run dev -- --host 127.0.0.1`.

Runtime: Three.js `^0.181.0`. Development: Vite `^7.1.13`, TypeScript `^5.9.3`, типы Three/Bun; точные версии фиксирует lock-файл. Это PvE extraction shooter: выбор экипировки, рейд, противники, добыча, эвакуация, потеря снаряжения при смерти. Entry: `index.html` → `/src/main.ts`. Локальные шрифты и notices сохранены; внешних runtime-ресурсов в просмотренном исходнике не найдено.

### DEAD PARADE

```bash
npm --prefix games/dead-parade ci
npm --prefix games/dead-parade run build
npm --prefix games/dead-parade run preview -- --host 127.0.0.1 --port 4178 --strictPort
```

Открыть `http://127.0.0.1:4178/`. Для разработки: `npm --prefix games/dead-parade run dev -- --host 127.0.0.1`; исходный dev-порт — 5175.

Runtime: Three.js `^0.180.0`. Development: Vite `^6.0.7`, TypeScript `^5.6.3`, типы Three; точные версии в lock-файле. Build выполняет `tsc --noEmit && vite build`. Игра об орде зомби: заражение и последователи, способности, улучшения, сюжетные районы и endless-режим. Entry: `index.html` → `/src/main.ts`. Геометрия, текстуры и звук создаются кодом; внешних runtime-ресурсов в просмотренном исходнике не найдено.

### Статические игры портала

Один сервер для всех трёх импортированных игр портала:

```bash
python3 -m http.server 4176 --bind 127.0.0.1 --directory games
```

| Игра | Адрес |
| --- | --- |
| Tidebreak: Corsair Run | `http://127.0.0.1:4176/boat-astra-deepseek/` |
| FOGLINE | `http://127.0.0.1:4176/fogline/` |
| Terrarium No 11 | `http://127.0.0.1:4176/wow-terrarium-glm53-flash/` |

Катер и FOGLINE уже собраны, npm/install/build не нужны. В HTML стоят относительные пути, поэтому проверять именно такие вложенные URL. Катер: W/S — газ/тормоз, A/D — поворот, Space — огонь, Shift — ускорение, Escape — пауза, R — рестарт; управление FOGLINE показывается его собственным меню.

Террариум тоже не требует сборщика: HTML содержит исходную программу. Нужны WebGL и ES-module import maps. **Three.js 0.170.0 загружается с jsDelivr**; без доступа к CDN автономность не гарантируется. Зависимость оставлена как в оригинале, локально библиотека не vendored.

Управление: drag/pinch — камера, клик по стеклу — стук, Space — дождь, N — день/ночь, T — пауза суточного цикла, C — дрейф камеры, G — стекло, R — сброс камеры, H — помощь. Биом, банка, растения и погода генерируются процедурно. `cover.webp` и `game.json` — метаданные каталога, не подмена кода.

## Что есть в bench-portal

На зафиксированной ревизии найдено **39 игровых каталогов**. Проверены названия по метаданным. Для остальных игр ниже **наличие оригинальных исходников и пригодность к интеграции не проверялись**; они не импортированы и не выбраны как главы.

| Каталог | Название |
| --- | --- |
| `arena-blast-mistral-large-4` | ARENA BLAST |
| `boat-astra-deepseek` | Tidebreak: Corsair Run |
| `boat-deepseek-astra` | Tidebreaker: Reef Assault |
| `boat-flash-glm` | Tidebreaker: Coral Run |
| `boat-glm-flash` | Tidebreaker: Harbor Nine |
| `breach-blacksite-astra` | BREACH — Blacksite |
| `breach-protocol-glm53-flash` | Breach Protocol |
| `daybreak-grok-4-7` | DAYBREAK // KILLHOUSE |
| `daybreak-omp-grok-4-7` | DAYBREAK // KILLHOUSE — OMP |
| `fogline` | FOGLINE — Bodycam // Sector 7 |
| `golden-hour-claude-haiku-5.5` | GOLDEN HOUR |
| `gpt-6-astra-2026-09-11` | GPT-6 Astra 11.09.2026 |
| `hanafubuki-grok-4-7` | Hanafubuki |
| `highrise-protocol-5.6-luna` | Highrise Protocol |
| `highrise-protocol-qwen3.8-27b` | Highrise Protocol |
| `highrise-protocol-qwen3.8-flash-next` | Highrise Protocol |
| `highrise-protocol-qwen3.8-max` | Highrise Protocol |
| `kart-astra-deepseek` | Lumen Rally |
| `kart-astra-solo` | Tidebloom Rally |
| `kart-deepseek-astra` | Zephyr Reef Grand Prix |
| `kart-deepseek-solo` | Prismfall Grand Prix |
| `kerr-protocol-glm-5.3` | Kerr Protocol |
| `onslaught-fable-5.1` | Onslaught |
| `overrun-claude-opus-5.5` | OVERRUN — Dockyard Nine |
| `overrun-deepseek-v4.1` | OVERRUN |
| `ox-alpha` | Ox Alpha |
| `pagoda-ac130-glm53-flash` | Pagoda Garden AC-130 |
| `retrocraft-qwen3.8-27b` | RetroCraft |
| `rig-3090-astra` | RIG / 3090 — Anatomy of a Rig |
| `rig-3090-fable-5.1` | RIG · 4× RTX 3090 |
| `trenchcam-claude-opus-5.5` | TRENCHCAM — BLOCK 17 |
| `vesper-cathedral-of-ash` | VESPER: Cathedral of Ash |
| `voidbound-choir-of-ash` | VOIDBOUND: The Choir of Ash |
| `voidbreaker-union-alpha` | VOIDBREAKER |
| `voidrunner-astra` | VOIDRUNNER: Orbital Combat League |
| `whiteout-protocol-glm-5.3` | Whiteout Protocol |
| `wow-drift-city-glm53-flash` | Drift City |
| `wow-mandelbulb-glm53-flash` | Mandelbulb |
| `wow-terrarium-glm53-flash` | Terrarium No 11 |
