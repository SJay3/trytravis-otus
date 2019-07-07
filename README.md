# SJay3_infra
SJay3 Infra repository

## Homework 7 (terraform-2)
В данном домашнем задании было сделано:
- Импорт существующего правила firewall
- Структуризация ресурсов
- Созданием модулей

### Импорт существующего правила firewall
По заданию, мы должны создать правило для фаервола, разрешающее подключение по ssh. Но в GCP оно уже создано по умолчанию. Однако, что бы мы могли управлять этим правилось через terraform, его нужно описать в main.tf, после чего выполнить импорт, что бы терраформ знал, что такое правило уже существует в GCP

```shell
terraform import google_compute_firewall.firewall_ssh default-allow-ssh
```

### Структуризация ресурсов
Вынесем БД на отдельный инстанс ВМ. Для этого, для начала создадим 2 разных образа с помощью packer: db.json и app.json.

Далее разобьем файл main.tf на несколько конфигов, аналогично, как мы сделали с конфигурацией для packer. Создадим файлы app.tf с описанием приложения и db.tf с описанием базы. Так же, создадим файл vpc.tf, куда вынесем правило фаервола, которое применимо для всех инстансов (default-allow-ssh)

Перед тем, как создавать образы, необходимо проверить, что в GCP создано правило default-allow-ssh. Если его нет (возможно мы применили terraform destroy), то необходимо его создать, либо вручную, либо с помощью терраформа:

```shell
terraform apply -target=google_compute_firewall.firewall_ssh
```

После того, как разобьем файлы на несколько конфигов, сделаем сначала 2 новых образа:

```shell
packer build -var-file=variables.json app.json
packer build -var-file=variables.json db.json
```

А потом развернем терраформом инфраструктуру:

```shell
terraform plan
terraform apply
```

### Создание модулей
Перед тем, как создавать модули, уничтожим текущую инфраструктуру:

```shell
terraform destroy
```

В дирректории terraform создадим папку modules. Создадим модуль для базы данных и для приложения.

#### Модуль для базы
Создадим папку db внутри папки modules. Внутри создадим 3 файла: main.tf, variables.tf и outputs.tf. В файл main.tf скопируем содержимое ранее созданного файла db.tf. В файле variables.tf опишем используемые переменные для модуля с базой: `public_key_path`, `zone` и `db_disk_image`

#### Модель для приложения
По аналогии с базой, создадим папку app внутри директории modules с 3-мя файлами main.tf, variables.tf и outputs.tf. В файл main.tf скопируем содержимое из файла app.tf. В файле variables.tf опишем используемые переменные для приложения: `public_key_path`, `zone`, `app_disk_image` и `instance_count`

#### Использование модулей
Перед тем, как использовать модули, необходимо удалить из папки terraform ранее созданные файлы db.tf и app.tf, а в файле main.tf прописать использование модулей:

```
module "app" {
  source = "modules/app"
  public_key_path = "${var.public_key_path}"
  zone = "${var.zone}"
  app_disk_image = "${var.app_disk_image}"
  instance_count = "${var.instance_count}"
}

module "db" {
  source = "modules/db"
  public_key_path = "${var.public_key_path}"
  zone = "${var.zone}"
  db_disk_image = "${var.db_disk_image}"
}
```



----
## Homework 6 (terraform-1)
В данном домашнем задании было сделано:
- Установка terraform
- Организация структуры проекта в terraform
- Запуск проекта и основные команды
- Работа с ssh-ключами и пользователями в terraform (*)
- Созданние нескольких ресурсов и балансирование нагрузки (**)

### Установка terraform
Для установки terraform необходимо скачать дистрибутив с оффициального сайта [terraform](https://www.terraform.io/downloads.html). Т.к. домашнии задания адаптированы для версии 0.11.11, а последняя версия > 12, то для скачивания старой версии терраформа, необходимо найти её по следующей [ссылке](https://releases.hashicorp.com/terraform/0.11.11/). Скачанный архив необходимо распаковать в папку `~/terraform/`.
Далее, необходимо добавить путь к утилите packer в PATH. В `~/.bashrc` необходимо добавить строку в конец файла:

```shell
export PATH=$PATH:~/terraform/
```

Применим изменения, что бы не перелогиниваться с новой сессией:

```shell
source ~/.bashrc
```

### Структура проекта в terraform
При запуске терраформа, он будет считывать все файлы `.tf` из текущей директории. Структура проекта состоит из следующих файлов:
- main.tf
- variables.tf
- outputs.tf
- variables.tfvars

#### main.tf
Основной файл проекта. В нем указывается версия terraform, на которой будет работать проект, провайдер ресурсов, сами ресурсы. Внутри ресурсах могут быть указаны провижионеры. 

[Ссылка на документацию](https://www.terraform.io/docs/cli-index.html): Провизионеры, ресурсы, провайдеры и т.д.

#### variables.tf
В данном файле инициализируются переменные. У них указывается тип, описание, и значение по умолчанию (не обязательно).
Пример:

```
variable "region" {
  type        = "string"
  description = "region"
  default     = "europe-west1"
}
```

#### outputs.tf
В этом файле указываются выходные переменных, которые терраформ получает во время выполнения стейта. Эти переменные можно потом использовать для различных систем конфигурации.

#### variables.tfvars
Если в папке с проектом есть файл variables.tfvars то он тоже считывается автоматически терраформом. В противном случае, необходимо запускать терраформ с ключем `-var-file`, куда передавать путь к файлу с переменными.

В этом файле содержатся значения переменных, которые были определены в файле variables.tf.
Переменные указываются в формате ключ=значение.

### Запукс проекта и основные команды
Для запуска dry-run, необходимо выполнить команду

```shell
terraform plan
```
Терраформ покажет планируемые изменения, которые произойдут в инфраструктуре.

Для применения конфигурации, необходимо выполнить команду:

```shell
terraform apply
```
Терраформ покажет изменения и запросит подтверждение выполнения стейта. Для того, что бы терраформ не запрашивал подтверждение, а начинал выполнять стейт сам, необходимо запускать терраформ со специальным ключем:

```shell
terraform apply -auto-approve=true
```

При работе терраформ создает специальные файлы с расширением `.tfstate`. В них он хранит состояние применения конфигурации. Важно, что терраформ смотрит состояние только по этим файлам и не подключается к провайдеру, поэтому при использовании терраформа не следует править конфигурацию руками. Только через код терраформа.

Для просмотра и поиска по tfstate файлам, можно использовать команду:

```shell
terraform show
```

Если выходные переменные были добавлены после применения стейта, то занести в них информацию можно с помощью команды:

```shell
terraform refresh
```

Посмотреть значения выходных переменных можно командой:

```shell
terraform output
```

Для того, что бы терраформ заного пересоздал ресурс необходимо использовать команду:

```shell
terraform taint <тип_ресурса.имя_ресурса>
```
Это может потребоваться, к прирмеру, когда мы изменили провижионеры в ресурсе или добавили новых провижионеров, т.к. они запускаются только при создании ресурса или при удалении.

Для удаления ресурса используется следующая команда:

```shell
terraform destroy
```

### Работа с ssh-ключами и пользователями в terraform (*)

Для добавления ssh-ключа в метадату проекта, необходимо использовать отдельный ресурс `google_compute_project_metadata_item`. Этот ресурс добавляет 1 единицу метаданных в проект. Но для того, что бы можно было добавиь ssh ключ, необходимо указать **ssh-keys** в качестве значения у параметра **key**.

```
resource "google_compute_project_metadata_item" "appuser1" {
  key = "ssh-keys"
  value = "appuser1:${file(var.public_key_path)}"
  project = "${var.project}"
}
```

Для добавления сразу нескольких метаданных или нескольких ssh ключей, необходимо использовать другой ресурс: `google_compute_project_metadata`. Пример добавления нескольких ключей:

```
resource "google_compute_project_metadata" "many_keys" {
  project = "${var.project}"
  metadata = {
    ssh-keys = "appuser2:${file(var.public_key_path)} \nappuser3:${file(var.public_key_path)}"
  }
}
```

Нельзя использовать сразу 2 этих ресурса, т.к. терраформ будет затирать данные, добавленные одним из ресурсов. Так же, добавленные через веб-интерфейс ключи тоже будут удалены, если терраформ управляет метадатой.

### Созданние нескольких ресурсов и балансирование нагрузки (**)
#### Балансировщик
Создадим файл lb.tf в котором опишем настройки встроенного балансировщика нагрузки в GCP
Для того, чтобы создать балансировщик нагрузки в GCP необходимо:
- Создать группу инстансов и добавить необходимые инстансы в неё
- Создать хелс-чек, для проверки работоспособности инстансов
- Создать бекенд сервис, ссылающийся на группу
- Создать urlmap, у которого указать дефолтный инстанс
- Создать target proxy, ссылающийся на urlmap
- Создать forwarding rule, ссылающийся на target proxy

##### Группа инстансов
Создается через ресурс **google_compute_instance_group**. Необходимо указать имя, зону, а так же ссылку на каждый инстанс, который будет находиться в группе.
Так же, директивой `named_port`, необходимо указать порт и имя порта (по имени другие ресурсы будут обращаться к порту)
##### Health check
Health cheacks нужны для того, что бы проверять, работает ли сервис или нет.
Существует несколько видов хелс чеков (разные ресурсы): для http и для https. В хелс чеке указывается request_path и порт, по которому будут отправляться запросы к сервису.
##### Backend service
Это часть балансировщика, которая связывает его и группу инстансов. Здесь указывается имя порта (которое мы определили в группе инстансов), протокол, ссылка на группу инстансов и health check. Хелс чек возможно указать только один. Если необходимо использовать несколько хелс чеков или несколько разных портов, то надо создавать несколько бекенд сервисов.
##### Urlmap
Urlmap - это ядро балансирощика. Имя, определенное в этом ресурсе будет видно в веб-интерфейсе. Urlmap - это карта перенаправления url (аналог location в nginx).
Необходимо обязательно указывать дефолтовый backend (`default_service`).
##### Target proxy
Проксирует входищие соединения с форвардера на urlmap. существует несколько прокси. В том числе http и https (это отдельные ресурсы)
##### Forwarding rule
Описывает правила форвардинга. Это лицо балансировщика, тут указывается порт для входящих соединений и ссылка на прокси.

#### Внешний адрес балансировщика
Для определения внешнего адреса балансировщика, добавим в файл outputs.tf следующую переменную:

```
output "lb_external_ip" {
  value = "${google_compute_global_forwarding_rule.reddit-forward.ip_address}"
}
```

#### Добавление второго инстанса в балансировщик
Скопируем ресурс `google_compute_instance.app` и поменяем название ресурса на app2, а так же имя (name) на eddit-app2.
Добавим в outputs.tf новую переменную, определяющую ip адрес второго инстанса. Не забудем в файле lb.tf добавить новый инстанс в группу.

Такой подход добавления нового инстанса в группу не слишком удобен:
- Слишком много кода надо копировать
- Необходимо изменить имя ресурса и имя самого инстанса
- Необходимо добавить новый инстанс в группу инстансов.
- Необходимо добавить новую переменную для нового инстанса

#### Использование count для множественного создания инстансов
Завведем переменную instance_count с дефолтным значением 1. В main.tf добавим директиву count в ресурс `google_compute_instance.app`. В качестве имени инстанса укажем `reddit-app-${count.index + 1}`
Для того, что бы ссылаться на наши инстансы необходимо использовать немного другой синтаксис. К примеру, для указания инстансов в группе, следует использовать `${google_compute_instance.app.*.self_link}`, где вместо `*` можно указать номер инстанса. Номера начинаются с 0. Можно так же применять различные фильтры, для более точного указания инстансов.

----
## Homework 5 (packer-base)
В данном домашнем задании было сделано:
- Установка packer
- Предоставление доступа к GCP через ADC
- Создание образа ВМ через packer (fry подход)
- Создание полного образа ВМ (bake подход) (*)
- Создание скрипта создания ВМ из собранного образа (*)

### Установка packer
Для установки packer, необходимо скачать дистрибутив по [ссылке](https://www.packer.io/downloads.html), распаковать архив в папку `~/packer/`.
Далее, необходимо добавить путь к утилите packer в PATH. В `~/.bashrc` необходимо добавить строку в конец файла:

```shell
export PATH=$PATH:~/packer/
```

Применим изменения, что бы не перелогиниваться с новой сессией:

```shell
source ~/.bashrc
```

### Предоставление доступа к GCP через ADC
Для того, что бы packer мог подключаться к google cloud необходимо ему разрешить доступ. Это можно сделать через Application Default Credentials (ADC). Это позволяет приложениям работать с АПИ гугла используя credentals пользователя авторизованного через gcloud.

Выполним команду:

```shell
gcloud auth application-default login
```

### Создание образа ВМ через packer
Для работы через packer создадим файл шаблона ubuntu16.json, в котором будет описана конфигурация создаваемого нами образа.
Основные секции этого файла:
- variables - указываются переменные, которые имеют значения по умолчанию и не обязательны.
- builders - секция сборки образа. Для GCP тут указываются параметры временной виртуальной машины, на основе которой будет создан наш образ, а так же имя и семейство нашего образа
- provisioners - секция в которой указываются, что необходимо выполнить после запуска виртуальной машины, к примеру, установить необходимый софт.

Так же, создадим отдельный файл variables.json, в котором переопределим дефалтовые переменные, а так же обязательные переменные, которые нельзя определять в ubuntu16.json.
Поскольку данный файл нельзя пушить в репозиторий, т.к. он может содержать секреты, то создадим файл varibles.json.example, в котором опишем пример используемых параметров.

Для проверки корретности файла шаблона можно использовать:

```shell
packer validate ubuntu16.json
```
Что бы пакер зарезолвил все переменные, необходимо использовать синтаксис:

```shell
packer validate -var-file=variables.json ubuntu16.json
```

Если валидация прошла успешно, то запустить сборку можно командой:

```shell
packer build -var-file=variables.json ubuntu16.json
```

### Создание полного образа ВМ (bake подход) (*)
Для практики подхода immutable infrastructure, необходимо использовать подход к созданию образа именуемый bake.
Для этого был создан файл immutable.json, из которого packer собрал полный образ с уже установленным и добавленным в автозапуск приложением.
В качестве базового образа был выбран образ reddit-base, созданный на прошлом шаге. После скачивания git-репозитория и установки приложения, выполняется копирование подготовленного systemd unit во временную директорию, после чего юнит перемещается в целевую директорию и активируется автозапуск при загрузке.

Юнит запускает приложение из-под пользователя, поэтому, если используется другой пользователь, то его + пути к скачанному репозиторию необходимо поменять, перед пересборкой образа.

### Создание скрипта создания ВМ из собранного образа (*)

Для более быстрого создания и запуска ВМ из образа reddit-full был написан скрипт create-reddit-vm.sh, помещенный в директорию config-scripts.
Сам скрипт:

```shell
#!/bin/bash
#create reddit vm
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family reddit-full \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure
  
```

----
## Homework 4 (cloud-app)
В данном домашнем задании было сделано:
- Установка gcloud
- Установка тестового приложения с настройкой инфраструктуры
- Создание bash-скриптов для установки приложения и настройки инфраструктуры
- Создание startup script
- Создание правила фаервола с помощью gcloud


### Ревизиты для проверки

    testapp_IP = 35.228.222.184
    testapp_port = 9292

### Установка gcloud
[Инструкция по установке](https://cloud.google.com/sdk/docs/#deb)

### Создание ВМ через gcloud

```shell
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure
```

### Деплой приложения
Выполняем на машине reddit-app
#### Установка ruby

```shell
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
```

Проверка ruby и bundler

```shell
ruby -v
bundler -v
```

#### Установка mongoDB

```shell
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
sudo bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
sudo apt update
sudo apt install -y mongodb-org
```

Запускаем монгу и добавляем в автозагрузку

```shell
sudo systemctl start mongod
sudo systemctl enable mongod
```

#### Установка приложения

В домашней директории пользователя на машине reddit-app выполним:

```shell
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
```

Запускаем проект и проверяем, что он работает:

```shell
puma -d
ps aux | grep puma
```

### Создание startup script (*)
Необходимо закоммитить скрипт startup_script.sh в репозиторий, после чего воспользоваться параметром `--metadata startup-script-url` для скачивания и выполнения скрипта.
Этот скрипт всегда будет выполняться от пользователя **root**

Можно использовать параметр `--metadata startup-script`, но тогда придется указывать весь скрипт в командной строке. Это подходит только для небольших скриптов.

```shell
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure \
  --metadata startup-script-url='https://raw.githubusercontent.com/otus-devops-2019-05/SJay3_infra/cloud-testapp/startup_script.sh'
```

### Создание правила фаервола с помощью gcloud (*)

```shell
gcloud compute firewall-rules create default-puma-server --allow tcp:9292 --direction INGRESS --source-ranges="0.0.0.0/0" --target-tags puma-server
```


----
## Homework 3 (cloud-bastion)
В данном домашнем задании было сделано:
- Создание учетной записи в GCP
- Создание ssh ключей для инстансов ВМ
- Создание инстансов ВМ из веб-интерфейса
- Подключение по ssh через бастион-хост
- Подклчюение по vpn через бастион-хост
- Настройка ssl сертификатов для vpn-сервера

### Реквизиты ВМ

    bastion_IP = 35.228.209.11
    someinternalhost_IP = 10.166.0.5

### Регистрация учетной записи в GCP
Регистрация производится по ссылке: https://cloud.google.com/free/
Лучше всего использовать отдельный аккаунт Gmail.
Так же, в GCP был создан проект **infra**

### Создание ssh ключей и добавление их в GCP
#### для Windows
Можно сгенерировать ключи с помощью puttygen

#### для Linux
Генерируем ключ для пользователя *dusachev*

```shell
ssh-keygen -t rsa -f ~/.ssh/dusachev -C dusachev -P ""
```
#### добавление ключей в GCP
Заходим в Compute Engine -> Metadata -> SSH Keys.
Добавляем туда публичные ключи

### Подключение по ssh
#### Подключение с нестандартным ключем:
`ssh -i <path_to_key> <username>@<host>`
#### Настройка форвардинга ssh
Настраиваем формаврдинг с локальной машины.
Сначала запустим ssh-агент `eval "$(ssh-agent)"`
Теперь добаваил ключ в агент: `ssh-add ~/.ssh/dusachev`
#### Подключение через бастион-хост одной командой
Принцип следующий: Мы подключаемся через proxycommand к бастиону (35.228.209.11), после чего, тот проксирует нас на целевой сервер someinternalhost (10.166.0.5). Ключ `-W %h:%p` означает, что стандартный ввод и вывод будут форвардится на хост `%h` и порт `%p`. Эти переменные будут зарезолвены указаным хостом для подключения и портом.

```shell
ssh dusachev@10.166.0.5 -o "proxycommand ssh -W %h:%p -i ~/.ssh/dusachev dusachev@35.228.209.11"
```

#### Подключение через бастион-хост с использованием алиаса (*)
Для создания алиаса необходимо создать файл `~/.ssh/config` в котором прописать

``` shell
Host someinternalhost
  Hostname 10.166.0.5
  ForwardAgent yes
  User dusachev
  ProxyCommand ssh -W %h:%p -i ~/.ssh/dusachev dusachev@35.228.209.11

```

Или в случае, если версия openssh > 7.4, то можно использовать директиву ProxyJump. В таком случае конфиг будет выглядеть так:

```shell
Host someinternalhost
  Hostname 10.166.0.5
  ForwardAgent yes
  User dusachev
  ProxyJump dusachev@35.228.209.11
```

Теперь, что бы подключиться через бастион-хост нужно выполнить:

``` shell
ssh someinternalhost
```

### Подключение через VPN
#### Установка и первоначальная настройка VPN-сервера
Разрешим http/https трафик на машине bastion и установим vpn-server [Pritunl](https://pritunl.com/)

```shell
cat <<EOF> setupvpn.sh
#!/bin/bash
echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.4.list
echo "deb http://repo.pritunl.com/stable/apt xenial main" > /etc/apt/sources.list.d/pritunl.list
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 0C49F3730359A14518585931BC711F9BA15703C6
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
apt-get --assume-yes update
apt-get --assume-yes upgrade
apt-get --assume-yes install pritunl mongodb-org
systemctl start pritunl mongod
systemctl enable pritunl mongod
EOF
```

Выполним созданный скрипт. В результате мы получим установленный сервер pritunl и базу mongodb

```shell
sudo bash setupvpn.sh
```

Для настройки vpn необходимо через браузер зайти на https://<bastion_address>/setup и выполнить инструкции на экране. Далее, необходимо:
 - залогиниться, добавить организацию, тестового пользователя, сервер. 
 - Добавить сервер в организацию. 
 - Создать правило файрвола в GCP для порта на котором запустился сервер.
 - Добавить тег правила в инстанс ВМ

Теперь необходимо установить openvpn-client на машину, с которой будет производиться подключение.
#### Установка и настройка openvpn клиента на рабочую машину
##### Для Ubuntu 18
Установим openvpn

```shell
    sudo apt update
    sudo apt install openvpn
```

Скачиваем с сервера файл `*.ovpn`. Для этого необходимо нажать на иконку с цепочкой у пользователя, профиль которого мы хотим скачать, копируем ссылку из первого окошка и выполняем:

```shell
wget https://35.228.209.11/key/AwBbkqSZvBaMUZ8hC5YtcR7i85MAyAG5.tar --no-check-certificate
tar -xvf AwBbkqSZvBaMUZ8hC5YtcR7i85MAyAG5.tar
```
В результате в текущей директории мы получим ovpn-файл.
Запускаем соединение с vpn-сервером:

```shell
sudo openvpn --config <path_to_ovpn_file>
```
Предложит ввести логин и пароль. Используем логин test и PIN в качестве пароля.
Если на экране появится строка `Initialization Sequence Completed` значит соединение успешно установлено.

#### Проверка работоспособности впн-сервера
Для проверки подключимся с рабочей машины к vpn-серверу и попробуем зайти по ssh на someinternalhost (Заходить нужно с другой консоли):

```shell
ssh -i ~/.ssh/dusachev dusachev@10.166.0.5
```

### Настройка сертификата для панели управления Pritunl (*)
Используемые сервисы:
- sslip.io
- Lets Encrypt

Для использования сервиса [sslip.io](https://sslip.io) достаточно обратиться к сервису с запросом по специальному dns-имени и он вернет в ответ ip-адрес. Работает это так: У нас есть внешний сервис на ip 35.228.209.11. Мы в браузере набираем 35-228-209-11.sslip.io и попадаем на веб-интерфейс нашего сервиса.

Для использования Lets Encrypt необходимо зайти в веб-интерфейс pritunl используя домен от sslip.io. Далее перейти в настройки и в поле Lets Encrypt Domain ввести адрес домена sslip.io.
После сохранения настроек страница обновится и подцепится валидный ssl-сертификат от Lets Encrypt

p.s. Возможно потребуется дополнительная установка certbot, который генерит сертификаты. Делается это следующим образом:

```shell
    sudo apt-get update
    sudo apt-get install software-properties-common
    sudo add-apt-repository universe
    sudo add-apt-repository ppa:certbot/certbot
    sudo apt-get update

    sudo apt-get install certbot 
```


----
## Homework 2 (play-travis)
В данном домашнем задании было сделано:
- Добавлен функционал использования Pull Request Template
- Интеграция Slack с github
- Интеграция Репозитория и Slack с travis

### Использование Pull Request Template
Pull Request Template - это технология github для шаблонизироания Pull Request'а (PR).
Для его использования, необходимо в корне проекта создать папку `.github`, в которую поместить шаблон с именем `PULL_REQUEST_TEMPLATE.md`

### Интеграция Slack с github
Для интеграции slack с github Для начала необходимо добавить приложение github в slack. [Инструкция](https://get.slack.help/hc/en-us/articles/232289568-GitHub-for-Slack)
Далее, создать канал в в slack (мой канал: #dmitriy_usachev), после чего выполнить команаду:

    /github subscribe Otus-DevOps-2019-05/SJay3_infra commits:all

### Интеграция репозитория и slack с travis
Для использования travis, необходимо в корень репозитория добавить файл `.travis.yml`, в котором описать инструкции по запуску сборки travis.
Для интеграции со slack необходимо добавить в slack приложение Travis CI, выбрать канал для уведомлений и сгенерировать токен.
Для обеспечения безопасности, данный токен необходимо зашифровать. Это можно сделать с помощью утилиты travis.
Инструкция по интеграции со slack (для Ubuntu 18.04):
1. Необходимо авторизоваться через github на сайте [travis](https://travis-ci.com)
2. Удаляем стандартый ruby из ubuntu, т.к. он немного кривой.

```shell
sudo apt-get remove ruby
```

3. Установим дополнительные пакеты

```shell
sudo apt install autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm5 libgdbm-dev
```

4. Установим rbenv

```shell
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

5. Проверим, что все установилось корректно

```shell
source ~/.bashrc
type rbenv
```
На экран выведется:

```shell
Output
rbenv is a function
rbenv ()
{
    local command;
    command="${1:-}";
    if [ "$#" -gt 0 ]; then
        shift;
    fi;
    case "$command" in
        rehash | shell)
            eval "$(rbenv "sh-$command" "$@")"
        ;;
        *)
            command rbenv "$command" "$@"
        ;;
    esac
}
```

6. Усстановим ruby-build plugin. Он необходим для использования команды `rbenv install`

```shell
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
```

7. Выведем список того, что мы можем установить

```
rbenv install -l
```

8. Выберем необходимую версию руби (я выбрал 2.6.3), установим её, сделаем используемой по умолчанию и проверим, что версия установилась корректно

```shell
rbenv install 2.6.3
rbenv global 2.6.3
ruby -v
```

9. Устанавливать утилиту travis необходимо через gem (это утилита управления библиотеками и пакетами ruby). Для начала установим bundler, который необходим для управления зависимостями пакетов

```shell
gem install bundler
```

10. Теперь установим travis

```shell
gem install travis
```

11. Авторизуемся чезер утилиту travis

```shell
travis login --com
```

12. Теперь зашифруем токен с помощью утилиты travis. Мы должны находиться в папке с нашим репозиторием и в нем должен присутствовать файл `.travis.yml`

```shell
cd ~/otus/SJay3_infra
travis encrypt "devops-team-otus:<ваш_токен>#dmitriy_usachev" \
--add notifications.slack.rooms --com
```

13. travis автоматически добавит в файл `.travis.yml` шифрованый токен для уведомлений в slack. Остается только закоммитить изменения в файле.

### Самостоятельная работа (Добиться устпешного билда)
В файле `play-travis/test.py` была допущена ошибка в 6 строке.

```python
self.assertEqual(1 + 1, 1)
```
Эта функция всегда будет возвращать false по скольку, проверяем равнество 2-х чисел. В данном случае 2 не равно 1.
Необходимо исправить эту строку приведя её к виду:

```python
self.assertEqual(1, 1)
```
