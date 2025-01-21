
# mini-server's microcloud

## target
- micro cloud
- backup data
- rapid migration

## install
> all in docker or k8s

### phyical machine
- docker
- snap lxd
- microk8s
- nginx

### fs
docker-compose.yaml
```bash
services:
  # https://hub.docker.com/r/itsthenetwork/nfs-server-alpine
  nfs:
    image: itsthenetwork/nfs-server-alpine:12
    container_name: nfs
    restart: unless-stopped
    privileged: true
    environment:
      - SHARED_DIRECTORY=/data
    volumes:
      - ./nfs:/data
    ports:
      - 2049:2049
  webdav:
    container_name: webdav
    image: bytemark/webdav
    restart: always
    ports:
      - "31001:80"
    environment:
      AUTH_TYPE: Digest
      USERNAME: russionbear
      PASSWORD: 123456
    volumes:
      - ./dav:/var/lib/dav

```

### s3
docker-compose.yaml
```bash
services:
  minio:
    image: minio/minio
    container_name: minio
    ports:
      - "31010:9000"
      - "31011:9001"
    volumes:
      - ./data:/data
    environment:
      MINIO_ROOT_USER: admin 
      MINIO_ROOT_PASSWORD: password
    command: ["server", "/data", "--console-address", ":9001", "--address", ":9000"]


```

### db
docker-compose.yaml
```bash

services:
  mysql:
    image: mysql:8.3.0-oracle
    container_name: mysql-container
    restart: always
    ports:
      - "31020:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root@mysql
    volumes:
      - ./mysql:/var/lib/mysql

#   bind-container:
#     image: sameersbn/bind:latest
#     container_name: bind-container
#     restart: always
#     environment:
#       WEBMIN_INIT_SSL_ENABLED: false
#     ports:
#       - "53:53/tcp"
#       - "53:53/udp"
#       - "10000:10000/tcp"
#     volumes:
#       - /data/ws/bind-data:/data

  redis:
    image: redis
    container_name: redis-container
    restart: always
    ports:
      - "31023:6379"
    command: --requirepass redis@redis
    volumes:
      - ./redis:/data

  mongodb:
    image: mongo
    container_name: mongodb
    restart: always
    ports:
      - "31026:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: root@mongo
    volumes:
      - ./mongo:/data/db

  postgresql:
    image: postgres
    container_name: postgresql
    ports:
      - "31029:5432"
    environment:
      POSTGRES_PASSWORD: password
    volumes:
      - ./pql:/var/lib/postgresql/data

  rabbitmq:
    image: rabbitmq:3-management-alpine  # 使用包含管理界面的RabbitMQ镜像
    container_name: rabbitmq
    ports:
      - "31032:5672"  # RabbitMQ 默认AMQP端口
      - "31033:15672" # RabbitMQ管理界面端口
    environment:
      - RABBITMQ_DEFAULT_USER=russionbear
      - RABBITMQ_DEFAULT_PASS=redhat

  kafka:
    image: apache/kafka:3.8.0 
    container_name: kafka
    ports:
      - "31035:9092"


```


### harbor

docker-compose.yaml
```bash
services:
  log:
    image: goharbor/harbor-log:v2.10.3
    container_name: harbor-log
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    volumes:
      - /var/ws/harbor/log/:/var/log/docker/:z
      - type: bind
        source: ./common/config/log/logrotate.conf
        target: /etc/logrotate.d/logrotate.conf
      - type: bind
        source: ./common/config/log/rsyslog_docker.conf
        target: /etc/rsyslog.d/rsyslog_docker.conf
    ports:
      - 127.0.0.1:1514:10514
    networks:
      - harbor
  registry:
    image: goharbor/registry-photon:v2.10.3
    container_name: registry
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - ./data/registry:/storage:z
      - ./common/config/registry/:/etc/registry/:z
      - type: bind
        source: ./data/secret/registry/root.crt
        target: /etc/registry/root.crt
      - type: bind
        source: ./common/config/shared/trust-certificates
        target: /harbor_cust_cert
    networks:
      - harbor
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "registry"
  registryctl:
    image: goharbor/harbor-registryctl:v2.10.3
    container_name: registryctl
    env_file:
      - ./common/config/registryctl/env
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - ./data/registry:/storage:z
      - ./common/config/registry/:/etc/registry/:z
      - type: bind
        source: ./common/config/registryctl/config.yml
        target: /etc/registryctl/config.yml
      - type: bind
        source: ./common/config/shared/trust-certificates
        target: /harbor_cust_cert
    networks:
      - harbor
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "registryctl"
  postgresql:
    image: goharbor/harbor-db:v2.10.3
    container_name: harbor-db
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    volumes:
      - ./data/database:/var/lib/postgresql/data:z
    networks:
      harbor:
    env_file:
      - ./common/config/db/env
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "postgresql"
    shm_size: '1gb'
  core:
    image: goharbor/harbor-core:v2.10.3
    container_name: harbor-core
    env_file:
      - ./common/config/core/env
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - SETGID
      - SETUID
    volumes:
      - ./data/ca_download/:/etc/core/ca/:z
      - ./data/:/data/:z
      - ./common/config/core/certificates/:/etc/core/certificates/:z
      - type: bind
        source: ./common/config/core/app.conf
        target: /etc/core/app.conf
      - type: bind
        source: ./data/secret/core/private_key.pem
        target: /etc/core/private_key.pem
      - type: bind
        source: ./data/secret/keys/secretkey
        target: /etc/core/key
      - type: bind
        source: ./common/config/shared/trust-certificates
        target: /harbor_cust_cert
    networks:
      harbor:
    depends_on:
      - log
      - registry
      - redis
      - postgresql
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "core"
  portal:
    image: goharbor/harbor-portal:v2.10.3
    container_name: harbor-portal
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - NET_BIND_SERVICE
    volumes:
      - type: bind
        source: ./common/config/portal/nginx.conf
        target: /etc/nginx/nginx.conf
    networks:
      - harbor
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "portal"

  jobservice:
    image: goharbor/harbor-jobservice:v2.10.3
    container_name: harbor-jobservice
    env_file:
      - ./common/config/jobservice/env
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - ./data/job_logs:/var/log/jobs:z
      - type: bind
        source: ./common/config/jobservice/config.yml
        target: /etc/jobservice/config.yml
      - type: bind
        source: ./common/config/shared/trust-certificates
        target: /harbor_cust_cert
    networks:
      - harbor
    depends_on:
      - core
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "jobservice"
  redis:
    image: goharbor/redis-photon:v2.10.3
    container_name: redis
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    volumes:
      - ./data/redis:/var/lib/redis
    networks:
      harbor:
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "redis"
  proxy:
    image: goharbor/nginx-photon:v2.10.3
    container_name: nginx
    restart: always
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - NET_BIND_SERVICE
    volumes:
      - ./common/config/nginx:/etc/nginx:z
      - ./data/secret/cert:/etc/cert:z
      - type: bind
        source: ./common/config/shared/trust-certificates
        target: /harbor_cust_cert
    networks:
      - harbor
    ports:
      - 31050:8080
      - 31051:8443
    depends_on:
      - registry
      - core
      - portal
      - log
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://localhost:1514"
        tag: "proxy"
networks:
  harbor:
    external: false

```

### code-hub
docker-compose.yaml
```bash
services:
  gitlab:
    image: gitlab/gitlab-ce:17.3.0-ce.0
    container_name: gitlab
    hostname: 'code-hub.russionbear.com'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://code-hub.russionbear.com'
        gitlab_rails['gitlab_shell_ssh_port'] = 22
    ports:
      - 31060:80
      - 31061:443
      - 31062:22
    volumes:
      - ./config:/etc/gitlab
      - ./logs:/var/log/gitlab
      - ./data:/var/opt/gitlab
      - /etc/hosts:/etc/hosts
    shm_size: '256m'
  gitlab-runner-01:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner-01
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./runner-01-config:/etc/gitlab-runner
      - /etc/hosts:/etc/hosts

```


gitlab-runner/config.toml
```bash
concurrent = 1
check_interval = 0
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "runner-01"
  url = "https://code-hub.russionbear.com"
  id = 5
  token = ""
  token_obtained_at = 2024-08-21T08:48:45Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    MaxUploadedArchiveSize = 0
  [runners.docker]
    tls_verify = false
    image = "ubuntu:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
    network_mode = "host"
    network_mtu = 0


```




## general
storage
k8s

> os at phyical machine is just an environment, dont' t use ssh to connect it

- tc-cloud port is 3202

## build lxd environment
```bash

```

## /etc/hosts
```bash
127.0.0.1 localhost
127.0.1.1 russionbear-SER

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters


## ZEROTIER BEGIN
### only used for phyical machine os or cloud machine
192.168.191.149 tc-cloud-server.ws
192.168.191.89  box-server.ws
192.168.191.123 mini-serverws.ws
## ZEROTIER END

## INNER BEGIN

### only used for host in inner net for fast
10.152.106.1    mini-server.ws  fs.russionbear.com s3.russionbear.com admin-s3.russionbear.com db.russionbear.com harbor.russionbear.com code-hub.russionbear.com devops.russionbear.com jumpserver.russionbear.com work-env.russionbear.com
192.168.191.123                    fs.-.mini-server.ws s3.-.mini-server.ws admin-s3.-.mini-server.ws db.-.mini-server.ws harbor.-.mini-server.ws code-hub.-.mini-server.ws devops.-.mini-server.ws jumpserver.-.mini-server.ws work-env.-.mini-server.ws

10.152.106.1    lxd.mini-server.ws

### ignore bd.mini-server.ws bd.russionbear.com 
10.152.106.230  fs.mini-server.ws
10.152.106.52   s3.mini-server.ws admin-s3.mini-server.ws 
10.152.106.219  db.mini-server.ws
10.152.106.182  harbor.mini-server.ws
10.152.106.105  code-hub.mini-server.ws

10.152.106.26   devops.mini-server.ws
10.152.106.158  jumpserver.mini-server.ws

10.152.106.27   work-env.mini-server.ws

10.152.106.253  master-k8s.mini-server.ws
10.152.106.174  worker1-k8s.mini-server.ws
10.152.106.149  worker2-k8s.mini-server.ws

## INNER END
```

## bd
none

## fs
> nfs can't export to out net when config cloud-gateway host

```bash
apt install nfs-kernel-server -y
apt install apache2 -y

sudo a2enmod dav
sudo a2enmod dav_fs
systemctl restart apache2
sudo htpasswd -c /etc/apache2/webdav.users russionbear
mkdir /var/www/dav

```
`vim /etc/apache2/sites-available/000-default.conf`
```xml
        Alias / /var/www/dav
        <Location />
                DAV On
                AuthType Basic
                AuthName "WebDAV"
                AuthUserFile /etc/apache2/webdav.users
                Require valid-user
        </Location>

```

`sudo systemctl restart apache2`

## s3

vim /etc/default/minio
```bash
MINIO_OPTS = --console-address ":9001"   --address ":80" 
MINIO_ROOT_USER = admin 
MINIO_ROOT_PASSWORD = password
MINIO_VOLUMES = 
```
or  
systemd
```ini
[Unit]
Description=Minio Storage Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/data
ExecStart=/usr/local/bin/minio server /data/s3 --console-address ":80" --address ":80"
Environment=MINIO_ROOT_USER=admin MINIO_ROOT_PASSWORD=password
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## db

docker-compose.yaml
```yaml
services:
  mysql-container:
    image: mysql:8.3.0-oracle
    container_name: mysql-container
    restart: always
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root@mysql
    volumes:
      - /data/ws/mysql-data:/var/lib/mysql

#   bind-container:
#     image: sameersbn/bind:latest
#     container_name: bind-container
#     restart: always
#     environment:
#       WEBMIN_INIT_SSL_ENABLED: false
#     ports:
#       - "53:53/tcp"
#       - "53:53/udp"
#       - "10000:10000/tcp"
#     volumes:
#       - /data/ws/bind-data:/data

  redis-container:
    image: redis
    container_name: redis-container
    restart: always
    ports:
      - "6379:6379"
    command: --requirepass redis@redis
    volumes:
      - /data/ws/redis-data:/data

  mongodb:
    image: mongo
    container_name: mongodb
    restart: always
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: root@mongo
    volumes:
      - /data/ws/mongo-data:/data/db
#  postgresql-container:
#    image:
#    volumes:
#      - /var/lib/postgresql/data

  rabbitmq:
    image: rabbitmq:3-management-alpine  # 使用包含管理界面的RabbitMQ镜像
    container_name: rabbitmq
    ports:
      - "5672:5672"  # RabbitMQ 默认AMQP端口
      - "15672:15672" # RabbitMQ管理界面端口
    environment:
      - RABBITMQ_DEFAULT_USER=russionbear
      - RABBITMQ_DEFAULT_PASS=redhat

  kafka:
    image: apache/kafka:3.8.0 
    container_name: kafka
    ports:
      - "9092:9092"
```

## microk8s
[use the microk8s profile  when create instance ](https://microk8s.io/docs/install-lxd)
snap install microk8s --classic

vim /etc/environment (does not need `export`) or bashrc (need `export`)
```bash
# remember to replace hostname
export HTTPS_PROXY=http://10.152.106.1:7890
export HTTP_PROXY=http://10.152.106.1:7890
export ALL_PROXY=http://10.152.106.1:7890
export NO_PROXY=10.0.0.0/8,192.168.0.0/16,127.0.0.1,10.0.0.0/8,.svc,localhost
```

install
```bash
lxc exec microk8s -- sudo snap install microk8s --classic

microk8s kubectl get -n kube-system  pods 

```

waiting   

addons
```bash
# microk8s.enable dns
microk8s.enable rbac 
# microk8s.enable dashboard

# microk8s.enable minio
microk8s.enable  observability # prometheus
# microk8s.enable metallb 
# microk8s.enable metrics-server
```


### master
> HA master
```bash
microk8s add-node
## or
microk8s join 1xxxxxx  
```

### worker
```bash
microk8s join 1xxxxxx --worker
```

### ~~~prometheus~~~observability


## code-hub

code-hub-compose.service
```ini
[Unit]
Description=Docker Compose Application
After=docker.service

[Service]
Type=simple
WorkingDirectory=/home/russionbear/code-hub
ExecStartPre=-/usr/bin/docker compose down
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

docker-compose.yaml for gitea
```yaml
services:
  gitea-container:
    image: gitea/gitea:latest
    restart: always
    container_name: gitea-container
    volumes:
      - /data/ws/gitea:/data/gitea
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "2222:2222"
  gitea-runner-01:
    image: gitea/act_runner:nightly
    container_name: gitea-runner-01
    restart: always
    environment:
      CONFIG_FILE: /config.yaml
      GITEA_INSTANCE_URL: "http://gitea-container:3000"
      GITEA_RUNNER_REGISTRATION_TOKEN: "nHWxH7KTzpVPSflTiRFSYw96I61Ff0rdHowWKY7W"
      GITEA_RUNNER_NAME: "runner01"
      GITEA_RUNNER_LABELS: "all-in-one"
    volumes:
      - ./gitea-runner-config.yaml:/config.yaml
      - /data/ws/gitea-runner01-data:/data
      - /var/run/docker.sock:/var/run/docker.sock
```

docker-compose.yaml for gitlab
```yaml
services:
  gitlab:
    image: gitlab/gitlab-ce:17.3.0-ce.0
    container_name: gitlab
    restart: always
    hostname: 'code-hub.russionbear.com'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://code-hub.russionbear.com'
        gitlab_rails['gitlab_shell_ssh_port'] = 22
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - '/data/ws/code-hub/config:/etc/gitlab'
      - '/data/ws/code-hub/logs:/var/log/gitlab'
      - '/data/ws/code-hub/data:/var/opt/gitlab'
    shm_size: '256m'
  gitlab-runner-01:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner-01
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
        #      - /data/ws/code-hub/runner-01-config:/etc/gitlab-runner
```
```bash
# https://docs.gitlab.com/runner/register/index.html?tab=Docker
gitlab-runner register  --url https://code-hub.russionbear.com  --token Vu4gma5N4xpEpHxYAvnh

gitlab-runner register  --url https://code-hub.russionbear.com  --token glrt-i8mQhBjvMB8dc_4PsHJU
```

/etc/gitlab-runner/config.toml 
```ini
concurrent = 1
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800
```

## devops
install jenkins

## jumpserver
```bash
./jmsctl.sh start

2. Other management commands
./jmsctl.sh stop
./jmsctl.sh restart
./jmsctl.sh backup
./jmsctl.sh upgrade
```

`@reboot sleep 10 && /home/user/start.sh`


or


jumpserver
```ini
[Unit]
Description=JMS Service
After=docker.service network.target

[Service]
Type=forking
WorkingDirectory=/opt/jumpserver-installer-v4.1.0
ExecStart=/opt/jumpserver-installer-v4.1.0/jmsctl.sh start
ExecStop=/opt/jumpserver-installer-v4.1.0/jmsctl.sh stop
ExecRestart=/opt/jumpserver-installer-v4.1.0/jmsctl.sh restart

[Install]
WantedBy=multi-user.target

```

## work-env

## phycial machine
only access by inner net
### install vnc server

## coder
```yaml
services:
  code-server:
    image: codercom/code-server:latest
    container_name: code-server
    ports:
      - "127.0.0.1:32081:8080"
    volumes:
      - "./_local:/home/coder/.local"
      - "./_config:/home/coder/.config"
      - "./project:/home/coder/project"
    user: "${UID}:${GID}"
    environment:
      - DOCKER_USER=${USER}
    tty: true
    interactive: true
```

## QA

### cofig ssh
### add user
```sh
useradd -d /home/russionbear -s /bin/bash russionbear &> /dev/null 
echo 'russionbear ALL=(ALL:ALL) NOPASSWD:ALL' > /etc/sudoers.d/russionbear  
mkdir -p /home/russionbear/.ssh 
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPz6Mu8YCVkCJLeL8eWMi9vs9uiX39LUlCysJ9fgu9Rm russionbear@work-env.mini-server.ws" > /home/russionbear/.ssh/authorized_keys 
chown russionbear:russionbear /home/russionbear -R 
# apt update
apt install openssh-server
# echo 'PasswordAuthentication no' > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl enable ssh --now
```

### install and config docker
```bash
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
# step 2: 安装GPG证书
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
# Step 3: 写入软件源信息
sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable"
# Step 4: 更新并安装Docker-CE
sudo apt-get -y update
sudo apt-get -y install docker-ce
```

`vim /etc/docker/daemon.json`
> search a mirror at web
```json
{
    "registry-mirrors": [ "https://docker.awsl9527.cn/" ]
}
```

any lxd instance used docker should run `lxc config set isntance_name security.nesting=true security.syscalls.intercept.mknod=true security.syscalls.intercept.setxattr=true`


### mirrors for microk8s
[config](https://microk8s.io/docs/registry-private)

### use proxy for instance or microk8s
bashrc
```bash
export HTTPS_PROXY=http://10.152.106.1:7890
export HTTP_PROXY=http://10.152.106.1:7890
export ALL_PROXY=http://10.152.106.1:7890
export NO_PROXY=10.0.0.0/8,192.168.0.0/16,127.0.0.1,172.16.0.0/16,.svc,localhost
```
> /etc/environment  remember to remove 'export'

### linux optimization
- ntp
- `timedatectl set-timezone Asia/Shanghai`
- apt source


### microk8s private mirror

### ~~create ca~~
### modify harbor export url

### docker can't access mini-server
update `/etc/hosts` in container


### rsync + ssh pubkey
`rsync -avzP {{ item.src_path }} russionbear@10.152.106.231:{{ item.dest_path }} --delete -e 'ssh -p 22 -o StrictHostKeyChecking=no -i /root/.ssh/id_backup'`



### generate password
```bash
for i in wedav rabbitmq mysql redis mongo kafka s3 code-hub harbor jenkins jumpserver work-env
do
        openssl rand -base64 16 > ${i}.pass
done
```

### add user for  webdav
`htpasswd -bc webdav.users username password`


### jumpserver trust domain
修改`/opt/jumpserver/config/config.txt` , fllow the example  
DOMAINS="


### network about lxd and docker
```bash
iptables -I DOCKER-USER -i lxdbr0 -j ACCEPT
iptables -I DOCKER-USER -o lxdbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo apt install iptables-persistent
netfilter-persistent  save
```
