# k8s-russian.video
Kubernetes по русски, ссылки и ответы на вопросы

# Общие вопросы 
## Лучший способ понять основы kubernetes
- https://github.com/kinvolk/kubernetes-the-hard-way-vagrant
  - Лучший путь для того чтобы разобраться в основных компонетах
  - Не подходит для локальной разработки
  - Слишком много памяти и виртуальных машин, single node k8s получается убогонький
  - Бинарники ставятся "ручками" а не через apt
 
# Построение develoment кластера
## [Как поставить kubernetes локально?](docs/local_k8s_install.md)
## [Как разрабатывать и тестировать все локально?](docs/local_development.md)

## Построение production\staging кластера

### Как накатывать новые ноды в production?
- kubeadm + install-k8s.sh ?
- http://kubespray.io/documents/
- Сделать свой ansible playbook из hard-way?
- как ставить k8s в условиях spot instances?

### Как вести менеджмент манифестов
- Чем плох Helm?
- https://kustomize.io/
- https://docs.shipper-k8s.io/en/latest/
- https://github.com/shyiko/kubetpl + https://m0rk.space/posts/2018/Aug/21/deploying-on-kubernetes-using-circleci-and-kubetpl/


### Авторизация по ssh на нодах через SSH Bastion?
- https://github.com/iamacarpet/ssh-bastion

### RBAC в k8s как оно работает?
- Обычных юзеров менеджерить надо отдельно
- https://habr.com/ru/company/flant/blog/422801/

### Менеджмент секретов
- https://itnext.io/can-kubernetes-keep-a-secret-it-all-depends-what-tool-youre-using-498e5dee9c25 - https://github.com/Soluto/kamus

### SSO + LDAP ?
- https://github.com/appliedtrust/goklp
- https://github.com/glauth/glauth
- https://github.com/negz/kuberos - WEB SSO, https://github.com/vimond/k8s-auth-client - CLI SSO
- https://wso2.com/identity-and-access-management/install/kubernetes/get-started/
- https://www.techrepublic.com/article/how-to-install-phpldapadmin-on-ubuntu-18-04/

- https://www.pomerium.io/docs/identity-providers.html#google
- https://www.8host.com/blog/nastrojka-freeipa-na-servere-ubuntu-16-04/
- https://github.com/krishnapmv/k8s-ldap
- https://hub.docker.com/r/freeipa/freeipa-server/
- http://newstudyclub.blogspot.com/2017/10/setting-up-multi-master-replication-of.html
- https://github.com/manuparra/FreeIPA#creating-a-replica
- https://hub.docker.com/r/ldapaccountmanager/lam - Web UI для LDAP
- https://help.github.com/articles/connecting-your-identity-provider-to-your-organization/ - только для Enterprise - жмотье 
- https://cloud.google.com/blog/products/identity-security/using-your-existing-identity-management-system-with-google-cloud-platform
- https://www.8host.com/blog/nastrojka-freeipa-na-servere-ubuntu-16-04/
- https://github.com/jirutka/ssh-ldap-pubkey
- https://eng.ucmerced.edu/soe/computing/services/ssh-based-service/ldap-ssh-access

- https://github.com/leo-yuriev/ReOpenLDAP
    - ставить multi-master reOpenLDAP на каждый сервер? нужно сделать .deb пакет для этого
        долго не вариант

## Какой DNS регистратор
- godaddy? namecheap? dnssimple?
- Почему не использовать DNS от регистратора?
    
## Какой DNS провайдер выбрать? 
### Необходимые условия:
 - https://www.dnsperf.com/ 
 - Anycast DNS, Latency based DNS
 - API для быстрого менежмента зон
     - https://github.com/kubernetes-incubator/external-dns
 
### Кого рассматриваем
 - AWS Route 53
 - Google Cloud DNS
 - https://zillore.com
 - https://constellix.com/solutions/latency-routing/
 - https://cloudflare.com/dns/
 
## Хостинг \ Cloud провайдеры
 - https://github.com/cablespaghetti/kubeadm-aws - SPOT инстансы
 - https://cloud.google.com
    - https://cloud.google.com/products/calculator/#id=c533fb7e-4b01-4e26-a1e6-761ec599a754 - 478 USD/month (30Gb RAM суммарно)
    - https://cloud.google.com/products/calculator/#id=4a4bca8c-27f6-4ab4-8720-efc6437b6b46 - 25,07 USD/day
 - https://www.linode.com/pricing - 150 USD - 15 nodes 2Gb RAM (30gb)
 - https://www.packet.com/cloud/servers/t1-small/ - ATOM 155 USD = 3 nodes 9 nodes (8Gb RAM) / 155 USD - spot цена
 - https://www.servers.com/cloud - 180 USD - 9 nodes x 2Gb RAM
 - https://www.digitalocean.com/pricing/ - 150 USD - 15 nodes 2Gb RAM
    - https://www.digitalocean.com/products/kubernetes/ - бесплатные master nodes ?
 - https://cart.alibabacloud.com/calculator - нет local SSD
     
 
### Как аллоцировать новые k8s ноды у хостинг провайдера
- Через terraform?

### Multi Cloud Kubernetes
- https://github.com/bookingcom/shipper/ - деплоймент и раскатка на мульти кластер - https://docs.shipper-k8s.io/en/latest/
- https://github.com/GoogleCloudPlatform/k8s-multicluster-ingress/ - глубокая бета, работает только в GKE
- https://github.com/rook/rook - Storage Orchestration
- https://github.com/google/metallb - L2 Load Balancer 
- https://crossplane.io
- https://github.com/banzaicloud/pipeline
- https://github.com/kubicorn/kubicorn
- https://containership.io/
 

# CI/CD - code quality
- https://sonarcloud.io/ + github + bitbucket
- https://sourced.tech/
- https://travis-ci.com/plans vs https://circleci.com/pricing/ vs https://drone.io/enterprise/
- https://golangci.com/
- https://github.com/python-security/pyt

# Базы данных (то что рассмотрю обязательно) + [отдельные описания интересных DB-aware продуктов](docs/databases.md)
- MySQL - https://github.com/oracle/mysql-operator, https://vitess.io (DBaaS - https://planetscale.com/)
- PostgreSQL - https://github.com/sorintlab/stolon
- CockroachDB - https://www.cockroachlabs.com/campaigns/kubernetes/

# Frontend
- VUE.js - https://vuejs.org/
- VUE Native - https://vue-native.io/
- Flutter - https://flutter.io

# Backend
## PHP 
- https://github.com/spiral/roadrunner 
- https://github.com/swoole/swoole-src
- https://github.com/adsr/phpspy

## Python
- https://github.com/squeaky-pl/japronto + asyncio 
- tatantool + https://github.com/igorcoding/asynctnt

# Мониторинг
- https://prometheus.io
- https://github.com/bloomberg/goldpinger - пингер внутри кластера
- https://github.com/Comcast/kuberhealthy
- https://github.com/cuishark/cuishark 
- https://github.com/netdata/netdata
- https://github.com/netdata/netdata/tree/master/backends


# Тестирование отказоустойчивости 
- https://github.com/asobti/kube-monkey
- https://github.com/arnaudmz/kaos
- https://github.com/shopify/toxiproxy

# Аналитика
- https://github.com/apache/incubator-superset
- https://github.com/Vertamedia/clickhouse-grafana
- https://github.com/metabase/metabase/issues/3332
- https://blog.ubuntu.com/2018/12/10/using-gpgpus-with-kubernetes
- https://github.com/jupyterhub/zero-to-jupyterhub-k8s 
- https://habr.com/ru/post/439272/ - Netflix + Jupyter
- https://github.com/kubeflow

# Что есть проще чем k8s? 
- https://rancher.com/docs/rancher/v2.x/en/
- https://github.com/lastbackend/lastbackend
- https://stellarproject.io/

# Security 
- https://github.com/aquasecurity/trivy
- https://github.com/anchore/anchore-engine - проверка через ImagePolicyWebhook
- https://github.com/coreos/clair - сканирование образов + встроено в harbor 
- https://snyk.io/plans - сканирование исходников, говорят много false positive
- https://sysdig.com/opensource/falco/ - alert если делается что то не то в контейнере
- https://github.com/sysdiglabs/falco-nats 
- https://kubesec.io/ - проверяем yaml файлы на "секурность"
- https://github.com/awslabs/git-secrets - сканирует на pre-commit hook
- https://github.com/zricethezav/gitleaks, https://github.com/auth0/repo-supervisor - проверяем репозиторий на "открытые пароли"

# Flamegraphs
- https://www.speedscope.app/ vs flamescope
