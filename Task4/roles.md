# Ролевая модель Kubernetes для PropDevelopment

| Роль | Права роли | Группы пользователей |
|---|---|---|
| `cluster-viewer` | Чтение основных ресурсов кластера и workload-ресурсов без доступа к Secrets и объектам RBAC | Бизнес-аналитики и менеджеры operational team — группа `viewers` |
| `namespace-developer` | Создание и сопровождение приложений, Services, ConfigMaps, Jobs и PVC только в namespace `propdevelopment`; Secrets и RBAC недоступны | Разработчики PropDevelopment — группа `developers`, пользователь `developer1` |
| `platform-operator` | Чтение узлов, namespaces и постоянных томов во всём кластере; эксплуатация workload-ресурсов только в namespace `propdevelopment` | Инженеры эксплуатации — группа `platform-operators`, пользователь `operator1` |
| `security-secret-reader` | `get` и ограниченный `list` только для Secrets `application-tls` и `integration-credentials` в namespace `propdevelopment` | Команда информационной безопасности — группа `security` |
| `limited-security-admin` | Чтение событий, ConfigMaps, ServiceAccounts и журналов Pods, управление NetworkPolicy в `propdevelopment`; чтение namespaces и patch только namespace `propdevelopment` для управляемой настройки меток Pod Security Admission | Команда информационной безопасности — группа `security` |

Роли следуют принципу минимальных привилегий. Для `list` Secrets API-запрос обязан использовать field selector по разрешённому имени, иначе Kubernetes его отклонит из-за `resourceNames`. Узкая вспомогательная роль `limited-security-admin-psa` разрешает группе `security` менять только namespace `propdevelopment`. Для запросов этой группы fail-closed `ValidatingAdmissionPolicy` (Kubernetes 1.30+) допускает изменение только шести стандартных PSA-меток; системные контроллеры и администраторы под это ограничение не попадают. Остальные metadata, spec и status в таком запросе должны остаться прежними. Ни одна роль не выдаёт `bind`, `escalate`, `impersonate`, wildcard-права или доступ к `cluster-admin`.
