# Происхождение ресурсов LATENTPUNK

## Музыка Creo

Автор и правообладатель: **Creo**. Официальный сайт: https://creo-music.com/ . Дата получения: **9 октября 2026**. Все 21 запрошенный трек сохранены в `assets/audio/music/creo/`.

### Разрешение

Официальный [FAQ Creo](http://faq.creo-music.com/), раздел «Can I use your music in my Videogame?»:

> If your game is free/non-commercial (no ads, in-game purchases, etc...) you are welcome to use any of my music against credit.

Автор разрешает любую свою музыку в **бесплатной некоммерческой игре с указанием авторства**, без рекламы и внутриигровых покупок. Если игра продаётся или иначе приносит прибыль, нужно отдельное соглашение, кроме релизов с подходящей свободной лицензией. Это специальное разрешение автора, а не вывод «некоммерческое значит разрешено».

[Sphere](https://creo-music.com/track/sphere) отдельно опубликована под [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [Epilogue](https://creo-music.com/track/epilogue) — под [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/). Остальные выбранные релизы использованы по разрешению FAQ; не приписывать им CC BY. Музыкальный кодекс прав отличается от подтверждённой участником договорённости по играм bench-portal.

### Формат и происхождение

Скачаны **полные публичные MP3-потоки официального Bandcamp Creo, 128 кбит/с**, с CDN `t4.bcbits.com`. Они не являются платными HQ/FLAC-загрузками. Файлы не обрезаны и не перекодированы; логины, платные загрузки и ограничения доступа не обходились. Официальные страницы ниже — постоянные ссылки; подписанные CDN-адреса в `audio/music/creo/provenance.json` служат записью происхождения и со временем истекают.

| Трек — официальная страница | Файл в `audio/music/creo/` | Длительность |
| --- | --- | --- |
| [We Can Dream](https://creo-music.com/track/we-can-dream) | `we-can-dream.mp3` | 3:29 |
| [Sphere](https://creo-music.com/track/sphere) | `sphere.mp3` | 4:00 |
| [Crazy](https://creo-music.com/track/crazy) | `crazy.mp3` | 3:36 |
| [Octane](https://creo-music.com/track/octane) | `octane.mp3` | 3:36 |
| [Dark Tides](https://creo-music.com/track/dark-tides) | `dark-tides.mp3` | 3:32 |
| [Epilogue](https://creo-music.com/track/epilogue) | `epilogue.mp3` | 4:08 |
| [Exoplanet](https://creo-music.com/track/exoplanet) | `exoplanet.mp3` | 4:07 |
| [Exosphere](https://creo-music.com/track/exosphere) | `exosphere.mp3` | 3:24 |
| [Awaken](https://creo-music.com/track/awaken) | `awaken.mp3` | 3:08 |
| [Lightmare](https://creo-music.com/track/lightmare) | `lightmare.mp3` | 5:01 |
| [Drift](https://creo-music.com/track/drift) | `drift.mp3` | 3:30 |
| [Red Haze](https://creo-music.com/track/red-haze) | `red-haze.mp3` | 3:20 |
| [Challenger](https://creo-music.com/track/challenger) | `challenger.mp3` | 2:53 |
| [Worlds](https://creo-music.com/track/worlds) | `worlds.mp3` | 4:17 |
| [Aurora](https://creo-music.com/track/aurora) | `aurora.mp3` | 3:20 |
| [Ballistic Funk](https://creo-music.com/track/ballistic-funk) | `ballistic-funk.mp3` | 3:22 |
| [Dune](https://creo-music.com/track/dune) | `dune.mp3` | 3:30 |
| [Endless](https://creo-music.com/track/endless) | `endless.mp3` | 3:20 |
| [Rivals](https://creo-music.com/track/rivals) | `rivals.mp3` | 4:31 |
| [Wavelight](https://creo-music.com/track/wavelight) | `wavelight.mp3` | 3:43 |
| [Never Make It](https://creo-music.com/track/never-make-it) | `never-make-it.mp3` | 3:54 |

### Авторство для титров и страницы игры

**Music by Creo — https://creo-music.com/**

Для каждого реально использованного трека указать **название, автора Creo и ссылку на официальную страницу** из таблицы. Для Sphere добавить ссылку CC BY 4.0, для Epilogue — CC BY-NC 4.0. Текущие файлы не изменены; если позже появятся обрезка, ремикс или другой монтаж, это отметить в авторстве и проверить условия соответствующего релиза. Скачивание библиотеки само по себе не добавляет титры в приложение: экран общей игры ещё предстоит поставить.

### Проверка и использование в проекте

`ffprobe` подтвердил MP3 и длительность, совпадающую с метаданными официальных страниц; **все 21 файла полностью декодированы `ffmpeg -xerror` без ошибок**. Суммарно 74673706 байт (около 71.2 MiB) и 77.67 минуты. SHA-256, размеры, длительности и происхождение — в `audio/music/creo/provenance.json`.

Это библиотека для выбора, а не готовый плейлист сцен. Музыка не подключена автоматически к шаблону и не назначена всему повествованию. В текущем Godot Web-пресете `all_resources`: вся библиотека увеличит экспорт, поэтому перед релизом выбрать реально нужные треки и проверить состав сборки. Не проигрывать музыку одновременно со звуком отдельной игры без согласованного микса; для хоррора сохранять тишину в ключевых переходах.

Формулировка джема «своя музыка» в PDF не разъяснена; музыка Creo не является оригинальной композицией участника. Наличие разрешённых файлов не отмечает автоматически выполненным этот пункт общего игрового чек-листа.

**Импорт в движок:** Godot 4.7.2 Standard успешно импортировал все 21 MP3 9 октября 2026; импорт проекта завершился с кодом 0 без ошибок скриптов или ресурсов. После подготовки материалов открыт редактор с текущим проектом. Веб-экспорт музыкальной библиотеки и микс сцен в этой задаче не проверялись.

## Ресурсы вступления

- Геометрия города, транспорта, интерьеров, мебели и прохожих создана процедурно в `scripts/intro/`; исходная форма хранится в GDScript, внешние модели и текстуры не заимствовались.
- `games/dead-parade/src/rendering/World.ts`, `Palette.ts` и `GameView.ts` использованы как художественный референс палитры, сборных силуэтов и архитектурной детализации. Код, модели, планировка и ресурсы мини-игры не переносились в сцену и не изменялись.
- `assets/shaders/intro_tape.gdshader`: новый экранный кассетный фильтр; зерно, строки, лёгкое цветовое размытие, округлая виньетка и муар по всему периметру. Это постоянное визуальное оформление, не сюжетная аномалия.
- Треки Creo во вступлении не назначены; музыкальная библиотека сохранена в проекте, но исключена из этой Web-сборки.

## Звуки вступления

Все звуки в `assets/audio/intro/` — реальные записи под лицензией CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/). Получены 9 октября 2026. Записи Freesound взяты из HQ-превью (MP3 128 кбит/с) на странице звука; паки Kenney — из официальных ZIP-архивов. Общая обработка (ffmpeg + numpy): удаление DC, фильтр ВЧ 40–200 Гц против гула, обрезка, плавные края, нормализация громкости по категориям, 44,1 кГц. Фоновые петли — стерео Ogg Vorbis q5 с равномощной склейкой 2 с; позиционные петли — моно Ogg Vorbis q4 со склейкой 1,5 с; короткие эффекты и шаги — моно PCM16 WAV. Шаги нарезаны по отдельным ударам с выравниванием по атаке и нормализованы по кратковременной громкости.

| Файл | Источник | Автор | Изменения |
| --- | --- | --- | --- |
| `step_street_1–5.wav` | Kenney Impact Sounds, `footstep_concrete_000–004` — https://kenney.nl/assets/impact-sounds | Kenney | ВЧ 60 Гц, обрезка, нормализация |
| `step_street_6–8.wav` | https://freesound.org/people/florianreichelt/sounds/459964/ | florianreichelt | три шага, ВЧ 70 Гц, НЧ 12 кГц |
| `step_lobby_1–8.wav` | https://freesound.org/people/ragamuffin/sounds/118985/ | ragamuffin | восемь шагов кожаной подошвы по мрамору с хвостом зала |
| `step_office_1–3.wav` | Kenney Impact Sounds, `footstep_carpet_000/001/003` | Kenney | ВЧ 60 Гц, обрезка, нормализация |
| `step_office_4–7.wav` | https://freesound.org/people/mlsulli/sounds/234855/ | mlsulli | четыре шага, НЧ 9 кГц |
| `step_office_8.wav` | https://freesound.org/people/jeroberts92/sounds/560477/ | jeroberts92 | один шаг, НЧ 9 кГц |
| `street_bed.ogg` | https://freesound.org/people/Pfannkuchn/sounds/457617/ + https://freesound.org/people/ValentinPetiteau/sounds/563547/ | Pfannkuchn; ValentinPetiteau | тихая улица (12–76 с) + птицы парка (−10 дБ, ВЧ 150 Гц), петля 60 с |
| `lobby_bed.ogg` | https://freesound.org/people/blaukreuz/sounds/747196/ + https://freesound.org/people/Soup_UnderScore/sounds/708021/ | blaukreuz; Soup_UnderScore | гул холла отеля (140–204 с, НЧ 11 кГц) + вентиляция, петля 60 с |
| `office_bed.ogg` | https://freesound.org/people/Soup_UnderScore/sounds/708021/ + https://freesound.org/people/SduggySounds/sounds/725718/ | Soup_UnderScore; SduggySounds | кондиционер пустого офиса + далёкая клавиатура (полоса 200–3500 Гц, короткое эхо, −14 дБ), петля 60 с |
| `car_loop.ogg` | https://freesound.org/people/lmbubec/sounds/119449/ + https://freesound.org/people/Anya_Media/sounds/437460/ | lmbubec; Anya_Media | холостой ход двигателя + шорох шин дороги, моно петля 11 с |
| `cafe_loop.ogg` | https://freesound.org/people/BeeProductive/sounds/375983/ + https://freesound.org/people/4team/sounds/214996/ | BeeProductive; 4team | разговоры и посуда кафе + терраса, моно петля 32 с |
| `bus_idle.ogg` | https://freesound.org/people/bikesnbassboi/sounds/540398/ | bikesnbassboi | холостой ход автобуса, НЧ 6 кГц, моно петля 17 с |
| `intersection_loop.ogg` | https://freesound.org/people/Anya_Media/sounds/437460/ | Anya_Media | спокойное движение (20–64 с), моно петля 42 с |
| `plaza_loop.ogg` | https://freesound.org/people/sphion/sounds/153552/ + https://freesound.org/people/khenshom/sounds/518929/ | sphion; khenshom | пешеходная улица + далёкие голоса и птицы, моно петля 42 с |
| `entrance_door.wav` | https://freesound.org/people/OroborosNZ/sounds/273651/ | OroborosNZ | автоматическая стеклянная дверь, первые 3,5 с |
| `lift_doors.wav` | https://freesound.org/people/NachtmahrTV/sounds/556699/ | NachtmahrTV | двери лифта, 0,2–5,6 с |
| `lift_ding.wav` | https://freesound.org/people/XfiXy8/sounds/467299/ | XfiXy8 | сигнал лифта, ВЧ 150 Гц, 2,4 с |
| `lift_travel.ogg` | https://freesound.org/people/Filmscore/sounds/825478/ | Filmscore | поездка в кабине, 3,5–17,5 с, плавные края |
| `office_door_open.wav` | https://freesound.org/people/RutgerMuller/sounds/104020/ | RutgerMuller | ручка и открывание деревянной двери |
| `office_door_close.wav` | https://freesound.org/people/amholma/sounds/344360/ | amholma | закрывание двери, 4,1–6,0 с |
| `ui_click.wav` | Kenney UI Audio, `click1` — https://kenney.nl/assets/ui-audio | Kenney | ВЧ 80 Гц, нормализация |
| `ui_wrong.wav` | Kenney Interface Sounds, `error_006` — https://kenney.nl/assets/interface-sounds | Kenney | ВЧ 80 Гц, нормализация |
| `computer_start.wav` | https://freesound.org/people/marlonnnnnn/sounds/351880/ | marlonnnnnn | нормализация, затухание 1,2 с |
| `street_bell_1.wav` | https://freesound.org/people/bsumusictech/sounds/81875/ | bsumusictech | полоса 200–5000 Гц, короткое эхо (эффект дистанции) |
| `street_bell_2.wav` | https://freesound.org/people/dm103/sounds/400695/ | dm103 | то же, 2,9–6,1 с |
| `street_door.wav` | https://freesound.org/people/wjtaylor/sounds/266682/ | wjtaylor | то же |
| `street_laugh.wav` | https://freesound.org/people/vumseplutten1709/sounds/264336/ | vumseplutten1709 | далёкий разговор со смехом, 4,5–7,8 с, полоса 250–3800 Гц, эхо |

## Материалы и шрифты вступления

- `assets/textures/intro/surface_grain.png` — процедурно созданная в рамках проекта бесшовная текстура 256×256; внешние изображения не использованы. `assets/shaders/intro_surface.gdshader` задаёт мировой масштаб рисунка штукатурки, кладки, мощения, асфальта, дерева и металла.
- Файлы `assets/fonts/OpenRunde-*.woff2` предоставлены участником и подключены через `assets/fonts/interface_theme.tres` к обычному интерфейсу и 3D-вывескам. Сохранено лицензионное уведомление `assets/fonts/LICENSE.txt`: SIL Open Font License 1.1, Copyright © 2016 The Inter Project Authors.
- Пиксельные шрифты Galmuri в `assets/interview/fonts/` оставлены для терминала; лицензионное уведомление сохранено в `assets/interview/fonts/OFL-Galmuri.txt`.
