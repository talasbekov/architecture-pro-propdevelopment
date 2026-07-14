# PropDevelopment Security Project Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Подготовить проверяемые решения Task1–Task7 для проектной работы по аудиту безопасности PropDevelopment.

**Architecture:** Репозиторий состоит из семи независимых каталогов с диаграммами, Markdown-документами, Kubernetes-манифестами и Bash-скриптами. Общий README связывает решения, описывает исходные данные и команды проверки; каждый технический артефакт проверяется локально без зависимости от публикации в GitHub.

**Tech Stack:** draw.io XML, Markdown, Kubernetes YAML, Bash, `kubectl`, `minikube`, `jq`, Python standard library для структурных проверок.

---

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
- `Task5/non-admin-api-allow.yaml` — namespace, четыре Nginx-сервиса и NetworkPolicy.
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

Run: `git add README.md Task* && git commit -m "chore: scaffold sprint project"`

### Task 2: Mind map классификации данных

**Files:**
- Create: `Task1/data-security-mindmap.drawio`

- [ ] **Step 1: Сформировать матрицу содержимого**

Включить четыре класса: публичные данные (описания объектов, публичные тарифы), внутренние (планы ремонтов, техданные, журналы), конфиденциальные (ФИО, контакты, платёжные и договорные данные), секретные (биометрические шаблоны, учётные данные, ключи/токены). Для каждого типа указать один-два наиболее существенных риска, оценку и короткую причинно-следственную формулировку.

- [ ] **Step 2: Создать draw.io XML**

Использовать отдельную ветвь на каждый класс данных и читаемые подписи без декоративной перегрузки.

- [ ] **Step 3: Проверить XML и обязательные категории**

Run: `python3 -c 'import xml.etree.ElementTree as E; E.parse("Task1/data-security-mindmap.drawio")' && for x in Публичные Внутренние Конфиденциальные Секретные; do grep -q "$x" Task1/data-security-mindmap.drawio; done`
Expected: exit code 0.

- [ ] **Step 4: Commit**

Run: `git add Task1 && git commit -m "docs: classify PropDevelopment data risks"`

### Task 3: Чек-лист бизнес-систем

**Files:**
- Create: `Task2/security-checklist.md`
- Reference: `/home/erda/Музыка/yandex-4-sprint/IB.md`

- [ ] **Step 1: Написать обоснование выбранных разделов**

Связать управление доступом с ошибками tenant isolation, безопасность данных — с ПДн и сырыми CDC-потоками, инфраструктуру — с гибридной средой/Kubernetes, инциденты — с отсутствием системного контроля, специфические проверки — с мобильным приложением и биометрией.

- [ ] **Step 2: Заполнить Markdown-таблицу**

Использовать значения `Да`, `Нет`, `Частично`, `Нет данных — требуется проверка`. В комментариях отделить факт кейса от рекомендации и назвать затронутые системы.

- [ ] **Step 3: Проверить отсутствие пустых ответов**

Run: `awk -F'|' '/^\| [0-9]+ / {gsub(/ /,"",$4); if ($4=="") bad=1} END {exit bad}' Task2/security-checklist.md`
Expected: exit code 0.

- [ ] **Step 4: Commit**

Run: `git add Task2 && git commit -m "docs: add business systems security checklist"`

### Task 4: C4 и требования внешней интеграции

**Files:**
- Create: `Task3/context.drawio`
- Create: `Task3/containers.drawio`
- Create: `Task3/integration-requirements.md`
- Reference: `/home/erda/Музыка/yandex-4-sprint/PropDevelopment_С4_model.drawio.xml`

- [ ] **Step 1: Создать контекстную диаграмму**

Показать собственника, мобильное приложение/систему PropDevelopment, платформу партнёра, устройства домофона/шлагбаума и оператора УК. Подписать потоки управления доступом и события устройств.

- [ ] **Step 2: Создать контейнерную диаграмму**

Сохранить узнаваемые существующие контейнеры ЖКУ и добавить API Gateway, Smart Home Integration Service, consent/access registry, audit stream; партнёрскую платформу разместить за границей предприятия.

- [ ] **Step 3: Написать требования интеграции**

Зафиксировать TLS 1.2+, mTLS, OAuth 2.0/OIDC, client credentials, scopes/tenant claims, deny-by-default, consent, минимизацию биометрии, secret rotation, rate limits, timeouts/circuit breaker, идемпотентность, аудит, DPA/SLA и отзыв доступа.

- [ ] **Step 4: Проверить XML и ключевые требования**

Run: `python3 - <<'PY'
import xml.etree.ElementTree as E
for p in ('Task3/context.drawio','Task3/containers.drawio'): E.parse(p)
PY
grep -Eq 'OAuth|OIDC' Task3/integration-requirements.md && grep -q 'mTLS' Task3/integration-requirements.md`
Expected: exit code 0.

- [ ] **Step 5: Commit**

Run: `git add Task3 && git commit -m "docs: design secure smart home integration"`

### Task 5: Kubernetes RBAC

**Files:**
- Create: `Task4/roles.md`
- Create: `Task4/01-create-users.sh`
- Create: `Task4/02-create-roles.sh`
- Create: `Task4/03-bind-roles.sh`
- Reference: `/home/erda/Музыка/yandex-4-sprint/Шаблон_проектная_работа_5спринт.md`

- [ ] **Step 1: Заполнить таблицу ролей**

Описать `cluster-viewer`, `namespace-developer`, `platform-operator`, `security-secret-reader`; сопоставить аналитикам/менеджерам, разработчикам, инженерам эксплуатации/DevOps и специалисту ИБ. Явно запретить обычным ролям Secrets, RBAC bind/escalate и cluster-admin.

- [ ] **Step 2: Написать скрипт пользователей**

Создать минимум `developer1` и `operator1`: `openssl genrsa`, CSR, `kubectl certificate approve`, извлечение сертификата и отдельный kubeconfig. Писать результаты в игнорируемый каталог `.credentials/`, использовать `set -euo pipefail`.

- [ ] **Step 3: Написать роли и привязки**

Применять YAML через `kubectl apply -f -`; namespace-роли ограничить `propdevelopment`, доступ к Secrets выдать только группе `security`, не разрешать изменение Role/RoleBinding.

- [ ] **Step 4: Проверить shell и RBAC dry-run**

Run: `bash -n Task4/*.sh && kubectl apply --dry-run=client -f <(sed -n '/^apiVersion:/,$p' Task4/02-create-roles.sh)`
Expected: shell exit 0; для встроенного heredoc при необходимости использовать временный выводной режим скрипта вместо process substitution.

- [ ] **Step 5: Commit**

Run: `git add Task4 && git commit -m "feat: add Kubernetes RBAC setup"`

### Task 6: NetworkPolicy

**Files:**
- Create: `Task5/non-admin-api-allow.yaml`

- [ ] **Step 1: Написать ресурсы и default deny**

Создать namespace `traffic-zone`, четыре Pod/Service на Nginx с метками `role`, default-deny ingress/egress и DNS egress.

- [ ] **Step 2: Добавить парные политики**

Разрешить TCP/80 в обоих направлениях только для `front-end` ↔ `back-end-api` и `admin-front-end` ↔ `admin-back-end-api`; не использовать широкие пустые podSelector в allow-правилах.

- [ ] **Step 3: Проверить YAML**

Run: `kubectl apply --dry-run=client -f Task5/non-admin-api-allow.yaml`
Expected: все ресурсы parsed/configured (dry run), exit code 0.

- [ ] **Step 4: При доступном CNI проверить матрицу соединений**

Expected: две разрешённые пары доступны, cross-pair обращения завершаются timeout/refused.

- [ ] **Step 5: Commit**

Run: `git add Task5 && git commit -m "feat: isolate application traffic with network policies"`

### Task 7: Анализ Kubernetes audit log

**Files:**
- Create: `Task6/filter-audit.sh`
- Create: `Task6/audit-extract.json`
- Create: `Task6/analysis.md`

- [ ] **Step 1: Создать тестовый JSON Lines fixture во временном каталоге**

Включить ожидаемые audit-события get secrets, create privileged pod, create pods/exec и create RoleBinding на cluster-admin. Не включать вымышленное API-событие удаления AuditPolicy.

- [ ] **Step 2: Написать фильтр**

Скрипт принимает `INPUT=${1:-audit.log}` и `OUTPUT=${2:-audit-extract.json}`, использует `jq -s` и безопасные optional-пути для фильтрации пяти классов индикаторов.

- [ ] **Step 3: Запустить фильтр на fixture**

Run: `Task6/filter-audit.sh /tmp/audit-fixture.log Task6/audit-extract.json && jq -e 'length >= 4' Task6/audit-extract.json`
Expected: JSON-массив минимум из четырёх событий.

- [ ] **Step 4: Написать analysis.md**

Для каждого события описать ожидаемого инициатора, namespace, риск и RBAC-ошибку. Отдельно обозначить synthetic provenance и неподтверждённую попытку удаления локального файла audit-policy.

- [ ] **Step 5: Commit**

Run: `git add Task6 && git commit -m "feat: add Kubernetes audit incident analysis"`

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

Каждый контейнер задаёт `runAsNonRoot: true`, non-zero UID, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`; Pod задаёт `seccompProfile.type: RuntimeDefault`.

- [ ] **Step 3: Написать Gatekeeper templates/constraints**

Rego просматривает все containers/initContainers/ephemeralContainers; hostPath проверяется по `spec.volumes`; constraints ограничены Pod и namespace `audit-zone`.

- [ ] **Step 4: Написать audit policy и проверки**

`verify-admission.sh` проверяет ожидаемые reject/accept через server dry-run; `validate-security.sh` выполняет статические `kubectl`/`jq` проверки и состояние constraints. `README_FOR_REVIEWER.md` описывает установку Gatekeeper и порядок команд.

- [ ] **Step 5: Проверить синтаксис**

Run: `bash -n Task7/verify/*.sh && kubectl apply --dry-run=client -f Task7/01-create-namespace.yaml -f Task7/insecure-manifests -f Task7/secure-manifests && kubectl apply --dry-run=client -f Task7/audit-policy.yaml`
Expected: core manifests and audit Policy parse; Gatekeeper objects validate after CRD installation or structurally via YAML parser.

- [ ] **Step 6: Commit**

Run: `git add Task7 && git commit -m "feat: enforce container security policies"`

### Task 9: Итоговая проверка

**Files:**
- Modify: `README.md`
- Test: all `Task1`–`Task7` artifacts

- [ ] **Step 1: Проверить полный список файлов**

Run: `find Task{1..7} -type f | sort`
Expected: присутствуют все артефакты из карты файлов и условия задания.

- [ ] **Step 2: Запустить единый набор статических проверок**

Run: `bash -n Task4/*.sh Task6/*.sh Task7/verify/*.sh; jq -e 'type=="array"' Task6/audit-extract.json; python3 -c 'import xml.etree.ElementTree as E; [E.parse(p) for p in ("Task1/data-security-mindmap.drawio","Task3/context.drawio","Task3/containers.drawio")]'`
Expected: exit code 0.

- [ ] **Step 3: Проверить рабочее дерево и историю**

Run: `git status --short && git log --oneline --decorate -12`
Expected: только намеренные изменения; отдельные осмысленные коммиты.

- [ ] **Step 4: Запросить code review**

Использовать `superpowers:requesting-code-review`; исправить обязательные замечания и повторить итоговую проверку.

- [ ] **Step 5: Финальный commit при необходимости**

Run: `git add README.md && git commit -m "docs: finalize reviewer instructions"`
