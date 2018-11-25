# k8s-russian.video
Kubernetes по русски, план скринкастов
 
# Общие вопросы
## Как тестировать все локально?
- https://github.com/kinvolk/kubernetes-the-hard-way-vagrant

## Какой DNS провайдер выбрать? 
Необходимые условия
 - Anycast DNS
 - API для быстрого менежмента зон

### Кого рассматриваем
 - AWS Route 53
 - Google Cloud DNS
 - https://zillore.com
 - https://constellix.com/solutions/latency-routing/
 - https://cloudflare.com/dns/
 
## Хостинг \ Cloud провайдеры
 - https://servers.com 
 - https://cloud.google.com

### Как аллоцировать новые k8s ноды
- Через terraform

### Как накатывать новые ноды
- http://kubespray.io/documents/

# Базы данных
- MySQL - https://github.com/oracle/mysql-operator
- PostgreSQL - https://github.com/sorintlab/stolon
- CockroachDB - https://www.cockroachlabs.com/campaigns/kubernetes/

# Фронтенд
- VUE.js - https://vuejs.org/
- VUE Native - https://vue-native.io/

# Мониторинг
- https://github.com/netdata/netdata
- https://github.com/netdata/netdata/tree/master/backends
- https://prometheus.io

# Аналитика
- https://github.com/apache/incubator-superset
- https://github.com/Vertamedia/clickhouse-grafana
- https://github.com/metabase/metabase/issues/3332
