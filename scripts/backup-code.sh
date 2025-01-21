#!/bin/bash


operate=$1
key=$2

backup () {

    if ! [ -f /home/coder/.bakignore ];then
        touch /home/coder/.bakignore
    fi

    # 初始化空字符串作为 exclude 参数
    exclude_args=""

    # 读取 .gitignore 文件并为每个模式添加 --exclude 参数
    while IFS= read -r pattern; do
        # 忽略注释和空行
        pattern=$(echo "$pattern" | tr -d "'")
        [[ "$pattern" =~ ^# ]] && continue
        [[ "$pattern" =~ "^ *$" ]] && continue

        # 添加到 exclude_args 变量
        exclude_args+="--exclude='$pattern' "
    done < .bakignore

    cd  /home/coder
    # 执行 tar 命令，包含所有 exclude 参数
    eval "tar $exclude_args -zcf /tmp/${key}.tar.gz /home/coder "
}


restore() {
    tar -xf /tmp/${key}.tar.gz  -C /
    rm  /tmp/${key}.tar.gz
}


if [ "$operate" = "backup" ];then
    backup
elif [ "$operate" = "restore" ];then
    restore
else
    echo "Usage: $0 backup|restore key user password"
fi


