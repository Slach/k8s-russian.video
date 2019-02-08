# Kubernetes по-русски
## Как поднять локальный kubernetes?
- docker-compose для локальной разработки проще:
    - ДА, но паралельно поддерживать docker-compose.yml и kubernetes/*.yml будет геморой
    - есть https://github.com/kubernetes/kompose, но это просто конвертер и лишнее звено
    - есть https://github.com/docker/compose-on-kubernetes, будет работать только на нативном docker (win10pro), не будет будет работать с cri-o

- https://github.com/kinvolk/kubernetes-the-hard-way-vagrant
    - Лучший путь для того чтобы разобраться в основных компонетах
    - Не подходит для локальной разработки
    - Слишком много памяти и виртуальных машин, single node k8s получается убогонький
    - Бинарники ставятся "ручками" а не через apt
             
- https://github.com/kubernetes-sigs/kind
    - еще одна хорошая штука, но нужен docker на HOST OS для установки, работает быстрее чем minikube 
    под docker-toolbox "перекачивает docker pull на 1.3Gb" если сделать docker-machine rm, также в docker-toolbox похоже сломана совместимость последнего docker с boot2docker, ждем когда починят https://github.com/moby/moby/issues/36016 (если починят)
    и еще требует отдельного проброса порта в Virtualbox чтобы запустить с хоста kubectl.exe
    
    
    рестарт minikube 1m20s
    рестарт трех нод на vagrant 1m44s
    рестарт docker-machine (kind+docker-toolbox) 50s

    kind cluster create 1.5 минуты
    vagrant up 9 минут
    пока останусь на vagrant, но думаю что надо еще kubeadm-dind-cluster попробовать ;)    

- https://github.com/kubernetes/minikube
    - крутая вещь, подходит всем, но нельзя local multi-node k8s https://github.com/kubernetes/minikube/issues/94
      minikube под docker-toolbox не захотела поставить cri-o и не умеет ставить kube-router

- https://github.com/kubernetes-sigs/kubeadm-dind-cluster
    - еще более крутая вещь, но у нее docker in docker ;( а я хочу cri-o 
    - и еще на старых OS - windows 7 / osx < 10.9 все равно будет через boot2docker + virtualbox - медленно 

                   
### Запилил свой Vagrantfile + public vagrantbox и single/multi-master k8s!
- https://github.com/Slach/vagrant-kubernetes, https://app.vagrantup.com/Slach/boxes/vagrant-kubernetes
- Внутри ubuntu 18.04 + cri-o + kubeadm + kube-router все ставим из apt, за основу взяты:
    - https://github.com/andygabby/bionic64-k8s 
    - cri-o - https://launchpad.net/~projectatomic/+archive/ubuntu/ppa
    - https://coreos.com/etcd/docs/latest/tuning.html - тюнинг ETCD hight latency 
- Как опубликовать свой vagrant box на vagrant cloud:
    - https://www.vagrantup.com/docs/cli/cloud.html#cloud-publish
- Авторизацией сервисов по SSL сертификатам? 
    - ca.pem и т.п. генерируется через kubeadm init
    - распостранение сертификатов увы через Vagrant shared synced folder /vagrant/ 
    
- Как правильно проверить security настройки kubernetes
    - https://github.com/aquasecurity/kube-bench - 6 FAIL на текущий момент
      
- Непонятно как делать private image registry 
    - пока буду использовать как public hub.docker.com
    - локально можно развернуть https://hub.docker.com/_/registry или https://goharbor.io/ 
    - как делать "только явно подписанные образы"?

- Как делать docker build внутри k8s + cri-o и потом делать docker push ?
    - https://github.com/genuinetools/img - поставил, работает, вроде все ок
    - https://github.com/GoogleContainerTools/kaniko#pushing-to-different-registries
    
- Непонятно как делать secrets для "локальной разработки"?
- придется поддерживать два Dockerfile на каждый application, один "для разработки", второй production + multi-stage?
    - как сделать localVolume и проброс файлов?
    - как сделать аналог docker-compose restart?
    - #### как делать livereload + debug
        - https://github.com/Azure/draft
            - скрывают от разработчика процесс deployment в кластер, 
            - удлиняет цикл разработки, кроме kubernetes/*.yml придется поддерживать свой packs/*.yml и helm
            - нельзя multinode k8s
        
        - https://github.com/windmilleng/tilt
            - меньше скрывают от разработчика процесс deployment в кластер, более понятный конфиг чем у draft
        - https://www.telepresence.io/tutorials/kubernetes
        - https://github.com/cortesi/modd для перезапуска сервисов "по изменению файловой системы"
        - https://github.com/solo-io/kubesquash
        - https://github.com/cloudnativedevelopment/cnd
        - https://github.com/aylei/kubectl-debug
        #### IDE 
        - go https://blog.jetbrains.com/go/2018/04/30/debugging-containerized-go-applications/
        - python https://www.jetbrains.com/help/pycharm/remote-debugging-with-product.html
        - php xdebug
        #### CLI
        - python https://github.com/inducer/pudb
        - rust, go https://gdbgui.com/
        - https://github.com/snare/voltron
        #### WEB-IDE
        - https://www.theia-ide.org/
