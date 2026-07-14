# PropDevelopment Security Project Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Подготовить проверяемые решения Task1–Task7 для проектной работы по аудиту безопасности PropDevelopment.

**Architecture:** Репозиторий состоит из семи независимых каталогов с диаграммами, Markdown-документами, Kubernetes-манифестами и Bash-скриптами. Общий README связывает решения, описывает исходные данные и команды проверки; каждый технический артефакт проверяется локально без зависимости от публикации в GitHub.

**Tech Stack:** draw.io XML, Markdown, Kubernetes YAML, Bash, `kubectl`, `minikube`, `jq`, Dockerized `yq`, Python standard library для структурных проверок.

---

Все команды выполняются из корня `/home/erda/Музыка/yandex-4-sprint/architecture-pro-propdevelopment`. Перед каждым `git add` обязательно выполнить `git status --short`; добавлять только перечисленные в шаге новые файлы.

## Карта файлов

- `README.md` — состав проекта, исходники, быстрые проверки и ограничение по отсутствующему audit.log.
- `Task1/data-security-mindmap.drawio` — классификация данных, риски, оценки и обоснования.
- `Task2/security-checklist.md` — обоснование разделов и заполненный чек-лист.
- `Task3/context.drawio` — C4 System Context для функций умного дома.
- `Task3/containers.drawio` — обновлённая C4 Container-диаграмма.
- `Task3/integration-requirements.md` — требования безопасности и взаимодействия.
- `Task4/roles.md` — таблица ролей, прав и организационных групп.
- `Task4/01-create-users.sh` — ключи, CSR/сертификаты и kubeconfig минимум для двух пользователей.
- `Task4/02-create-roles.sh` — RBAC-роли без неявной эскалации.
- `Task4/03-bind-roles.sh` — привязки пользователей/групп к ролям.
- `Task5/non-admin-api-allow.yaml` — namespace, четыре Nginx Deployment/Service и NetworkPolicy.
- `Task6/analysis.md` — анализ ожидаемых событий с оговоркой о происхождении.
- `Task6/audit-extract.json` — синтетический JSON-массив событий для демонстрации.
- `Task6/filter-audit.sh` — фильтрация внешнего JSON Lines audit.log.
- `Task7/01-create-namespace.yaml` — `audit-zone` с PSA restricted.
- `Task7/insecure-manifests/*.yaml` — privileged, hostPath и UID 0.
- `Task7/secure-manifests/*.yaml` — три исправленных Pod-манифеста.
- `Task7/gatekeeper/constraint-templates/*.yaml` — три ConstraintTemplate.
- `Task7/gatekeeper/constraints/*.yaml` — три Constraint.
- `Task7/verify/*.sh` — проверки PSA/Gatekeeper и полей безопасности.
- `Task7/audit-policy.yaml` — политика аудита значимых ресурсов.
- `Task7/README_FOR_REVIEWER.md` — порядок воспроизведения.

### Task 1: Базовая структура и документация

**Files:**
- Create: `README.md`
- Create: `Task1/` … `Task7/`
- Reference: `docs/superpowers/specs/2026-07-14-propdevelopment-security-project-design.md`

- [ ] **Step 1: Создать каталоги Task1–Task7 и корневой README**

README перечисляет входные файлы, артефакты каждого задания, команды `bash -n`, `jq`, XML/YAML-проверки и предупреждение, что публикация выполняется отдельно.

- [ ] **Step 2: Проверить структуру**

Run: `for n in {1..7}; do test -d "Task$n"; done`
Expected: exit code 0.

- [ ] **Step 3: Commit**

Run: `git status --short && git add README.md && git commit -m "chore: scaffold sprint project"`

Expected: коммит содержит только README; пустые Task-каталоги появятся в Git вместе с артефактами следующих задач.

### Task 2: Mind map классификации данных

**Files:**
- Create: `Task1/data-security-mindmap.drawio`

- [ ] **Step 1: Сформировать матрицу содержимого**

Включить четыре класса: публичные данные (описания объектов, публичные тарифы), внутренние (планы ремонтов, техданные, журналы), конфиденциальные (ФИО, контакты, платёжные и договорные данные), секретные (биометрические шаблоны, учётные данные, ключи/токены). Для каждого типа указать один-два наиболее существенных риска, оценку и короткую причинно-следственную формулировку.

- [ ] **Step 2: Создать центральный узел и четыре ветви draw.io XML**

Использовать отдельную ветвь на каждый класс данных и читаемые подписи без декоративной перегрузки.

- [ ] **Step 3: Добавить листья данных, рисков, оценок и обоснований**

Каждая ветвь содержит минимум два типа данных; каждый тип — `Риск: ...`, `Оценка: ...`, `Почему: ...`.

- [ ] **Step 4: Проверить XML и обязательные категории**

Run: `python3 -c 'import xml.etree.ElementTree as E; E.parse("Task1/data-security-mindmap.drawio")' && for x in Публичные Внутренние Конфиденциальные Секретные; do grep -q "$x" Task1/data-security-mindmap.drawio; done`
Expected: exit code 0.

- [ ] **Step 5: Commit**

Run: `git add Task1 && git commit -m "docs: classify PropDevelopment data risks"`

### Task 3: Чек-лист бизнес-систем

**Files:**
- Create: `Task2/security-checklist.md`
- Reference: `/home/erda/Музыка/yandex-4-sprint/IB.md`

- [ ] **Step 1: Написать обоснование выбранных разделов**

Связать управление доступом с ошибками tenant isolation, безопасность данных — с ПДн и сырыми CDC-потоками, инфраструктуру — с гибридной средой/Kubernetes, инциденты — с отсутствием системного контроля, специфические проверки — с мобильным приложением и биометрией.

- [ ] **Step 2: Скопировать строки шаблона и заполнить колонку статуса**

Использовать значения `Да`, `Нет`, `Частично`, `Нет данных — требуется проверка`. В комментариях отделить факт кейса от рекомендации и назвать затронутые системы.

- [ ] **Step 3: Заполнить комментарии фактами и ожидаемыми проверками**

Каждая строка получает короткое основание: подтверждённый факт кейса либо конкретный вопрос аудита.

- [ ] **Step 4: Проверить отсутствие пустых ответов**

Run: `awk -F'|' '/^\| [0-9]+ / {gsub(/ /,"",$4); if ($4=="") bad=1} END {exit bad}' Task2/security-checklist.md`
Expected: exit code 0.

- [ ] **Step 5: Commit**

Run: `git add Task2 && git commit -m "docs: add business systems security checklist"`

### Task 4: C4 и требования внешней интеграции

**Files:**
- Create: `Task3/context.drawio`
- Create: `Task3/containers.drawio`
- Create: `Task3/integration-requirements.md`
- Reference: `/home/erda/Музыка/yandex-4-sprint/PropDevelopment_С4_model.drawio.xml`

- [ ] **Step 1: Создать каркас контекстной диаграммы**

Показать собственника, мобильное приложение/систему PropDevelopment, платформу партнёра, устройства домофона/шлагбаума и оператора УК. Подписать потоки управления доступом и события устройств.

- [ ] **Step 2: Добавить границы и подписанные связи context.drawio**

Системная граница включает PropDevelopment; платформа/устройства партнёра находятся снаружи; стрелки указывают HTTPS/API и события устройств.

- [ ] **Step 3: Создать каркас контейнерной диаграммы**

Сохранить узнаваемые существующие контейнеры ЖКУ и добавить API Gateway, Smart Home Integration Service, consent/access registry, audit stream; партнёрскую платформу разместить за границей предприятия.

- [ ] **Step 4: Добавить связи и trust boundaries containers.drawio**

Мобильная витрина идёт через API Gateway; интеграционный сервис обращается к consent registry и партнёру; audit stream принимает события без секретов/биометрических шаблонов.

- [ ] **Step 5: Написать требования аутентификации и доступа**

Зафиксировать TLS 1.2+, mTLS, OAuth 2.0/OIDC, client credentials, scopes/tenant claims, deny-by-default, consent, минимизацию биометрии, secret rotation, rate limits, timeouts/circuit breaker, идемпотентность, аудит, DPA/SLA и отзыв доступа.

- [ ] **Step 6: Написать требования надёжности, аудита и эксплуатации**

Отдельными пунктами описать timeout/retry/circuit breaker, идемпотентный request ID, rate limit, SLA, ротацию секретов и процедуру отключения партнёра.

- [ ] **Step 7: Проверить XML и ключевые требования**

Run: `python3 - <<'PY'
import xml.etree.ElementTree as E
for p in ('Task3/context.drawio','Task3/containers.drawio'): E.parse(p)
PY
grep -Eq 'OAuth|OIDC' Task3/integration-requirements.md && grep -q 'mTLS' Task3/integration-requirements.md`
Expected: exit code 0.

- [ ] **Step 8: Commit**

Run: `git add Task3 && git commit -m "docs: design secure smart home integration"`

### Task 5: Kubernetes RBAC

**Files:**
- Create: `Task4/roles.md`
- Create: `Task4/01-create-users.sh`
- Create: `Task4/02-create-roles.sh`
- Create: `Task4/03-bind-roles.sh`
- Reference: `/home/erda/Музыка/yandex-4-sprint/Шаблон_проектная_работа_5спринт.md`

- [ ] **Step 1: Заполнить таблицу ролей**

Описать `cluster-viewer`, `namespace-developer`, `platform-operator`, `security-secret-reader` и отдельную `limited-security-admin`. Последняя читает audit-facing ресурсы и NetworkPolicy/Pod security configuration, но не получает `bind`, `escalate`, impersonate или `cluster-admin`. Сопоставить аналитикам/менеджерам, разработчикам, инженерам эксплуатации/DevOps и специалисту ИБ. Только `security-secret-reader` получает `get/list` Secrets в рабочем namespace.

- [ ] **Step 2: Написать скрипт пользователей**

Создать минимум `developer1` (group `developers`) и `operator1` (group `platform-operators`). При наличии согласованной пары `.key/.crt` повторно использовать её; при наличии только одного файла завершаться с ошибкой. Для нового пользователя: `openssl genrsa`, CSR с `O=<group>`, API CSR с `signerName: kubernetes.io/kube-apiserver-client`, usages `client auth`, `kubectl apply`, approve, ожидание сертификата, extraction и отдельный kubeconfig. Перед пересозданием несовместимого CSR явно удалить только одноимённый CSR после подтверждённого отсутствия локального сертификата. Результаты писать в игнорируемый `Task4/.credentials/`.

- [ ] **Step 3: Написать роли с режимом `--render`**

`02-create-roles.sh --render` печатает только multi-document YAML; без флага передаёт тот же вывод в `kubectl apply -f -`. Namespace-роли ограничить `propdevelopment`, не разрешать изменение Role/RoleBinding.

- [ ] **Step 4: Написать привязки с режимом `--render`**

`03-bind-roles.sh --render` печатает только YAML. Связать группы `viewers`, `developers`, `platform-operators`, `security` и двух пользователей с согласованными ролями.

- [ ] **Step 5: Проверить shell и RBAC dry-run**

Run: `bash -n Task4/*.sh && Task4/02-create-roles.sh --render | kubectl apply --dry-run=client -f - && Task4/03-bind-roles.sh --render | kubectl apply --dry-run=client -f -`
Expected: shell exit 0; все отрендеренные RBAC-объекты проходят client dry-run.

- [ ] **Step 6: Commit**

Run: `git add Task4 && git commit -m "feat: add Kubernetes RBAC setup"`

### Task 6: NetworkPolicy

**Files:**
- Create: `Task5/non-admin-api-allow.yaml`

- [ ] **Step 1: Написать ресурсы и default deny**

Создать namespace `traffic-zone`, четыре Deployment/Service на Nginx с метками `role`, default-deny ingress/egress. Каждый Pod содержит Nginx и sidecar `busybox` с `sleep`, из которого выполняются сетевые пробы.

- [ ] **Step 2: Добавить парные политики**

Разрешить TCP/80 в обоих направлениях только для `front-end` ↔ `back-end-api` и `admin-front-end` ↔ `admin-back-end-api`; каждое правило задаёт source и destination role selector. DNS egress разрешить только к pod с `k8s-app: kube-dns` в namespace с `kubernetes.io/metadata.name: kube-system`, UDP/TCP 53.

- [ ] **Step 3: Проверить YAML**

Run: `kubectl apply --dry-run=client -f Task5/non-admin-api-allow.yaml`
Expected: все ресурсы parsed/configured (dry run), exit code 0.

- [ ] **Step 4: Развернуть ресурсы в Minikube с поддержкой NetworkPolicy**

Run: `minikube start --cni=calico && kubectl apply -f Task5/non-admin-api-allow.yaml && kubectl -n traffic-zone rollout status deploy --all --timeout=180s`
Expected: четыре Deployment готовы.

- [ ] **Step 5: Проверить полную матрицу соединений**

Run для каждого source Deployment: `kubectl -n traffic-zone exec deploy/<source>-app -c probe -- wget -qO- --timeout=2 http://<target>-app`
Expected: `front-end→back-end-api`, `back-end-api→front-end`, `admin-front-end→admin-back-end-api`, `admin-back-end-api→admin-front-end` успешны; все восемь cross-pair направлений завершаются ненулевым кодом.

- [ ] **Step 6: Commit**

Run: `git add Task5 && git commit -m "feat: isolate application traffic with network policies"`

### Task 7: Анализ Kubernetes audit log

**Files:**
- Create: `Task6/filter-audit.sh`
- Create: `Task6/audit-extract.json`
- Create: `Task6/analysis.md`

- [ ] **Step 1: Создать тестовый JSON Lines fixture во временном каталоге**

Включить ожидаемые audit-события get secrets, create privileged pod, create pods/exec и create RoleBinding на cluster-admin. Каждая запись получает annotation `propdevelopment.dev/fixture: synthetic`. Не включать вымышленное API-событие удаления AuditPolicy.

- [ ] **Step 2: Написать фильтр**

Скрипт принимает `INPUT=${1:-audit.log}` и `OUTPUT=${2:-audit-extract.json}`, использует `jq -s` и безопасные optional-пути для четырёх API-индикаторов. Пятый индикатор — только строковое упоминание `audit-policy` в исходной JSON-записи; оно маркируется как mention, а не удаление API-ресурса.

- [ ] **Step 3: Запустить фильтр на fixture**

Run: `Task6/filter-audit.sh /tmp/audit-fixture.log Task6/audit-extract.json && jq -e 'length >= 4' Task6/audit-extract.json`
Expected: JSON-массив минимум из четырёх событий.

- [ ] **Step 4: Проверить malformed/optional поля**

Run: `printf '%s\n' '{}' '{"objectRef":null}' 'not-json' >/tmp/audit-bad.log; ! Task6/filter-audit.sh /tmp/audit-bad.log /tmp/out.json`
Expected: скрипт сообщает номер некорректной строки и завершает работу ненулевым кодом без частичного output.

- [ ] **Step 5: Написать analysis.md**

Для каждого события описать ожидаемого инициатора, namespace, риск и RBAC-ошибку. Отдельно обозначить synthetic provenance и неподтверждённую попытку удаления локального файла audit-policy.

- [ ] **Step 6: Обновить корневой README provenance-оговоркой**

Указать, что каждая запись `audit-extract.json` — synthetic/demo, не извлечена из реального лога и не подтверждает фактический инцидент; избегать слов «наблюдалось» и «обнаружено» без условной формулировки.

- [ ] **Step 7: Commit**

Run: `git status --short && git add README.md Task6/analysis.md Task6/audit-extract.json Task6/filter-audit.sh && git commit -m "feat: add Kubernetes audit incident analysis"`

### Task 8: PodSecurity и Gatekeeper

**Files:**
- Create: `Task7/01-create-namespace.yaml`
- Create: `Task7/insecure-manifests/01-privileged-pod.yaml`
- Create: `Task7/insecure-manifests/02-hostpath-pod.yaml`
- Create: `Task7/insecure-manifests/03-root-user-pod.yaml`
- Create: `Task7/secure-manifests/01-secure.yaml`
- Create: `Task7/secure-manifests/02-secure.yaml`
- Create: `Task7/secure-manifests/03-secure.yaml`
- Create: `Task7/gatekeeper/constraint-templates/{privileged,hostpath,runasnonroot}.yaml`
- Create: `Task7/gatekeeper/constraints/{privileged,hostpath,runasnonroot}.yaml`
- Create: `Task7/verify/verify-admission.sh`
- Create: `Task7/verify/validate-security.sh`
- Create: `Task7/audit-policy.yaml`
- Create: `Task7/README_FOR_REVIEWER.md`

- [ ] **Step 1: Написать namespace и небезопасные Pods**

Namespace `audit-zone` получает `enforce: restricted`, `enforce-version: latest`, `warn: restricted`. Манифесты содержат ровно заявленные нарушения и пригодны для демонстрации отклонения.

- [ ] **Step 2: Написать безопасные Pods**

Каждый контейнер задаёт `runAsNonRoot: true`, non-zero UID, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`; Pod задаёт `seccompProfile.type: RuntimeDefault`. Для Nginx добавить `emptyDir` mounts для `/var/cache/nginx`, `/var/run` и `/tmp`, затем проверить готовность Pod, а не только admission.

- [ ] **Step 3: Написать Gatekeeper templates/constraints**

Rego просматривает все containers/initContainers/ephemeralContainers; hostPath проверяется по `spec.volumes`; constraints ограничены Pod и namespace `audit-zone`.

- [ ] **Step 4: Написать audit policy и PSA-проверку**

`verify-admission.sh` в `audit-zone` проверяет ожидаемые PSA reject/accept через server dry-run, затем разворачивает безопасные Pods и ждёт Ready. `audit-policy.yaml` проверять как конфигурационный YAML через version-pinned Dockerized yq, но никогда через `kubectl apply`. Интеграционный запуск API server с этой политикой не входит в обязательную локальную проверку: он требует отдельного mount/copy в Minikube node и audit-log flags.

- [ ] **Step 5: Написать отдельную Gatekeeper-проверку**

`validate-security.sh` устанавливает version-pinned Gatekeeper manifest, ждёт `deployment/gatekeeper-controller-manager`, создаёт временный namespace `gatekeeper-test` без PSA enforce, применяет constraints с namespace match для `audit-zone` и `gatekeeper-test`, затем server-dry-run проверяет отдельный reject каждого нарушения и accept безопасного Pod. После теста удаляет только `gatekeeper-test`. README фиксирует команды и ожидаемые результаты.

- [ ] **Step 6: Проверить синтаксис и core manifests**

Run: `bash -n Task7/verify/*.sh && kubectl apply --dry-run=client -f Task7/01-create-namespace.yaml -f Task7/insecure-manifests -f Task7/secure-manifests && docker run --rm -v "$PWD:/work" mikefarah/yq:4.44.3 eval '.apiVersion == "audit.k8s.io/v1" and .kind == "Policy" and (.rules | length > 0)' /work/Task7/audit-policy.yaml | grep -qx true`
Expected: shell/core manifests/audit config parse and semantic check returns `true`.

- [ ] **Step 7: Установить Gatekeeper и проверить CRD-aware manifests**

Run: `kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.17.1/deploy/gatekeeper.yaml && kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=300s && kubectl apply -f Task7/gatekeeper/constraint-templates && kubectl wait --for=condition=Established crd/k8sdenyprivileged.constraints.gatekeeper.sh crd/k8sdenyhostpath.constraints.gatekeeper.sh crd/k8srequirenonrootreadonly.constraints.gatekeeper.sh --timeout=180s && kubectl apply --dry-run=server -f Task7/gatekeeper/constraints`
Expected: controller ready; templates persist, три generated CRD Established, constraints accepted by server dry-run. После проверки удаляются только созданные constraints/templates и тестовый namespace; установка Gatekeeper сохраняется, если пользователь не запросил её удаление.

- [ ] **Step 8: Commit**

Run: `git add Task7 && git commit -m "feat: enforce container security policies"`

### Task 9: Итоговая проверка

**Files:**
- Modify: `README.md`
- Test: all `Task1`–`Task7` artifacts

- [ ] **Step 1: Проверить полный список файлов**

Run: `test -f Task1/data-security-mindmap.drawio && test -f Task2/security-checklist.md && test -f Task3/context.drawio && test -f Task3/containers.drawio && test -f Task3/integration-requirements.md && test "$(find Task4 -maxdepth 1 -type f | wc -l)" -eq 4 && test -f Task5/non-admin-api-allow.yaml && test "$(find Task6 -maxdepth 1 -type f | wc -l)" -eq 3 && test "$(find Task7 -type f | wc -l)" -eq 17`
Expected: exit code 0.

- [ ] **Step 2: Запустить единый набор статических проверок**

Run: `set -e; bash -n Task4/*.sh Task6/*.sh Task7/verify/*.sh && jq -e 'type=="array"' Task6/audit-extract.json && python3 -c 'import xml.etree.ElementTree as E; [E.parse(p) for p in ("Task1/data-security-mindmap.drawio","Task3/context.drawio","Task3/containers.drawio")]' && kubectl apply --dry-run=client -f Task5/non-admin-api-allow.yaml && grep -q 'synthetic/demo' README.md && grep -q 'Нет данных' Task2/security-checklist.md`
Expected: exit code 0.

- [ ] **Step 3: Проверить рабочее дерево и историю**

Run: `git status --short && git log --oneline --decorate -12`
Expected: только намеренные изменения; отдельные осмысленные коммиты.

- [ ] **Step 4: Запросить code review**

Использовать `superpowers:requesting-code-review`; исправить обязательные замечания и повторить итоговую проверку.

- [ ] **Step 5: Финальный commit при необходимости**

Run: `git add README.md && git commit -m "docs: finalize reviewer instructions"`
