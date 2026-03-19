Scope
- Этот файл относится только к проекту `codex-limits-menubar`.
- Не подтягивай workflow, конфиги и шаблоны из старого пути или родительских монореп, если пользователь явно не просил.
- Пути внутри файлов и документации записываются от git-root этого проекта.
- Машинозависимые абсолютные пути нельзя фиксировать в коде, документации или runtime-конфигах.
Product Goal
- Продукт — нативное macOS menu bar приложение, которое показывает лимиты Codex через локальный `codex app-server`.
- Главная ценность — быстрый и достоверный сигнал о лимитах без открытия UI.
- Если решение делает продукт менее надёжным ради магии или хака, агент должен возразить и предложить более устойчивую альтернативу.
Hard Boundaries
- Единственный поддерживаемый источник данных — локальный `codex app-server`.
- Нельзя добавлять browser scraping, DOM parsing, Playwright session reuse, cookies, private web endpoints или reverse engineering web traffic.
- Нельзя придумывать, подмешивать или скрывать stale data: при ошибке приложение должно показывать error или unavailable snapshot.
- Нельзя вшивать машинозависимые абсолютные пути к `node` или `codex` в исходники, bundle или docs; использовать runtime discovery и env overrides.
Architecture Map
- `src/app-server/jsonlAppServerClient.mjs` — JSON-RPC клиент для `codex app-server`.
- `src/rate-limits/menubarSnapshot.mjs` — нормализация ответа и формирование snapshot для UI.
- `src/cli/codex-limits-menubar-snapshot.mjs` — CLI entrypoint для получения snapshot.
- `macos/CodexLimitsMenuBar` — Swift и AppKit shell.
- `scripts/build-codex-limits-menubar-swift-app.sh` — сборка `.app` в `dist/`.
- `scripts/run-codex-limits-menubar-app.sh` — сборка и открытие приложения.
- `scripts/package-release-artifact.sh` — упаковка release artifact.
Change Rules
- Держать изменения минимальными и бить в корневую причину, а не маскировать симптомы UI-слоем.
- Любое изменение контракта между Node snapshot и Swift UI нужно менять согласованно по обе стороны.
- Новые зависимости добавлять только при явной продуктовой или эксплуатационной выгоде.
- Логи должны помогать диагностировать startup, refresh и app-server failures.
- При изменении поведения, setup, env vars, release flow или build flow обновлять `README.md`, `README.ru.md` и при необходимости `docs/releases/*`.
Validation
- Для изменений в Node-слое и форме snapshot использовать `npm run menubar:app:snapshot`.
- Для изменений в bundle или runtime flow использовать `npm run menubar:app:build`.
- Для release packaging использовать `npm run release:artifact`.
- Для Swift и AppKit изменений проверить, что приложение стартует и корректно показывает fallback при ошибке.
- Если шаг валидации нельзя выполнить, это нужно явно сообщить пользователю.
Build Artifacts And Hygiene
- `dist/` — generated output, а не source of truth.
- Нельзя редактировать файлы внутри `dist/`; менять нужно исходники и затем пересобирать приложение.
- Репозиторий должен оставаться чистым от generated artifacts, зависимостей и editor noise.
Decision Rule
- Если выбор стоит между clever hack и boring reliable path, выбирай boring reliable path.
