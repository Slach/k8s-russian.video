# Kubernetes по-русски                   
    
- Как правильно проверить security настройки kubernetes?
    - https://github.com/aquasecurity/kube-bench - 6 FAIL на текущий момент
      
- Непонятно как делать private image registry 
    - пока буду использовать как public hub.docker.com
    - локально можно развернуть https://goharbor.io/ или https://github.com/ContainerSolutions/trow/blob/master/INSTALL.md
    - Еще есть https://github.com/uber/kraken - p2p docker registry
    - как делать "только явно подписанные образы"?
        - пока толком никак, есть достаточно эпичные issues по этому поводу ;)
            - https://github.com/kubernetes/kubernetes/issues/30603
            - https://github.com/containerd/cri/issues/624
        - есть концепция https://docs.docker.com/engine/security/trust/content_trust/
        - из всех CRI концепция реализована пока только в docker ee (платная)
        - docker-ce может проверять не внутри engine, только при запуске клиента на pull, run коммандах
        но это не относится к CRI docker engine
        - img не умеет sign
        - crictl pull тоже не проверяет подписи
        - ctr image pull вроде тоже умеет 
## TODO
- https://github.com/google/ko
- https://github.com/cloudnativelabs/kube-router/issues/370#issuecomment-463967949 - надо правильно настраивать kube-router?

- Как делать docker build внутри k8s + cri-o и потом делать docker push ?
    - https://github.com/genuinetools/img - поставил, работает, вроде все ок
        - только не умеет "подпись образов" https://github.com/genuinetools/img/issues/215
    - https://github.com/GoogleContainerTools/kaniko#pushing-to-different-registries - не буду пока юзать
    
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
            - запускают процесс в локальном Pod, который смотрит в "development" k8s кластер и импортирует все ENV + сеть?
        - https://docs.garden.io/using-garden/hot-reload
        - https://github.com/solo-io/kubesquash
        - https://github.com/cloudnativedevelopment/cnd
        - https://github.com/aylei/kubectl-debug
        #### IDE 
        - go https://blog.jetbrains.com/go/2018/04/30/debugging-containerized-go-applications/
        - python https://www.jetbrains.com/help/pycharm/remote-debugging-with-product.html
        - php xdebug
        #### CLI DEBUG
        - python https://github.com/inducer/pudb
        - rust, go https://gdbgui.com/
        - gdb - https://github.com/snare/voltron
        #### WEB-IDE
        - https://www.theia-ide.org/
