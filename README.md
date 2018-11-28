# k8s-russian.video
Kubernetes по русски, план скринкастов
 
# Общие вопросы
## Как тестировать все локально?
- https://github.com/kinvolk/kubernetes-the-hard-way-vagrant
- Свой Vagrantbox ?
- Локальная registry?
- Volumes и правка файлов?

## Какой DNS регистра
- godaddy?
- Почему не использовать DNS от регистратора?

## Какой DNS провайдер выбрать? 
### Необходимые условия:
 - Anycast DNS
 - API для быстрого менежмента зон
 - https://github.com/github/octodns ? Добавить поддержку zillore?

### Кого рассматриваем
 - AWS Route 53
 - Google Cloud DNS
 - https://zillore.com
 - https://constellix.com/solutions/latency-routing/
 - https://cloudflare.com/dns/
 
## Хостинг \ Cloud провайдеры
 - https://servers.com 
 - https://cloud.google.com

### Как аллоцировать новые k8s ноды у хостинг провайдера
- Через terraform?

### Как накатывать новые ноды в production?
- http://kubespray.io/documents/
- Сделать свой ansible playbook из hard-way?

### Авторизация по ssh на нодах?

### RBAC авторизация в k8s?

### SSO + LDAP ?

# CI/CD - code quality
- https://sonarcloud.io/ + github + bitbucket
- https://travis-ci.com/plans vs https://circleci.com/pricing/

# Базы данных
- MySQL - https://github.com/oracle/mysql-operator
- PostgreSQL - https://github.com/sorintlab/stolon
- CockroachDB - https://www.cockroachlabs.com/campaigns/kubernetes/

# Frontend
- VUE.js - https://vuejs.org/
- VUE Native - https://vue-native.io/

# Backend
## PHP 
- https://github.com/spiral/roadrunner 
- https://github.com/swoole/swoole-src
- https://github.com/adsr/phpspy

## Python
- https://github.com/squeaky-pl/japronto + asyncio 
- tatantool + https://github.com/igorcoding/asynctnt

# Мониторинг
- https://github.com/netdata/netdata
- https://github.com/netdata/netdata/tree/master/backends
- https://prometheus.io

# Аналитика
- https://github.com/apache/incubator-superset
- https://github.com/Vertamedia/clickhouse-grafana
- https://github.com/metabase/metabase/issues/3332


# Что есть проще чем k8s? 
- https://rancher.com/docs/rancher/v2.x/en/
