# Отчёт по результатам анализа Kubernetes Audit Log

> Реальный `audit.log` не предоставлен, поэтому `audit-extract.json` — синтетический демонстрационный набор событий (каждое помечено `propdevelopment.dev/fixture: synthetic`), построенный по шагам `simulate-incident.sh`. Он не подтверждает реальный инцидент, а показывает, какие записи ожидались бы в audit.log при выполнении сценария и как их находить.

## Подозрительные события

1. Доступ к секретам:
   - Кто: `system:serviceaccount:secure-ops:monitoring` — под этой identity выполнен запрос за счёт impersonation (`--as`). Реальный инициатор — `kubernetes-admin`, чей kubeconfig обладает правом `impersonate`.
   - Где: namespace `kube-system`, секрет `default-token-8f2xk` (системный токен ServiceAccount `default`).
   - Почему подозрительно: ServiceAccount `monitoring`, только что созданный в служебном namespace `secure-ops`, сразу используется для попытки чтения секрета в системном namespace `kube-system` — это выход за периметр своего namespace и обращение к чувствительным системным данным. На момент запроса RoleBinding ещё не выдан, поэтому ответ — `403 Forbidden`, но сама попытка — типичный шаг разведки перед эскалацией привилегий.

2. Привилегированные поды:
   - Кто: `kubernetes-admin` (прямой запрос, без impersonation).
   - Комментарий: под `privileged-pod` создан в namespace `secure-ops` с `securityContext.privileged: true` — это даёт контейнеру полный доступ к устройствам и ядру ноды, фактически эквивалент root на хосте. Событию предшествовало создание тестового пода `attacker-pod` от имени того же ServiceAccount, что укладывается в схему «разведка → закрепление».

3. Использование kubectl exec в чужом поде:
   - Кто: `kubernetes-admin`.
   - Что делал: выполнил `pods/exec` (`cat /etc/resolv.conf`) в поде `coredns-6f9c4b8d9c-7xqzr` в системном namespace `kube-system`, не являясь оператором DNS-компонента кластера. Это несогласованное вмешательство в критичный системный под и разведка сетевой конфигурации кластера через чужой namespace.

4. Создание RoleBinding с правами cluster-admin:
   - Кто: `kubernetes-admin`.
   - К чему привело: RoleBinding `escalate-binding` в namespace `secure-ops` привязал ServiceAccount `monitoring` к ClusterRole `cluster-admin`. Поскольку это именно RoleBinding (не ClusterRoleBinding), права ограничены рамками namespace `secure-ops`, но внутри него ServiceAccount `monitoring` получил полный административный доступ — вплоть до `get`/`list`/`create`/`delete` на secrets, roles и rolebindings. Это прямая неавторизованная эскалация привилегий: ServiceAccount, у которого несколько секунд назад не было прав даже на чтение одного секрета (событие 1), в результате этого шага получил полный контроль над своим namespace.

5. Удаление audit-policy.yaml:
   - Кто: запрос выполнен с impersonation `--as=admin`; реальный инициатор — `kubernetes-admin`, обладающий правом `impersonate`.
   - Возможные последствия: цель команды `kubectl delete -f /etc/kubernetes/audit-policy.yaml` — отключить журналирование аудита (anti-forensics, «заметание следов»), чтобы последующие действия не попадали в audit.log. Технически `Policy` (`audit.k8s.io`) не зарегистрирован как ресурс Kubernetes API — это локальный файл конфигурации `kube-apiserver` (подключается флагом `--audit-policy-file`), а не объект, которым можно управлять через `kubectl`. Поэтому такая попытка не порождает audit-событие удаления ресурса, и в `audit-extract.json` соответствующей записи нет и не может быть. Это важный вывод сам по себе: манипуляция конфигурацией аудита на control-plane узле — слепая зона для `audit.log`, и обнаруживать такие попытки нужно отдельно: мониторингом целостности файлов на control-plane, ограничением SSH/exec-доступа к нодам и алертингом на изменение `--audit-policy-file`.

## Вывод

Все пять событий укладываются в единый сценарий, выполненный одним актором (`kubernetes-admin`, обладающий правами уровня `system:masters`), который частично действовал напрямую, а частично — через impersonation чужих identity (`secure-ops:monitoring`, `admin`). Вредоносными следует считать все пять шагов при отсутствии согласования: тестирование прав только что созданного ServiceAccount на системном namespace, запуск привилегированного пода, exec в системный под CoreDNS, эскалацию ServiceAccount до полного администратора namespace и попытку отключить аудит.

Компрометацией кластера в этом сценарии можно считать сам факт того, что RoleBinding `escalate-binding` перевёл ServiceAccount `monitoring` из состояния «без прав» в состояние «полный администратор namespace `secure-ops`» за одно действие — то есть у злоумышленника (или у скомпрометированного пода, использующего этот ServiceAccount) появляется устойчивый канал для последующих действий даже без повторного использования исходных учётных данных `kubernetes-admin`. В сочетании с приватным подом и exec-доступом к `kube-system` это уже достаточно для практического контроля над частью кластера.

Основные ошибки политики RBAC: (1) право `impersonate` выдано учётной записи, которая используется для рутинных операций, без отдельного контроля таких запросов; (2) ничто не мешает создать RoleBinding, ссылающийся на ClusterRole `cluster-admin`, из обычного namespace — отсутствует ограничивающая политика (например, через admission-контроллер) на выдачу привилегированных ClusterRole; (3) нет Pod Security Admission/policy engine, запрещающего `privileged: true`; (4) `pods/exec` в `kube-system` не ограничен отдельными правами и не генерирует алерт; (5) конфигурация самого аудита (`audit-policy.yaml`) не защищена от изменения независимо от Kubernetes RBAC — её целостность нужно контролировать на уровне control-plane узла.

## Рекомендации

1. Ограничить право `impersonate` минимально необходимым набором identity и включить отдельный алертинг на любые запросы с `impersonatedUser`.
2. Запретить создание RoleBinding/ClusterRoleBinding, ссылающихся на ClusterRole `cluster-admin`, вне контролируемого процесса согласования (например, через OPA Gatekeeper/ValidatingAdmissionPolicy).
3. Включить Pod Security Admission в режиме `restricted` (или policy engine) для namespace, где не требуется `privileged: true`.
4. Ограничить `pods/exec` в `kube-system` отдельной ролью и включить оповещения на такие операции.
5. Обеспечить неизменяемость `audit-policy.yaml` на control-plane узлах (file integrity monitoring, ограничение SSH-доступа) — сам Kubernetes API не может это проконтролировать.

## Метод фильтрации

`filter-audit.sh` принимает JSONL и путь результата, построчно проверяет корректность JSON и затем формирует итоговый массив через `jq -s`. Он отбирает: `get` для secrets, создание Pod с privileged-контейнером (включая init- и ephemeral-контейнеры), `pods/exec`, привязки на ClusterRole `cluster-admin` (RoleBinding/ClusterRoleBinding) и текстовые упоминания `audit-policy` в полях объекта, URI или параметрах запроса. При некорректном JSON скрипт останавливается с номером ошибочной строки и не публикует частичный результат; готовый файл собирается во временном файле рядом с результатом и атомарно перемещается на его место.
