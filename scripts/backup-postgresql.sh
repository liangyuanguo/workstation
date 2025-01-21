#!/bin/sh
# $0 backup|restore key user password

operate=$1
key=$2
user=$3
password=$4
should_drop=${5:-1}

export PGPASSWORD=${password} 


backup () {
    mkdir -p /tmp/backup
    rm -rf /tmp/backup/*
    touch /tmp/backup/README.md
    
    pg_dumpall -U ${user} > /tmp//backup/all_databases_backup.sql

    tar -czf /tmp/backup/${key}.tar.gz /tmp//backup/all_databases_backup.sql /tmp/backup/README.md
}


restore(){

    rm -rf /tmp/backup/*.sql
    tar -xvf /tmp/backup/${key}.tar.gz
    if ! [ -e /tmp/backup/*.sql ];then
        exit
    fi

    if [ "$should_drop" = "1" ];then
        databases=$(psql -U ${user} -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'template0', 'template1')")

        # 循环删除数据库
        for db in $databases; do
            psql -U ${user} -c "DROP DATABASE $db"
        done

        psql -U ${user} -f /tmp/drop.sql
    fi
    psql -U ${user} -f /tmp//backup/all_databases_backup.sql
}


if [ "$operate" = "backup" ];then
    backup
elif [ "$operate" = "restore" ];then
    restore
else
    echo "Usage: $0 backup|restore key user password"
fi

