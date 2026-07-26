# Ролевая модель Kubernetes для PropDevelopment

Кластер разделён на четыре namespace — по одному на каждый бизнес-домен компании. Это разграничивает доступ разработчиков и инженеров эксплуатации ресурсами их домена, а не всего кластера, в соответствии с организационной структурой PropDevelopment.

| Namespace | Домен компании |
|---|---|
| `sales` | Группа сервисов для продаж (витрина, client-tour-app, client-mart-app, client-crm-app, client-mart-estate-app) |
| `tenant-services` | Группа сервисов ЖКУ (tenant-core-app, CRM собственников) |
| `finance` | Финансы (accountant-service-1, служба каталогов) |
| `data-platform` | Дата (хранилище, BI, отчётность) |

| Роль | Права роли | Группы пользователей |
|---|---|---|
| `cluster-viewer` | Чтение основных ресурсов кластера и workload-ресурсов во всех namespace, без доступа к Secrets и объектам RBAC | Бизнес-аналитики и менеджеры операционной команды — группа `viewers` (обзор по всей компании, без деления по доменам) |
| `namespace-developer` | Создание и сопровождение приложений, Services, ConfigMaps, Jobs и PVC только в namespace своего домена; Secrets и RBAC недоступны | Разработчики функциональных команд — по отдельной группе на домен: `developers-sales`, `developers-tenant`, `developers-finance`, `developers-data`. Пользователь `developer1` состоит в `developers-sales` |
| `platform-operator` | Создание, чтение и эксплуатация workload-ресурсов только в namespace своего домена | Инженеры эксплуатации и DevOps-инженеры функциональных команд — по отдельной группе на домен: `platform-operators-sales`, `platform-operators-tenant`, `platform-operators-finance`, `platform-operators-data`. Пользователь `operator1` состоит в `platform-operators-tenant` |
| `platform-operator-cluster-reader` | Чтение nodes, namespaces и PersistentVolumes во всём кластере (нужно для планирования мощностей независимо от домена) | Все доменные группы инженеров эксплуатации (`platform-operators-*`) — привязка перечисляет каждую группу отдельно |
| `security-secret-reader` | `get` и ограниченный `list` только для Secrets `application-tls` и `integration-credentials`, выданы в каждом из четырёх доменных namespace | Команда информационной безопасности (один специалист на всю компанию, см. описание кейса) — группа `security` |
| `limited-security-admin` | Чтение событий, ConfigMaps, ServiceAccounts и журналов Pods, управление NetworkPolicy в каждом из четырёх доменных namespace; чтение namespaces и patch только PSA-меток | Команда информационной безопасности — группа `security` |

Роли следуют принципу минимальных привилегий. Разработчики и инженеры эксплуатации одного домена не имеют прав в namespace других доменов — за это отвечают отдельные RoleBinding для каждой пары «домен + группа», а не общая ClusterRoleBinding. Для `list` Secrets API-запрос обязан использовать field selector по разрешённому имени, иначе Kubernetes его отклонит из-за `resourceNames`. Узкая вспомогательная роль `limited-security-admin-psa` разрешает группе `security` менять метки Pod Security Admission только у четырёх доменных namespace. Для запросов этой группы fail-closed `ValidatingAdmissionPolicy` (Kubernetes 1.30+) допускает изменение только шести стандартных PSA-меток; системные контроллеры и администраторы под это ограничение не попадают. Остальные metadata, spec и status в таком запросе должны остаться прежними. Ни одна роль не выдаёт `bind`, `escalate`, `impersonate`, wildcard-права или доступ к `cluster-admin`.
