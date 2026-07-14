# Ролевая модель Kubernetes для PropDevelopment

| Роль | Права | Группы |
|---|---|---|
| `cluster-viewer` | Чтение основных ресурсов кластера и workload-ресурсов без доступа к Secrets и объектам RBAC | `propdevelopment-viewers` |
| `namespace-developer` | Создание и сопровождение приложений, Services, ConfigMaps, Jobs и PVC только в namespace `propdevelopment`; Secrets и RBAC недоступны | `propdevelopment-developers` |
| `platform-operator` | Эксплуатация узлов, namespaces и workload-ресурсов во всём кластере; без Secrets, RBAC и выдачи привилегий | `propdevelopment-platform-operators` |
| `security-secret-reader` | Только чтение заранее определённых Secrets `application-tls` и `integration-credentials` в namespace `propdevelopment` | `propdevelopment-security-auditors` |
| `limited-security-admin` | Управление NetworkPolicy, ResourceQuota и LimitRange только в namespace `propdevelopment`; без Secrets и RBAC | `propdevelopment-security-admins` |

Роли следуют принципу минимальных привилегий. Ни одна из них не выдаёт `bind`, `escalate`, `impersonate`, wildcard-права или доступ к `cluster-admin`. Создание и изменение объектов RBAC остаётся отдельной административной процедурой.
