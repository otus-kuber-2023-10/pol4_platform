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

# Выполнено ДЗ №3

3.1 Подготовка и запуск под-а web-pod.yaml

Среда запуска - кластер Kubernetes из предыдущего ДЗ
Для запуска в этой среде, а не на minikube потребовалось модифицировать образ Docker, т.к. при запуске со старым сценарием
nginx запускался не от root и не мог выполнить bind к порту 80 вне зависимости от своей конфигурации, однако после запуска
он отпускал порт 80 и более не слушал на нём.

3.2 ReadinessProbe
Сделано

3.3 Включение livenessProbe
Интересный факт - полностью работоспособную ноду, но не прошедшую проверку готовности нельзя апдейтить.
Для изменения её конфигурации приходится её удалять и создавать снова.

3.4 Проверка наличия процесса в память.
Не все приложения интерактивны. Такая проверка годится для сценариев, когда неисправность процесса может выразиться только
в исчезновении процесса, а не в различных вариантах повисания.

3.5 Деплой
Пробелы - это зло.

3.6 Деплой с роллапдейт
Сделано

3.7 Создание сервиса
Создан.
Кажется, что восторги автора по поводу нахождения "спрятанного" IP-адреса сервиса нескольно поверхностны, т.к. не отвечают
на вопрос о том, как пакеты на этот "IP" "оказываются" на других нодах кластера. Вполне понятно, что это зависит от используемого CNI,
но, на мой взгляд, случай сервиса работает в модели "плоской сети" (bridged) или L2 сети, т.е. сетевой интерфейс всех нод работает в 
promiscuous mode (ip -d link|grep promiscuity). Это гарантирует возможность приёма всех пакетов, вне зависмости от dest mac.
А получив пакет его уже можно обработать несложными правилами балансировки нагрузки на netfilter + iptables.
С позиции безопасности, надёжности и производительности модель плоской сети совсем не идеальна.

3.8 Установка, настройка и проверка Metallb
Установлено. На кластер ставить проще чем на minikube
ConfigMap из материалов устарела. Конфиг через kind: IPAddressPool заработал.
Раздавал не абстрактную подсеть чтобы бороться с portsecurity, которая блокирует наличие двух IP на одном mac,
а непосредственно IP одной из нод кластера.

3.9 ingress-nginx
Потребовалось обновить контроллер на кластере.


# Выполнено ДЗ №4

4.1 Подготовка
Данное ДЗ выполнялось на кластере из задания №2

4.2 Установка Minio
Для работы на кластере требуется наличие PV из подходящего storageclass
Установил rancher (kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml)
и пропатчил конфиг чтобы сторедж local-path стал по-умолчанию (kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}')

4.3 Установка StatefulSet minio
Потребовала изменения конфига чтобы секреты перестали быть обязательными

4.4 Установка хедлес сервиса для доступа
Создан

4.5
Требование секретов включено обратно. Секреты прогрожены в Объектное хранилище.
base64 от minio и minio123

# Выполнено ДЗ №5

5.1 Подготовка
Данное ДЗ выполнялось на кластере из задания №2

5.2 Создание сервисной учётки bob и биндинг роли cluster-admin
Выполнено.
При создании сервисной учётки не был заявлен неймспейс.
Меппинг произошёл при биндинге с ролью.
Это немного странно, если мы говорим о доступе везде...

5.3 Создание сервисной учётки dave и биндинг роли "без доступа"
Задача неоднозначная. Кажется, что "без доступа" - это когда учётка не может ничего сделать в системе.
Прямой такой роли не обнаружил, а ручками прописывать права откровенно лень.
Использую роль пользователя с минимальными полномочиями - basic-user
При просмотре в k9s у сервисной учётки пустые правила биндинга...
Кажется, что это не совсем корректно, ведь права-то есть, хоть и минимальные...
(Allows a user read-only access to basic information about themselves.
Prior to v1.14, this role was also bound to system:unauthenticated by default.)

5.4 Создать namespace Prometheus
Done

5.5 Создать сервисную учётку carol в этом неймспейсе.
Done

5.6 Дать всем Service Account в Namespace prometheus возможность делать
get , list , watch в отношении Pods всего кластера
Done

5.6 Создать Namespace dev
Done

5.7 Создать Service Account jane в Namespace dev
Done

5.8 Дать jane роль admin в рамках Namespace dev
Done

5.9 Создать Service Account ken в Namespace dev
Done

5.10 Дать ken роль view в рамках Namespace dev
Done

