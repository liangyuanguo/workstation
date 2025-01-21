#!/bin/sh


operate=$1
key=$2
user=$3
password=$4


<< EOF
FOR TEST

use test

// 插入一条数据到新集合中，这将同时创建数据库和集合
db.myCollection.insertOne({ name: "example", value: 1 })
db.myCollection.find()
EOF

backup () {


    
cat > /tmp/getdb.js <<EOF
db.getMongo().getDBNames().filter(db => !["admin","config","local"].includes(db)).forEach(item => console.log(item))
EOF


    DATABASES=$(mongosh -u ${user} -p ${password} /tmp/getdb.js)

    mkdir -p /tmp/backup
    rm -rf /tmp/backup/*
    touch /tmp/backup/README.md

    # 遍历所有非系统数据库并进行备份
    echo "$DATABASES" | while IFS= read -r DB_NAME; do
        echo "Backing up database: $DB_NAME"
        mongodump --uri="mongodb://${user}:${password}@localhost:27017/$DB_NAME?authSource=admin" --out="/tmp/backup"
    done


    tar -czf /tmp/backup/${key}.tar.gz /tmp/backup/*
}


restore() {
    find /tmp/backup/* -type d -maxdepth 0 | xargs -I {} rm -rf  {} 
    tar -xvf /tmp/backup/${key}.tar.gz
    # if ! [ -e /tmp/backup/*.bson ];then
    #     exit
    # fi

    mongorestore --uri="mongodb://${user}:${password}@localhost:27017/?authSource=admin" --drop /tmp/backup
}


if [ "$operate" = "backup" ];then
    backup
elif [ "$operate" = "restore" ];then
    restore
else
    echo "Usage: $0 backup|restore key user password"
fi

