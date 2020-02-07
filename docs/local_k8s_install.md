# Kubernetes по-русски

## Как поднять локальный kubernetes?
### Запилил свой Vagrantfile + public vagrantbox и single/multi-master k8s!
- https://github.com/Slach/vagrant-kubernetes
- https://app.vagrantup.com/Slach/boxes/kubernetes-containerd
- https://app.vagrantup.com/Slach/boxes/kubernetes-docker
- https://app.vagrantup.com/Slach/boxes/kubernetes-crio
- Внутри ubuntu 18.04 + cri-o / containerd / + kubeadm + kube-router все ставим из apt, за основу взяты:
    - https://github.com/andygabby/bionic64-k8s 
    - cri-o - https://launchpad.net/~projectatomic/+archive/ubuntu/ppa 
	- не выходят вовремя новые версии, мантейнер пакета косячит и ленится

- Как опубликовать свой vagrant box на vagrant cloud:
    - https://www.vagrantup.com/docs/cli/cloud.html#cloud-publish

#### TODO
    - https://coreos.com/etcd/docs/latest/tuning.html - тюнинг ETCD hight latency 

- Авторизация сервисов по TLS сертификатам? 
    - ca.pem и т.п. генерируется через kubeadm init
    - распостранение сертификатов пока через Vagrant shared synced folder /vagrant/ 

- docker-compose для локальной разработки проще:
    - ДА, но паралельно поддерживать docker-compose.yml и kubernetes/*.yml будет геморой
    - есть https://github.com/kubernetes/kompose, но это просто конвертер и лишнее звено
    - есть https://github.com/docker/compose-on-kubernetes, будет работать только на нативном docker (win10pro), не будет будет работать с cri-o и containerd


- https://github.com/kubernetes-sigs/kind
  - хорошая штука, но нужен docker на HOST OS для установки - ждем выхода WSL2, работает быстрее чем minikube
    если запускать под docker-toolbox "перекачивает docker pull на 1.3Gb" внутрь docker-machine 
    если потом сделать docker-machine rm придется качать образ заново, 
    также в docker-toolbox похоже сломана совместимость последнего docker с boot2docker, 
    ждем когда починят https://github.com/moby/moby/issues/36016 (если починят)
    и еще требует отдельного проброса порта в Virtualbox чтобы запустить с хоста kubectl.exe


- https://github.com/kubernetes/minikube
  - крутая вещь, подходит почти всем (можно пускать вообще без докера под linux), 
    но нельзя local multi-node k8s https://github.com/kubernetes/minikube/issues/94
    minikube под docker-toolbox не захотела поставить cri-o 
    и не умеет ставить kube-router

- https://github.com/kubernetes-sigs/kubeadm-dind-cluster
  - еще более крутая вещь, но у нее docker in docker ;( а я хочу cri-o
  - и еще на старых OS - windows 7 / osx < 10.9 все равно будет через boot2docker + virtualbox, 
  значит тоже медленный рестарт 

## Небольшой бенчмакр
  рестарт трех нод на vagrant - 1m44s
  рестарт minikube single node - 1m20s
  рестарт kind + docker-toolbox - 50s

  kind cluster create - 1.5 минуты
  vagrant up 9 минут (уже когда образ выкачан)
  пока останусь на vagrant, но думаю что надо еще kubeadm-dind-cluster попробовать ;)

