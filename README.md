# Выполнено ДЗ №1

1.1 Разберитесь почему все pod в namespace kube-system восстановились
после удаления. Укажите причину в описании PR

Результат анализа - после удаления подов напрямую из докера у меня pod-ы не восстановились и в случае
с minikube не должны были. Ручное удаление любых или всех pod-ов через kubectl приводит к их восстановлению.

Логика работы minikube следующая:
- 1. После старта containerd создаёт нужный набор namespace (в терминах Linux) (mnt, pid, cgroup, ipc, utc).
- 2. В этих пространствах имён ОС запускается "контейнер", который содержит unit systemd kubelet.service,
настроенный на автоматический перезапуск в случае падения.
- 3. kubelet читает манифесты и запускает в соответствии с их настройками контроллеры control plane (etcd, apiserver, control-manager, scheduler)
- 4. Два оставшиеся сервиса control plane запускаются уже scheduler-ом (coredns - в схеме ReplicaSet, а kube-proxy в схеме DaemonSet)

Надёжность этой схемы крайне ограничена, т.к. остановка сервиса kubelet гарантирует невозможность восстановления любого из сервисов.
Все шаги анализа зафиксированы в виде скриншотов.
Желающие могут поспорить с ними.

1.2 Создать образ Docker на основе Nginx
В каталоге kubernetes-intro/web созданы Dockerfile, nginx.conf, index.html, homework.html
Образ docker собран pol4/simple_web:0.2
После запуска доступна страница по адресу 127.0.0.1:8000

1.3 Разработать манифест web-pod.yaml для создания pod web c меткой app со значением web, содержащего один контейнер с названием web.
Для запуска образа из данного манифеста потребовалось вручную регистрировать локальный образ docker (minikube image load pol4/simple_web:0.2)
После включения в k9s port forwarding под стал доступен по 8000 порту на 127.0.0.1

1.4 Добавить init-контейнер, генерирующий index.html, доступный для контейнера web.
После запуска и настройки формвардинга приложение отозвалось на 8000-м порту с новой страницей.

1.5 Hipster shop
Репозиторий скопирован, docker-образ собран, манифест с ошибками выгружен.
Настроены забытые переменные. Часть приведённых в полном yaml-е front не использует (PORT).
С исправленным yaml-ом pod запустился.

# Выполнено ДЗ №2

2.1 Подготовка
Установка кластера Kubernetes v1.28 kubeadm в конфигурации 1 master(control plane) 3 minion на 4-х виртуальных машинах kvm.
Запуск и настройка локального docker registry:
 - docker run -d -p 5000:5000 --restart always --name registry registry:2
 - разрешение небезопасного доступа к реестру, запущенного в виде контейнера в docker. Файл /etc/docker/daemon.json
   ({ "insecure-registries": ["master:5000"] })
 - настройка возможности отращения к реестру без аутентификации и шифрование трафика. Файл /etc/containerd/config.tom
   ([plugins."io.containerd.grpc.v1.cri".registry]
  config_path = ""
  [plugins."io.containerd.grpc.v1.cri".registry.auths]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."master:5000".tls]
      insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".registry.configs."172.16.4.93:5000".auth]
      auth = ""
  [plugins."io.containerd.grpc.v1.cri".registry.headers]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."master:5000"]
      endpoint = ["http://master:5000"])
 - сборка и загрузка образа в локальный registry
  (docker build . -t pol4/hipstershop:0.1
   docker tag pol4/hipstershop:0.1 master:5000/hipstershop:0.1
   docker push master:5000/hipstershop:0.1)

2.2 Запуск Hipstershop контроллером ReplicaSet
Контроллер ReplicaSet не справился с ситуацией, когда манифест при первом запуске содержал указание на несуществующую
версию образа. После исправлеия манифеста в системе остались неработоспособные поды и запустились новые под требуемое
количество реплик. 
Судя по косвенным указаниям в документации, ReplicaSet контролирует только метки(labels), а не настройки образа.
Данная ситуация потребовала удаления всего ReplicaSet-а, т.к. при удалении неисправных подов они снова стартовали
в неисправной конфигурации. Только пересоздание репликасета позволило исправить ситуацию.

2.3 Воспроизвести ReplicaSet с paymentService. 
Выполнено по предыдущему сценарию

2.4 Запустить paymentService контроллером Deployment
Запуск осуществлялся при работающих подах paymentService с контроллером ReplicaSet.
После старта поды не перезапускались. Только появился Deployment.
После удаления контроллера Deployment поды ранее отдельно запущенные с контроллером ReplicaSet были удалены.
Это представляется некорректным с точки зрения логики работы.
Более того если с контроллером RS запускалось 5 подов, а в Depl 3, то 2 ноды были удалены...
Кажется, что в реальности это один контроллер с разными сценариями использования.

2.5 Обновить версию paymentService на контроллере Deployment
При обновлении появляется второй RS с новым ID. Deployment не меняется.

2.7 Выполнение Rollback
При выполнении операции отката оригинальное количество реплик не восстанавливается, только версии образа.

2.8 Сценарии BG и Reverse
Тривиально

2.9 Probes
Выполнено

2.10 DaemonSet
Хороший пример нашёлся
spec:
      tolerations:
        # these tolerations are to have the daemonset runnable on control plane nodes
        # remove them if your control plane nodes should not run pods
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule


