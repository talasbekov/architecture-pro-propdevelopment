# Task 7 — проверка политик безопасности Kubernetes

## Предварительные условия

- доступ к тестовому кластеру Kubernetes и права на создание Namespace и Pod;
- `kubectl`, настроенный на этот кластер;
- Docker (для закреплённого `yq` 4.44.3);
- для проверки Gatekeeper — права администратора кластера и сетевой доступ к GitHub при установке.

Проверяйте только в тестовом кластере. Небезопасные Pod созданы исключительно как демонстрации нарушений и не предназначены для запуска.

## Pod Security Admission

```bash
chmod +x Task7/verify/verify-admission.sh Task7/verify/validate-security.sh
./Task7/verify/verify-admission.sh
```

Скрипт создаёт/обновляет `audit-zone` с уровнями `enforce`, `warn` и `audit` профиля `restricted:latest`. Три изолированных нарушения из `insecure-manifests/` должны быть отклонены серверной dry-run проверкой. До применения безопасных Pod скрипт проверяет совпадения имён и останавливается, не изменяя существующие Pod. Три Pod из `secure-manifests/` применяются, и скрипт ждёт их состояния `Ready`. При завершении удаляются только ресурсы, созданные текущим запуском: весь Namespace, если он был создан скриптом, либо только созданные Pod в ранее существовавшем Namespace.

Безопасные примеры используют закреплённый образ `nginxinc/nginx-unprivileged:1.27.4-alpine`, порт 8080, непривилегированные UID/GID, `RuntimeDefault`, запрет повышения привилегий, только читаемую корневую ФС, сброс всех capabilities и `emptyDir` для каталогов, в которые nginx пишет во время работы.

## Gatekeeper

Если Gatekeeper уже установлен:

```bash
./Task7/verify/validate-security.sh
```

Для явной установки закреплённой версии Gatekeeper:

```bash
INSTALL_GATEKEEPER=true GATEKEEPER_VERSION=v3.22.2 ./Task7/verify/validate-security.sh
```

Скрипт ждёт готовности контроллера, применяет три `ConstraintTemplate` с явно включённым синтаксисом Rego v1, ожидает появления соответствующих CRD и применяет constraints. Затем создаётся `gatekeeper-test` **без меток PSA**, чтобы результат показывал именно работу Gatekeeper. Каждое нарушение изолировано и считается отклонённым только при ненулевом коде `kubectl` и наличии в ответе ожидаемых имени constraint и маркера политики; таймаут, TLS-ошибка или общий сбой webhook тестом не считаются. Три безопасных Pod проходят server-side dry-run. Во избежание изменения чужих ресурсов скрипт остановится, если одноимённые templates, constraints или Namespace уже существуют. Созданные этим запуском тестовый Namespace, constraints и templates удаляются при любом выходе. Сама установка Gatekeeper автоматически не удаляется.

Ожидаемый итог обоих скриптов: 3 небезопасных манифеста отклонены, 3 безопасных приняты. Ненулевой код выхода означает, что ожидание не выполнено.

## Audit policy

`audit-policy.yaml` — конфигурация запуска `kube-apiserver`, а не Kubernetes API-объект. Её **никогда нельзя применять через `kubectl apply`**. Администратор control plane передаёт файл API-серверу через `--audit-policy-file` и отдельно настраивает путь или webhook для audit-лога. Точная автономная семантическая проверка закреплённым yq:

```bash
docker run --rm -i mikefarah/yq:4.44.3 e -e 'select(.apiVersion == "audit.k8s.io/v1" and .kind == "Policy" and (.rules | type == "!!seq"))' - < Task7/audit-policy.yaml >/dev/null
```

Эта же команда выполняется в начале `validate-security.sh`.
