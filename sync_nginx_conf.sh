#!/bin/bash
#by cyz v1
set -e
sbin_file="/home/work/app/nginx/sbin/nginx"
conf_dir="/home/work/app/nginx/conf/vhosts"
conf_file=$1
node2="要同步的目标"

function md5check() {
 echo "开始比对${conf_file}md5值"
 locamd5=`md5sum ${conf_dir}/${conf_file}`
 remotemd5=`ssh ${node2} "md5sum ${conf_dir}/${conf_file}"`
 echo "本地md5:${locamd5}"
 echo "远程md5:${remotemd5}"
 echo "-----------------------------------------------"
}

function syntax() {
 echo "开始语法检查$(hostname)"
 ${sbin_file} -t
 echo "开始语法检查${node2}"
 ssh ${node2} ${sbin_file} -t
 echo "-----------------------------------------------"
}

function sync_file() {
 echo "开始同步文件${conf_file}"
 scp ${conf_dir}/${conf_file} ${node2}:${conf_dir}/
 echo "-----------------------------------------------"
}

function backup_file() {
 echo "开始备份文件"
 date=`date +%Y-%m-%d`
 cp ${conf_dir}/${conf_file} ${conf_dir}/bak/${conf_file}.${date}
 if [ "$?" -ne 0 ];then
   echo "备份失败"
   exit 1
 fi

 echo "备份成功"
 exit
}

function rollback() {
 echo "要回滚的配置文件是${conf_file}"
 read -p "只能回滚最近一次的操作备份,确认要回滚吗?(y/(n) " anser

 if [[ "$anser" != @("y"|"Y"|"Yes"|"yes") ]]; then
    echo -e "\033[31m Nothing to do, exitting...\033[0m"
    exit
 fi

 date=`date +%Y-%m-%d`
 cp ${conf_dir}/bak/${conf_file}.${date} ${conf_dir}/${conf_file}
 export conf_file=${conf_file}
 sync_file
 md5check
 syntax
 /home/work/app/nginx/sbin/nginx -s reload && ssh ${node2} "/home/work/app/nginx/sbin/nginx -s reload"
 if [ "$?" -ne 0 ];then
  echo "回滚失败"
  exit 1
 fi
 echo "回滚成功"
 exit
}

function checkexits() {
 if [ ! -f "${conf_dir}/${conf_file}" ];then
   echo "没找到文件 ${conf_dir}/${conf_file}"
   exit
 fi
}

if [ "$#" -lt 1 -o "$#" -gt 2 ];then
    echo "usage: $0 {conf_name} OR rollback {conf_name} OR backup {conf_name}"
    exit 1
fi

#备份配置
if [[ "$1" == "backup" ]];then
 export conf_file=$2
 if [[ "${conf_file}" == "" ]];then
  echo "输入要备份的配置文件.如:cloud-gateway.cloud.srv.conf"
 fi
 checkexits
 backup_file
fi

#回滚配置
if [[ "$1" == "rollback" ]];then
 export conf_file=$2
 if [[ "${conf_file}" == "" ]];then
  echo "输入要回滚的配置文件.如:cloud-gateway.cloud.srv.conf"
 fi
 checkexits
 rollback
fi

#同步配置
checkexits
echo "-----------------------------------------------"
sync_file
md5check
syntax

read -p "要重载配置文件吗?(y/(n) " ans

if [[ "$ans" != @("y"|"Y"|"Yes"|"yes") ]]; then
    echo -e "\033[31m Nothing to do, exitting...\033[0m"
    exit
fi

/home/work/app/nginx/sbin/nginx -s reload && ssh ${node2} "/home/work/app/nginx/sbin/nginx -s reload"
if [ "$?" -ne 0 ];then
  echo "reload faild"
  exit 1
fi

echo "reload sucess"
