#!/bin/sh
# $0 backup|restore key user password

operate=$1
key=$2
user=$3
password=$4

# 定义你想排除的系统数据库
exclude_dbs="information_schema|performance_schema|mysql|sys"

backup () {

    # 获取所有数据库名，并过滤掉系统数据库
    databases=$(mysql -u$user -p${password} -e "SHOW DATABASES;" --skip-column-names | grep -Ev "${exclude_dbs}")

    mkdir -p /tmp/backup
    rm -rf /tmp/backup/*
    touch /tmp/backup/README.md
    # 遍历每个数据库并导出
    for db in $databases; do
        echo "Dumping database: $db"
        mysqldump -u$user -p${password} --databases "$db"  > "/tmp/backup/${key}-${db}.sql"
    done

    if ! [ -e /tmp/backup/*.sql ];then
        exit 1
    fi

    tar -czf /tmp/backup/${key}.tar.gz /tmp/backup/*.sql /tmp/backup/README.md


}


restore(){
    rm -rf /tmp/backup/*.sql
    tar -xvf /tmp/backup/${key}.tar.gz
    if ! [ -e /tmp/backup/*.sql ];then
        exit
    fi

    for i in $(ls /tmp/backup/*.sql);do
        s1=${i#*-}
        db=${s1%.sql}
        echo "Restoring database: $db"
        mysql -u$user -p${password} -e "DROP DATABASE IF EXISTS $db;"
        mysql -u$user -p${password} < $i
    done
}



if [ "$operate" = "backup" ];then
    backup
elif [ "$operate" = "restore" ];then
    restore
else
    echo "Usage: $0 backup|restore key user password"
fi
