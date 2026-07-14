# Ролевая модель Kubernetes для PropDevelopment

| Роль | Права роли | Группы пользователей |
|---|---|---|
| `cluster-viewer` | Чтение основных ресурсов кластера и workload-ресурсов без доступа к Secrets и объектам RBAC | Наблюдатели и аудиторы платформы — группа `viewers` |
| `namespace-developer` | Создание и сопровождение приложений, Services, ConfigMaps, Jobs и PVC только в namespace `propdevelopment`; Secrets и RBAC недоступны | Разработчики PropDevelopment — группа `developers`, пользователь `developer1` |
| `platform-operator` | Чтение узлов, namespaces и постоянных томов; эксплуатация namespaced workload-ресурсов во всём кластере без изменения узлов, PV и namespaces | Инженеры эксплуатации — группа `platform-operators`, пользователь `operator1` |
| `security-secret-reader` | `get` и ограниченный `list` только для Secrets `application-tls` и `integration-credentials` в namespace `propdevelopment` | Аудиторы ИБ — группа `security-auditors` |
| `limited-security-admin` | Чтение событий, ConfigMaps, ServiceAccounts и журналов Pods; управление NetworkPolicy только в `propdevelopment` | Администраторы ИБ — группа `security-admins` |

Роли следуют принципу минимальных привилегий. Для `list` Secrets API-запрос обязан использовать field selector по разрешённому имени, иначе Kubernetes его отклонит из-за `resourceNames`. Ни одна роль не выдаёт `bind`, `escalate`, `impersonate`, wildcard-права или доступ к `cluster-admin`. Изменение RBAC и меток Pod Security namespace выполняется отдельным управляемым процессом с admission-контролем.
