# k8s-russian.video
Kubernetes по русски, ссылки и ответы на вопросы
 
# Общие вопросы
## [Как тестировать все локально?](docs/local_development.md)

## Построение production кластера

### Как накатывать новые ноды в production?
- http://kubespray.io/documents/
- kubeadm
- Сделать свой ansible playbook из hard-way?

### Авторизация по ssh на нодах через SSH Bastion?
- https://gravitational.com/teleport/
- https://github.com/moul/sshportal

### RBAC в k8s как оно работает?

### SSO + LDAP ?
- ставить multi-master reOpenLDAP на каждый сервер? нужно сделать .deb пакет для этого
- https://github.com/krishnapmv/k8s-ldap
- https://github.com/jirutka/ssh-ldap-pubkey
- https://github.com/leo-yuriev/ReOpenLDAP
- https://eng.ucmerced.edu/soe/computing/services/ssh-based-service/ldap-ssh-access

## Какой DNS регистратор
- godaddy? namecheap? dnssimple?
- Почему не использовать DNS от регистратора?
    
## Какой DNS провайдер выбрать? 
### Необходимые условия:
 - https://www.dnsperf.com/ 
 - Anycast DNS, Latency based DNS
 - API для быстрого менежмента зон
 - https://github.com/github/octodns
 - https://github.com/StackExchange/dnscontrol
 - как интегрировать с kubernetes?
 
### Кого рассматриваем
 - AWS Route 53
 - Google Cloud DNS
 - https://zillore.com
 - https://constellix.com/solutions/latency-routing/
 - https://cloudflare.com/dns/
 
## Хостинг \ Cloud провайдеры
 - https://servers.com 
 - https://cloud.google.com
    - https://cloud.google.com/products/calculator/#id=c533fb7e-4b01-4e26-a1e6-761ec599a754 - 15,75 USD/day - 450 USD - 30gb
    - https://cloud.google.com/products/calculator/#id=4a4bca8c-27f6-4ab4-8720-efc6437b6b46 - 25,07 USD/day
 - https://www.linode.com/pricing - 150 USD - 15 nodes 2Gb RAM (30gb)
 - https://www.packet.com/cloud/servers/t1-small/ - ATOM 155 USD = 3 nodes 9 nodes (8Gb RAM) / 155 USD - spot цена
 - https://www.servers.com/cloud - 180 USD - 9 nodes x 2Gb RAM
 - https://cart.alibabacloud.com/calculator - нет local SSD
 - https://www.digitalocean.com/pricing/ - 150 USD - 15 nodes 2Gb RAM
    - https://www.digitalocean.com/products/kubernetes/ - бесплатные master nodes ?
     
 
### Как аллоцировать новые k8s ноды у хостинг провайдера
- Через terraform?

### Multi Cloud Kubernetes
- https://crossplane.io
- https://github.com/banzaicloud/pipeline
- https://github.com/kubicorn/kubicorn
- https://containership.io/
- https://github.com/GoogleCloudPlatform/k8s-multicluster-ingress/ - глубокая бета, работает только в GKE
 

# CI/CD - code quality
- https://sonarcloud.io/ + github + bitbucket
- https://travis-ci.com/plans vs https://circleci.com/pricing/
- https://golangci.com/
- https://github.com/python-security/pyt

# Базы данных
- MySQL - https://github.com/oracle/mysql-operator, https://vitess.io
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
- https://github.com/bloomberg/goldpinger - пингер внутри кластера
- https://github.com/cuishark/cuishark + https://github.com/drk1wi/Modlishka ? MITM? 

# Тестирование отказоустойчивости 
- https://github.com/asobti/kube-monkey
- https://github.com/arnaudmz/kaos

# Аналитика
- https://github.com/apache/incubator-superset
- https://github.com/Vertamedia/clickhouse-grafana
- https://github.com/metabase/metabase/issues/3332
- https://blog.ubuntu.com/2018/12/10/using-gpgpus-with-kubernetes
- https://github.com/jupyterhub/zero-to-jupyterhub-k8s

# Что есть проще чем k8s? 
- https://rancher.com/docs/rancher/v2.x/en/
- https://github.com/lastbackend/lastbackend
- https://github.com/ehazlett/stellar
- https://stellarproject.io/

# Security 
- vulners scanner для библиотек?
- https://snyk.io/plans

# Flamegraphs
- https://www.speedscope.app/ vs flamescope



