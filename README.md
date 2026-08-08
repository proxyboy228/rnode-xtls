# rnode-xtls

Генератор **скрытой Remnawave-ноды** (remnanode) со **скрытым ядром Xray** —
с **оригинальным, официальным** ядром из
[`XTLS/Xray-core`](https://github.com/XTLS/Xray-core).

Это исправленная версия оригинального `rnode.sh`. Механизм «скрытности» и
функционал ноды не изменены; добавлены только фиксы (см. ниже). Ядро Xray
всегда скачивается из релизов XTLS и встраивается в образ.

> Есть парный репозиторий с тем же скриптом, но ядром из форка
> `Jolymmiles/Xray-core` — единственное отличие между ними в источнике ядра.

## Быстрый старт (curl)

Интерактивное меню:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/proxyboy228/rnode-xtls/main/rnode.sh)
```

Сразу указать команду:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/proxyboy228/rnode-xtls/main/rnode.sh) generate
```

Альтернатива через pipe (интерактивный ввод читается из `/dev/tty`):

```bash
curl -fsSL https://raw.githubusercontent.com/proxyboy228/rnode-xtls/main/rnode.sh | bash -s -- generate
```

> Замените `proxyboy228/rnode-xtls` на свой `<user>/<repo>`, если назвали
> репозиторий иначе. Для `curl`-запуска репозиторий должен быть **публичным**.

## Команды

| Команда    | Действие                                            |
|------------|-----------------------------------------------------|
| `generate` | Выбор варианта маскировки по категории (интерактив) |
| `random`   | Случайный вариант с возможностью reroll             |
| `check`    | Проверка зависимостей системы                       |
| `clean`    | Удалить сгенерированные файлы                        |
| `help`     | Справка                                             |

## Требования

- `docker` + `docker compose` (или `docker-compose`)
- `curl`, `unzip`
- `python3` **или** `jq` — для онлайн-меню выбора версии ядра (необязательно)

## Что исправлено относительно оригинального rnode.sh

- **Wrapper `rw-core` использует `#!/usr/bin/bash`, а не `#!/bin/sh`.**
  Флаг `exec -a <name>` (подмена `argv[0]` для маскировки процесса) — это
  bash-изм; под dash (`/bin/sh` в образе `remnawave/node`) он падает с
  `exec: -a: not found`, и ядро Xray не стартует.
- **Авто-`sudo` для docker**, когда пользователь не в группе `docker`
  (иначе `permission denied … /var/run/docker.sock` при `docker compose up`).
- **Устойчивый резолвинг версии** из GitHub Releases (корректно и для
  «красивого», и для компактного JSON).

## Как это «скрыто»

- Базовый образ `remnawave/node:latest`; бинарник Xray переименовывается в имя
  типичного системного демона (`nginx`, `redis-server`, `postgres`, …).
- Имена сокетов supervisord и internal-REST токена рандомизируются в
  `docker-entrypoint.sh`.
- Контейнер/хостнейм/лейблы образа маскируются под системный сервис.

## Ядро Xray

Источник: **https://github.com/XTLS/Xray-core**

Ядро скачивается из релизов (`Xray-linux-<arch>.zip`), проверяется по SHA-256
из сопутствующего `.dgst`, распаковывается и встраивается в образ на этапе
`docker build`.

## Артефакты

Скрипт создаёт в выбранной папке: `.Dockerfile`, `docker-compose.yml`,
`docker-entrypoint.sh`, `.env`, `.env.example`, `xray-core/`. Они добавлены в
`.gitignore`.
