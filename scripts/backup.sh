#!/bin/bash


key=202501  # 禁止 -
mysql_user=root
mysql_password=mysql
redis_password=redis
mongodb_user=root
mongodb_password=mongodb
postgresql_user=postgres
postgresql_password=postgresql
minio_url=https://s3.russionbear.com
minio_ak=minio
minio_sk=minio123

gitea_postgresql_user=postgres
gitea_postgresql_password=gitea

nextcloud_postgresql_user=postgres
nextcloud_postgresql_password=nextcloud

mc='./bin/mc'
mkdir -p backup

function mysql_backup(){
    for pod in $(kubectl get pods -l app=mysql --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        kubectl  -n ws-dbaas-base  cp scripts/backup-mysql.sh  ${pod}:/tmp/backup.sh
        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh /tmp/backup.sh backup ${key} ${mysql_user} ${mysql_password}
        if  [ $? -eq 0 ];then
            kubectl  -n ws-dbaas-base  cp  ${pod}:/tmp/backup/${key}.tar.gz ./backup/${key}-${pod}.tar.gz
        else
            echo  "backup fail"
        fi
    done
}
function mysql_restore(){
    for pod in $(kubectl get pods -l app=mysql --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        echo $pod
        if ! [ -e ./backup/${key}-${pod}.tar.gz ];then
            echo "backup file not exist"
            continue
        fi
        kubectl  -n ws-dbaas-base  cp scripts/backup-mysql.sh  ${pod}:/tmp/backup.sh
        kubectl  -n ws-dbaas-base  exec  ${pod} -- mkdir -p /tmp/backup/
        kubectl  -n ws-dbaas-base  cp  ./backup/${key}-${pod}.tar.gz ${pod}:/tmp/backup/${key}.tar.gz

        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh /tmp/backup.sh restore ${key} ${mysql_user} ${mysql_password}
    done

}

function redis_backup(){
    for pod in $(kubectl get pods -l app=redis --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh -c " tar -zcvf  /tmp/${key}-${pod}.tar.gz /data/appendonlydir/* "
        kubectl  -n ws-dbaas-base  cp  ${pod}:/tmp/${key}-${pod}.tar.gz ./backup/${key}-${pod}.tar.gz
        kubectl  -n ws-dbaas-base  exec  ${pod} --  rm -rf /tmp/${key}-${pod}.tar.gz
    done
}
function redis_restore(){
    for pod in $(kubectl get pods -l app=redis --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        if ! [ -e ./backup/${key}-${pod}.tar.gz ];then
            echo "backup file not exist"
            continue
        fi
        kubectl  -n ws-dbaas-base  cp  ./backup/${key}-${pod}.tar.gz ${pod}:/tmp/${key}-${pod}.tar.gz
        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh -c "rm -rf /data/appendonlydir/*  &&  tar -xvf /tmp/${key}-${pod}.tar.gz -C /   && redis-cli -a ${redis_password} SHUTDOWN"
    done
}

function mongodb_backup(){
    for pod in $(kubectl get pods -l app=mongodb --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        kubectl  -n ws-dbaas-base  cp scripts/backup-mongodb.sh  ${pod}:/tmp/backup.sh
        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh /tmp/backup.sh backup ${key} ${mongodb_user} ${mongodb_password}
        if  [ $? -eq 0 ];then
            kubectl  -n ws-dbaas-base  cp  ${pod}:/tmp/backup/${key}.tar.gz ./backup/${key}-${pod}.tar.gz
        else
            echo  "backup fail"
        fi
    done
}
function mongodb_restore(){
    for pod in $(kubectl get pods -l app=mongodb --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        echo $pod
        if ! [ -e ./backup/${key}-${pod}.tar.gz ];then
            continue
        fi
        kubectl  -n ws-dbaas-base  cp scripts/backup-mongodb.sh  ${pod}:/tmp/backup.sh
        kubectl  -n ws-dbaas-base  exec  ${pod} -- mkdir -p /tmp/backup/
        kubectl  -n ws-dbaas-base  cp  ./backup/${key}-${pod}.tar.gz ${pod}:/tmp/backup/${key}.tar.gz

        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh /tmp/backup.sh restore ${key} ${mongodb_user} ${mongodb_password}
    done

}

function postgresql_backup(){
    for pod in $(kubectl get pods -l app=postgresql --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        kubectl  -n ws-dbaas-base  cp scripts/backup-postgresql.sh  ${pod}:/tmp/backup.sh
        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh /tmp/backup.sh backup ${key} ${postgresql_user} ${postgresql_password}
        if  [ $? -eq 0 ];then
            kubectl  -n ws-dbaas-base  cp  ${pod}:/tmp/backup/${key}.tar.gz ./backup/${key}-${pod}.tar.gz
        else
            echo  "backup fail"
        fi
    done
}
function postgresql_restore(){
    for pod in $(kubectl get pods -l app=postgresql --namespace=ws-dbaas-base | awk 'NR>1{print $1}');do
        echo $pod
        if ! [ -e ./backup/${key}-${pod}.tar.gz ];then
            echo "backup file not exist"
            continue
        fi
        kubectl  -n ws-dbaas-base  cp scripts/backup-postgresql.sh  ${pod}:/tmp/backup.sh
        kubectl  -n ws-dbaas-base  exec  ${pod} -- mkdir -p /tmp/backup/
        kubectl  -n ws-dbaas-base  cp  ./backup/${key}-${pod}.tar.gz ${pod}:/tmp/backup/${key}.tar.gz

        kubectl  -n ws-dbaas-base  exec  ${pod} -- sh /tmp/backup.sh restore ${key} ${postgresql_user} ${postgresql_password}
    done

}

function minio_backup(){
    mkdir -p ./backup/minio
    $mc alias set myminio $minio_url $minio_ak $minio_sk
    $mc mirror  --overwrite --remove myminio/ ./backup/minio
}
function minio_restore(){
    $mc alias set myminio $minio_url $minio_ak $minio_sk
    if [ ! -d ./backup/minio ];then
        echo "backup minio not exist"
        exit
    fi
    $mc mirror  --overwrite --remove ./backup/minio myminio/
}
function minio_migrate(){
    $mc alias set myminio $minio_url $minio_ak $minio_sk
    $mc alias set target $minio_url $minio_ak $minio_sk
    $mc mirror  --overwrite --remove myminio/ target/
}

function kc_backup(){
    echo "需要手动导 而且不能导user数据"
    # local pod=kc-postgresql-0 
    # kubectl  -n ws-dbaas-kc  cp scripts/backup-postgresql.sh  ${pod}:/tmp/backup.sh
    # kubectl  -n ws-dbaas-kc  exec  ${pod} -- sh /tmp/backup.sh backup ${key} ${kc_postgresql_user} ${kc_postgresql_password}
    # if  [ $? -eq 0 ];then
    #     kubectl  -n ws-dbaas-kc  cp  ${pod}:/tmp/backup/${key}.tar.gz ./backup/kc-${key}-${pod}.tar.gz
    # else
    #     echo  "backup fail"
    # fi
}
function kc_restore(){
    echo "需要手动导 而且不能导user数据"
    # local pod=kc-postgresql-0 
    # if ! [ -e ./backup/kc-${key}-${pod}.tar.gz ];then
    #     echo "backup file not exist"
    #     continue
    # fi
    # kubectl  -n ws-dbaas-kc  cp scripts/backup-postgresql.sh  ${pod}:/tmp/backup.sh 
    # kubectl  -n ws-dbaas-kc  exec  ${pod} -- mkdir -p /tmp/backup/
    # kubectl  -n ws-dbaas-kc  cp  ./backup/kc-${key}-${pod}.tar.gz ${pod}:/tmp/backup/${key}.tar.gz

    # kubectl  -n ws-dbaas-kc  exec  ${pod} -- sh /tmp/backup.sh restore ${key} ${kc_postgresql_user} ${kc_postgresql_password}
    # kubectl  -n ws-dbaas-kc  delete pods  ${pod} 
}


function code_backup(){
    local pod=$(kubectl get pods -n ws-saas-code | awk 'NR>1{print $1}')
    kubectl  -n ws-saas-code  cp -c code-server scripts/backup-code.sh  ${pod}:/tmp/backup.sh
    kubectl  -n ws-saas-code  exec -c code-server  ${pod}  -- bash /tmp/backup.sh backup ${key}
    if  [ $? -eq 0 ];then
        kubectl  -n ws-saas-code  cp  -c code-server ${pod}:/tmp/${key}.tar.gz ./backup/code-${key}.tar.gz
    else
        echo  "backup fail"
    fi
}
function code_restore(){
    local pod=$(kubectl get pods -n ws-saas-code | awk 'NR>1{print $1}')
    if ! [ -e ./backup/code-${key}.tar.gz ];then
        echo "backup file not exist"
        exit 1
    fi
    kubectl  -n ws-saas-code  cp -c code-server scripts/backup-code.sh  ${pod}:/tmp/backup.sh
    kubectl  -n ws-saas-code  cp  -c code-server ./backup/code-${key}.tar.gz ${pod}:/tmp/${key}.tar.gz

    kubectl  -n ws-saas-code  exec  -c code-server  ${pod} -- bash /tmp/backup.sh restore ${key}
}


function gitea_backup(){
    local pod=$(kubectl  -n ws-saas-gitea get pods -l app.kubernetes.io/name=gitea | awk 'NR>1{print $1}')
    local sql_pod=gitea-postgresql-0

    kubectl  -n ws-saas-gitea  exec  ${pod} -- tar -zcf /tmp/${key}.tar.gz /data
    kubectl  -n ws-saas-gitea  cp    ${pod}:/tmp/${key}.tar.gz ./backup/gitea-${key}.tar.gz

    kubectl  -n ws-saas-gitea  cp scripts/backup-postgresql.sh  ${sql_pod}:/tmp/backup.sh
    kubectl  -n ws-saas-gitea  exec  ${sql_pod} -- mkdir -p /tmp/backup
    kubectl  -n ws-saas-gitea  exec  ${sql_pod} -- sh /tmp/backup.sh backup ${key} ${gitea_postgresql_user} ${gitea_postgresql_password}
    kubectl  -n ws-saas-gitea  cp    ${sql_pod}:/tmp/backup/${key}.tar.gz ./backup/gitea-sql-${key}.tar.gz
}
function gitea_restore(){
    local pod=$(kubectl  -n ws-saas-gitea get pods -l app.kubernetes.io/name=gitea | grep -v action | awk 'NR>1{print $1}')
    local sql_pod=gitea-postgresql-0
    if ! [ -e ./backup/gitea-${key}.tar.gz ];then
        echo "backup file not exist"
        exit 1
    fi

    # echo "kubectl  -n ws-saas-gitea  cp   ./backup/gitea-${key}.tar.gz ${pod}:/tmp/${key}.tar.gz "
    kubectl  -n ws-saas-gitea  cp   ./backup/gitea-${key}.tar.gz ${pod}:/tmp/${key}.tar.gz 
    # exit 1
    kubectl  -n ws-saas-gitea  exec  ${pod} -- tar -xf /tmp/${key}.tar.gz -C /
    kubectl  -n ws-saas-gitea  exec  ${pod} -- rm /tmp/${key}.tar.gz
    
    # exit 1
    # sql
    kubectl  -n ws-saas-gitea  cp scripts/backup-postgresql.sh  ${sql_pod}:/tmp/backup.sh
    kubectl  -n ws-saas-gitea  exec  ${sql_pod} -- mkdir -p /tmp/backup
    kubectl  -n ws-saas-gitea  cp   ./backup/gitea-sql-${key}.tar.gz ${sql_pod}:/tmp/backup/${key}.tar.gz 
    kubectl  -n ws-saas-gitea  exec  ${sql_pod} -- sh /tmp/backup.sh restore ${key} ${gitea_postgresql_user} ${gitea_postgresql_password} 0 1> /dev/null
    kubectl  -n ws-saas-gitea  exec  ${sql_pod} -- rm /tmp/backup/${key}.tar.gz
    kubectl  -n ws-saas-gitea  rollout restart deploy gitea

}



function nextcloud_backup(){
    local pod=$( kubectl  -n ws-saas-nextcloud get pods -l app.kubernetes.io/name=nextcloud | awk 'NR>1{print $1}')
    local sql_pod=nextcloud-postgresql-0

    kubectl  -n ws-saas-nextcloud  exec  ${pod} -- tar -zcf /tmp/${key}.tar.gz /var/www
    kubectl  -n ws-saas-nextcloud  cp    ${pod}:/tmp/${key}.tar.gz ./backup/nextcloud-${key}.tar.gz

    kubectl  -n ws-saas-nextcloud  cp scripts/backup-postgresql.sh  ${sql_pod}:/tmp/backup.sh
    kubectl  -n ws-saas-nextcloud  exec  ${sql_pod} -- mkdir -p /tmp/backup
    kubectl  -n ws-saas-nextcloud  exec  ${sql_pod} -- sh /tmp/backup.sh backup ${key} ${nextcloud_postgresql_user} ${nextcloud_postgresql_password}
    kubectl  -n ws-saas-nextcloud  cp    ${sql_pod}:/tmp/backup/${key}.tar.gz ./backup/nextcloud-sql-${key}.tar.gz
}
function nextcloud_restore(){
    local pod=$( kubectl  -n ws-saas-nextcloud get pods -l app.kubernetes.io/name=nextcloud | awk 'NR>1{print $1}')
    local sql_pod=nextcloud-postgresql-0
    if ! [ -e ./backup/nextcloud-${key}.tar.gz ];then
        echo "backup file not exist"
        exit 1
    fi

    kubectl  -n ws-saas-nextcloud  cp   ./backup/nextcloud-${key}.tar.gz ${pod}:/tmp/${key}.tar.gz 
    # exit 1
    kubectl  -n ws-saas-nextcloud  exec  ${pod} -- tar -xf /tmp/${key}.tar.gz -C /
    kubectl  -n ws-saas-nextcloud  exec  ${pod} -- rm /tmp/${key}.tar.gz
    
    # sql
    kubectl  -n ws-saas-nextcloud  cp scripts/backup-postgresql.sh  ${sql_pod}:/tmp/backup.sh
    kubectl  -n ws-saas-nextcloud  exec  ${sql_pod} -- mkdir -p /tmp/backup
    kubectl  -n ws-saas-nextcloud  cp   ./backup/nextcloud-sql-${key}.tar.gz ${sql_pod}:/tmp/backup/${key}.tar.gz 
    kubectl  -n ws-saas-nextcloud  exec  ${sql_pod} -- sh /tmp/backup.sh restore ${key} ${nextcloud_postgresql_user} ${nextcloud_postgresql_password} 0 1> /dev/null
    kubectl  -n ws-saas-nextcloud  exec  ${sql_pod} -- rm /tmp/backup/${key}.tar.gz
    kubectl  -n ws-saas-nextcloud  rollout restart deploy nextcloud
}

function useage(){
cat <<EOF
    $0 <server> [restore|backup]
        server: minio|mysql|redis|mongodb|postgresql
EOF
}

function main(){
    server=$1
    operate=$2
    shift 2
    case ${server}_${operate} in
        minio_backup)
            minio_backup $@
            ;;
        minio_restore)
            minio_restore $@
            ;;
        mysql_backup)
            mysql_backup $@
            ;;
        mysql_restore)
            mysql_restore $@ 
            ;;
        redis_backup)
            redis_backup $@
            ;;
        redis_restore)
            redis_restore $@
            ;;
        mongodb_backup)
            mongodb_backup $@
            ;;
        mongodb_restore)
            mongodb_restore $@
            ;;
        postgresql_backup)
            postgresql_backup $@
            ;;
        postgresql_restore)
            postgresql_restore $@
            ;;
        minio_backup)
            minio_backup $@
            ;;
        minio_restore)
            minio_restore $@
            ;;
        minio_migrate)
            minio_migrate $@
            ;;
        kc_backup)
            kc_backup $@
            ;;
        kc_restore)
            kc_restore $@
            ;;
        code_backup)
            code_backup $@
            ;;
        code_restore)
            code_restore $@
            ;;
        gitea_backup)
            gitea_backup $@
            ;;
        gitea_restore)
            gitea_restore $@
            ;;
        nextcloud_backup)
            nextcloud_backup $@
            ;;
        nextcloud_restore)
            nextcloud_restore $@
            ;;
        *)
            useage
            ;;
    esac
}


main $@
