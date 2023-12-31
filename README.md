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

# Выполнено ДЗ №6

6.1 Подготовка
Данное ДЗ выполнялось на кластере из задания №2

6.2 Установка репозитория stable
Ссылка уже устарела и nginx-ingress даже из актуальной её версии уже depricated.

Для nginx зарегистрировал актуальный репозиторий
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

Неплохо было-бы сделать update после установки новой репы.
helm repo update

6.3 Установка nginx
Актуальный ingress-nginx хочет ставиться в ingress-nginx.
С существующим контроллером, даже при установке в другой неймспейс, конфлифктует.
Воспользовался стандартной установкой.
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace --wait

Done

6.4 Установка Cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager --wait --namespace=cert-manager --set installCRDs=true

Helm самостоятельно создаёт неймспейс и ставит требуемые CRD

#Ожидаемо не находит своих CDR и ждёт.
#Ставим CRD 
#kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml

#Обнаружил ресурсы и вышел из wait.

Done

6.5
Настройка УЦ для Cert-manager.
Делаем собственный CA.
Проверяем, что он может подписывать.
kubectl get clusterissuers
Message: edu-ca-issuer               True    Signing CA verified

Проверяем, что корневой сертификат сгенерировался нормально.
kubectl describe certificate -n cert-manager

Normal  Generated  15m   cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "k8s-edu-ca-6nwdd"
Normal  Requested  15m   cert-manager-certificates-request-manager  Created new CertificateRequest resource "k8s-edu-ca-1"
Normal  Issuing    15m   cert-manager-certificates-issuing          The certificate has been successfully issued

Done

В качестве альтерантивы подготовим Letsencrypt Issuer с регистрацией на внешнюю почту

Т.к. на следующих этапах потребуется сервис, торчащий в Интернет, то развернул Metallb, настроил PAT на статическом внешнем адресе.


6.6 Установка ChartMuseum
Репа в методичке устарела.
Подключаем актуальную.
helm repo add chartmuseum https://chartmuseum.github.io/charts

Корректируем values.yaml чтобы обеспечить генерацию сертификата по протоколу ACME.
Устанавливаем chartmuseum
helm upgrade --install chartmuseum chartmuseum/chartmuseum --wait --namespace=chartmuseum -f ./values.yaml

О чудо! Процесс запрос-ответ для валидации владения сайтом работает по HTTP!!!
Пришлось добавлять в PAT 80-й порт. 8 часов возни... Очень ценное знание...

Страничка открывается по пути https://chartmuseum.46.138.241.117.nip.io/ с правильным сертификатом.

6.7 Настройка Харбора
Снова открываю 80 порт.

Добавил репу
helm repo add harbor https://helm.goharbor.io
helm repo update

Создал новое неймспейс и добавил туда Issuer
Корректируем values.yaml
helm upgrade --install harbor harbor/harbor --wait --namespace=harbor -f ./values.yaml

Для запуска redis и co на кластере требуется наличие PV из подходящего storageclass
Установил rancher (kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml)
и пропатчил конфиг чтобы сторедж local-path стал по-умолчанию (kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}')

Ссылка открылась, сертификат с полной цепочкой.
https://harbor.46.138.241.117.nip.io

6.8 Helmfile
Собрал

6.9 Создать свой helm chart

helm create kubernetes-templating/hipster-shop

Done

При запуске не удаётся скачать образ gcr.io/google-samples/microservices-demo/adservice:v0.1.3
Остальное работает, сервисы доступны из браузера.

6.10 Разделить фронтэнд и остальную часть приложения.
helm create kubernetes-templating/frontend

Done

Отредактировал файлы. Удалил старый неймспейс. Установил новую конфигурацию без фронта.

Done

Создал нового Issuer в неймспейсе hipster-shop

Установил фронт. Сертификат получен. Приложение отзывается на https://shop.46.138.241.117.nip.io/

Done

Шаблонизировал yaml-ы фронта, включил в зависимости основного приложения.
При обновлении фрон поднялся.

Done

6.11 Установка параметра напрямую.
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace=hipster-shop --set frontend.service.NodePort=31234

Не работает. Ошибка в имени параметра. Правильно - nodePort

Done

6.12 Публикация кастомных чартов

Кажется, что к хелму не установлен плагин для пуша чарта. В методичке опять пропущены важные шаги.
Пойдём другим путём.

Далаем пакеты из фронта и основного прилождения

helm package .
получаем tgz

Логинимся в харбор
helm registry login harbor.46.138.241.117.nip.io

Пушим чарты
helm push hipster-shop-0.1.0.tgz oci://harbor.46.138.241.117.nip.io/library
Pushed: harbor.46.138.241.117.nip.io/library/hipster-shop:0.1.0
Digest: sha256:0f4209c7a8ab85fb6b64455d4b32e7af234659359b4f4b5693a03862bb82c033

helm push frontend-0.1.0.tgz oci://harbor.46.138.241.117.nip.io/library
Pushed: harbor.46.138.241.117.nip.io/library/frontend:0.1.0
Digest: sha256:f3a003149f93e26c6f9f47c5bd34fbe67dc30791a1dd465d8a386625a3ffea2e

PULL-инг образа обратно 
helm pull oci://harbor.46.138.241.117.nip.io/library/frontend --version 0.1.0
helm pull oci://harbor.46.138.241.117.nip.io/library/hipster-shop --version 0.1.0

Установка чарта
helm upgrade --install hipster-shop oci://harbor.46.138.241.117.nip.io/library/hipster-shop --version 0.1.0 -n hipster-shop

Done

6.13 Всякая шняга для кастомизации.
Лениво писать. Накопипастил. Вроде завелось.


# Выполнено ДЗ №7
7.1 Подготовка
Данное ДЗ выполнялось на кластере получившемся в результате выполнения задания №6

7.2 Useless CR
Done

7.3 Создание CRD
Интересно, материал из методички вообще хоть кто-то проверял хоть раз?
По ссылке https://gist.githubusercontent.com/Evgenikk/581fa5bba6d924a3438be1e3d31aa468/raw/417c044e203f378b90ff94eb0103df3f143427b2/bacis_crd.yml
Лежит кривой файл, который не устанавливается хотябы потому, что указано apiVersion: apiextensions.k8s.io/v1beta1, а не apiVersion: apiextensions.k8s.io/v1
Что приводит к ошибке - error: resource mapping not found for name: "mysqls.otus.homework" namespace: "" from "./bacis_crd_old.yml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"

Исправление первой ошибки приводит ко второй - The CustomResourceDefinition "mysqls.otus.homework" is invalid: spec.versions[0].schema.openAPIV3Schema: Required value: schemas are required

Опять масса потраченного зра времени...

7.4 Добавить проверку полей
Done

7.5 Подготовка контроллера
Копирование темплейтов, копипаст кода, запуск - облом.

Надо доставить через pip кроме самого kopf ещё модули kubernetes и jinja2

Что-то запустилось. Висит. По логам не создаются PVC
Гуглим. Ошибка в темплейтах, создающих PVC.
с local-path несовместимо такое использование секции selector:
    matchLabels:
      pv-usage: "backup-{{ name }}"
Удаляем.

Делаем докер-образ.


7.6 Деплой оператора
Правим название контейнера.
Деплоим. Все PV и PVC есть сервисы задеплоились

7.7 Заполняем данными и проверям
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
mysql: [Warning] Using a password on the command line interface can be insecure.
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------+

7.8 Удалить mysql-instance
Удалилась и перезапустилась.
База без изменений

# Выполнено ДЗ №8
8.1 Подготовка
Данное ДЗ выполнялось на кластере, получившемся в результате выполнения задания №6

8.2 Подготовка объекта мониторинга.

Делаем образ докер, деплоймент на три контейнера и сервис для них.
Сервис сделал типа LB, т.к. задолбался форвардировать порт.

Важно - nginx отдаёт Exporter-у метрики в дефолте на порту 8080 и по uri- /basic_status.
Если контейнер с nginx повесить на другой порт, то начнутся страннейшие сайд-эффекты и exporter не сможет забрать метрики.
Если тут всё ок, то уже сам exporter светит их в удобном прометею формате на порту 9113.

Особенно мила невозможность полноценной отладки, т.е. с ноды, где работает контейнер с nginx нет доступа к сервису контенера через lh.
Что, конечно, ожидаемо и понятно, но очень неудобно.

При создании сервиса важно публиковать не только сам порт nginx, но и порт Exporter. Сделано откровенно криво, т.к. это нужно только для его обнаружения прометеем через настройки Service Monitor... Доступ идёт по внутренним IP контейнеров сервиса, а не через кластерный IP.
Фактически, это заставляет его открыть чтобы потом закрыть на МСЭ... Использовать другой способ дискаверинга ещё кривее...

Также, при настройке именно deployment nginx обязательно нужно настроить аннотации для обнаружения подов с nginx и запуска скрейпер-job-ов для сбора с endpoints (с порта Exporter-а)

template:
metadata:
labels:
app: nginx-web-app
annotations:
prometheus.io/scrape: "true"
prometheus.io/path: "metrics"
prometheus.io/port: "9113"

Тоже вязкая история, которая стоит много времени на въезжание в мысли "гения", создавшего эту логику.

Done

8.3 Сборка и запуск объекта мониторинга

Собрал и опубликовал образ Docker с Nginx.
Сделали деплой этого образа с 3-мя репликами
Запустил сервис.
Проверил наличие правильных меток и аннотаций. (labels: app и annotations:)

Всё про объект мониторинга живёт, как и положено, в отдельном неймспейсе - demo

done

8.4 Ставим прометея через helm вместе с графаной.

Ставим в отдельный неймспейс - monitoring
Мы таки "белые люди" и даже Инженеры или бесполезное ДЗ по мониторингу локального миникуба делаем? )))

done

8.5 Заставляем прометея увидеть объект мониторинга как Target и собрать с него метрики

    Создаём и прикручиваем к default-ому сервисному аккаунту неймспейса, где живёт прометей (monitoring), кластерную роль "prometheus" с капабилити найти и "уничтожить" )))

    Создаём ServiceMonitor в неймспейсе monitoring, для обнаружения которого прометеем нужно прописать магические аннотации и лейблы, которые стоит подсмотреть в заведомо рабочих сервисмониторах конктетной инталляции прометея.
    В моём случае это:
    annotations:
    meta.helm.sh/release-name: prometheus
    labels:
    release: prometheus
    Такая магия конечно не гуд. Время кушает, а толку ноль.

Чтобы найденный прометеем сервисмонитор мог точно навести процесс скраппер-job-а на наш сервис, сборщик метрик прометея, нужно прописать в SM:
spec:
namespaceSelector:
matchNames:
- demo # Где искать
selector:
matchLabels:
app: nginx-web-svc # что искать
endpoints:

    path: /metrics
    port: nginx-exp-port # что брать

Done

8.6 Проверяем что оно таки увидело всё, что "нажито непосильной работой процессора"

В Targets прометея видна serviceMonitor/monitoring/nginx-servicemonitor/0 (3/3 up)
Но это ползадачи.
Проверяем, что реальные метрики nginx - не exporter-а, а именно nginx - доступны.
Хорошо подходит метрика nginx_http_requests_total, т.к. для пустого nginx без нагрузки будет показывать число запросов от прометея на сбор метрик по нодам.
Т.е. паттерн нормальной работы - когда метрики на нодах в разные моменты то отличаются не более чем на 1, то равны.
Что и наблюдаем.

Done

# Выполнено ДЗ №9
9.1 Подготовка
Данное ДЗ выполнялось на кластере, получившемся в результате выполнения задания №8

9.2 Установка ELK.
Helm-пакет для Elastic и Kibana недоступны.
Качаем через VPN и ставим как локальный пакет Helm.

Репы для fluent-bit не указано в методичке.
Кажется это - helm repo add fluent https://fluent.github.io/helm-charts

Пытаюсь ставить Helm-ом из локального tgz Elastic.
ReplicaSet задеплоился, но скачать образы не смог.
После распаковки и исследования Helm-овских tgz стало понятно, что образы недоступны не только из нашей страны, но и удалены вообще.

Пробуем через bitnamicharts

helm install bitnami oci://registry-1.docker.io/bitnamicharts/elasticsearch -n observability 

Успешно

helm install bitnami-k oci://registry-1.docker.io/bitnamicharts/kibana -n observability

Успешно

helm install bitnami-f oci://registry-1.docker.io/bitnamicharts/fluent-bit -n observability

Успешно

9.3 Обеспечение корректности распределения контейнеров по нодам.
При установке из выбранного Helm Chart распределение равномерное и коррекции не требует.

9.4 ingress и доступ к сервису Kibana
Я управляю локальным кластером kubernets kubeadm, который поднят на отдельном физическом сервере и среде виртуализации KVM там.
Управление этим кластером осуществляю с физически отдельной рабочей стации.
Использование предлагаемой в задании схемы публикации мне неудобно.
Реализована публикация сервиса Kibana на LB Metallb

Доступ к UI Kibana через LB получен

Отдельно настраиваю LB на ingest-ноды Elastic (2 шутки). Было бы совсем странно сделать по методичке - три ингреса для "неуловимого Джо" в виде Kibana при одной входной
для трафика событий ноды...

9.4 Настройка fluentbit
Bitnami версия штатно управляется через configmap.
Выгружаем его в Yaml, настраиваем выход пайплайна

    [OUTPUT]
        Name  es # плагин выхода
        Match *
        Host el-ingest # должен ресолвиться в DNS кластера, если запрос из этого же неймспейса. (это LB)
        Port 9200
Получаем ошибку парсинга метрики в Elastic - "contains an unknown parameter [_type]"
Исправляем configmap
Suppress_Type_Name On

Проверяем наличие данных в индексе
Подключаемся к Kibana и проверяем наличие данных в индексе fluent-bit-<Y.m.d>
Данные есть. Тупые и никому не интересные метрики cpu этого хоста.

Настраиваем чтение логов kubernetes. Это несколько живее...

Настраиваем RBAC
Настраиваем [Input] по tail-у в ConfigMap.
Выгружаем Deployment fluent-bit и монтируем /var/log и т.п. с ноды... Так себе концепция мониторинга... Оооооочень плохо с позиции ИБ.
Но делаем... Кажется, что наиболее адекватный мониторинг кубера надо делать не изнутри кубера, а снаружи. Уж точно не потребуется
странными пробросами с хоста заниматься, ну и вообще инфраструктуру гораздо лучше видно без лишних полясок...

Проверяем наличие данных Hipstershop в Kibana (кажется он у нас объект мониторига? а то аффтор методички свалил всё в такую жуткую кучу, что "делание" утратило смысл)
Поищем trace_id из свежего лога почтового сервиса магазина.
Найдено успешно. Метка всремени корректная, сообщение не обрезано.

Done

9.5 Мониторинг EFK с помощью прометея.
helm install my-prometheus-elasticsearch-exporter prometheus-community/prometheus-elasticsearch-exporter --version 4.11.1 --set es.uri=http://elasticsearch-master:9200 --set serviceMonitor.enabled=true --namespace=observability

Данные видно.

Логи ingress-nginx находятся.

Done


9.6 Установка Loki
По ссылке в методичке устаревшая информация.

Использую актуальную репу и ставим
helm install my-release oci://registry-1.docker.io/bitnamicharts/grafana-loki
В качестве агентов сбора логов был установлен Promtail

Done

9.4 Подключение к Графана
Публикуем сервис grafana-loki-frontend на LB и порт 3100

Источник данных настроен и прошёл валидацию.

9.5 Логи и метрики с nginx 

Настраиваем запрос в эксплорере Графаны

Done

9.6 Дашборды с требуемыми визуализациями сформированы.

Done
