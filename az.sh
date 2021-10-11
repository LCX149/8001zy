
if [ "$(grep -q "cgroup_enable=memory\|swapaccount=1" /etc/default/grub;echo $?)" = 1 ];then
echo -e "您的系统似乎未开启内存限制，是否开启？\n  1  开启\n  2  不开启\n请输入数字并回车：\c"
read wd1
case $wd1 in
   1)
    if [ "$(grep -q "GRUB_CMDLINE_LINUX" /etc/default/grub;echo $?)" = 0 ];then
    sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1 /g" /etc/default/grub
    else
    echo 'GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"' >> /etc/default/grub
    fi
    
    if [ "$(grep -q "cgroup_enable=memory\|swapaccount=1" /etc/default/grub;echo $?)" = 0 ];then 
    sudo update-grub && echo -e "开启成功，请重启系统\n可输入：reboot 或其他方法重启\n重启后再次执行本脚本安装！"
    exit
    else
    echo -e "开启失败，请百度手动开启\n或重新执行本脚本选择不开启。"
    exit
    fi
   ;;
   *)
   echo "您选择的是不开启"
   sleep 3
   ;;
esac
fi


clear

echo "
     __    .___         ___.                         
    |__| __| _/         \_ |__ _____    ______ ____  
    |  |/ __ |   ______  | __ \\__  \  /  ___// __ \ 
    |  / /_/ |  /_____/  | \_\ \/ __ \_\___ \\  ___/ 
/\__|  \____ |           |___  (____  /____  >\___  >
\______|    \/               \/     \/     \/     \/
                                                                                                  
"
echo "安装即将开始！"
sleep 5

DOCKER_IMG_NAME="lcx149/bf"
JD_PATH=""
SHELL_FOLDER=$(pwd)
CONTAINER_NAME=""
CONFIG_PATH=""
LOG_PATH=""
TAG="ql_v4"

HAS_IMAGE=false
PULL_IMAGE=true

HAS_CONTAINER=false
DEL_CONTAINER=true
INSTALL_WATCH=false

TEST_BEAN_CHAGE=false

log() {
    echo -e "\e[32m$1 \e[0m\n"
}

inp() {
    echo -e "\e[33m$1 \e[0m\n"
}

warn() {
    echo -e "\e[31m$1 \e[0m\n"
}

cancelrun() {
    if [ $# -gt 0 ]; then
        echo     "\033[31m $1 \033[0m"
    fi
    exit 1
}

docker_install() {
    echo "检查Docker......"
    if [ -x "$(command -v docker)" ]; then
       echo "检查到Docker已安装!"
    else
       if [ -r /etc/os-release ]; then
            lsb_dist="$(. /etc/os-release && echo "$ID")"
        fi
        if [ $lsb_dist == "openwrt" ]; then
            echo "openwrt 环境请自行安装docker"
            #exit 1
        else
            echo "安装docker环境..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            echo "安装docker环境...安装完成!"
            systemctl enable docker
            systemctl start docker
        fi
    fi

if [ ! -x "$(command -v docker)" ]; then echo "docker安装失败，请稍后再试或手动安装";exit;fi
}



docker_install
warn "注意如果你什么都不清楚，建议所有选项都直接回车，使用默认选择！！！"
#配置文件目录
echo -n -e "\e[33m一.请输入配置文件保存的路径名/home/*,直接回车为当前目录:\e[0m"
read jd_path
JD_PATH=$jd_path
if [ -z "$jd_path" ]; then
    JD_PATH=$SHELL_FOLDER
fi
CONFIG_PATH=/home/$JD_PATH/config
LOG_PATH=/home/$JD_PATH/log
SCRIPTS_PATH=/home/$JD_PATH/scripts

#检测镜像是否存在
if [ ! -z "$(docker images -q $DOCKER_IMG_NAME:$TAG 2> /dev/null)" ]; then
    HAS_IMAGE=true
    inp "检测到先前已经存在的镜像，是否拉取最新的镜像：\n1) 是[默认]\n2) 不需要"
    echo -n -e "\e[33m输入您的选择->\e[0m"
    read update
    if [ "$update" = "2" ]; then
        PULL_IMAGE=false
    fi
fi

#检测容器是否存在
check_container_name() {
    if [ ! -z "$(docker ps -a | grep $CONTAINER_NAME 2> /dev/null)" ]; then
        HAS_CONTAINER=true
        inp "检测到先前已经存在的容器，是否删除先前的容器：\n1) 是[默认]\n2) 不要"
        echo -n -e "\e[33m输入您的选择->\e[0m"
        read update
        if [ "$update" = "2" ]; then
            PULL_IMAGE=false
            inp "您选择了不要删除之前的容器，需要重新输入容器名称"
            input_container_name
        fi
    fi
}

#容器名称
input_container_name() {
    echo -n -e "\e[33m三.请输入要创建的Docker容器名称[默认为：jd]->\e[0m"
    read container_name
    if [ -z "$container_name" ]; then
        CONTAINER_NAME="jd"
    else
        CONTAINER_NAME=$container_name
    fi
    check_container_name
}
input_container_name


#配置已经创建完成，开始执行

#log "1.开始创建配置文件目录"
#mkdir -p $CONFIG_PATH
#mkdir -p $LOG_PATH


if [ $HAS_IMAGE = true ] && [ $PULL_IMAGE = true ]; then
    log "2.1.开始拉取最新的镜像"
    docker pull $DOCKER_IMG_NAME:$TAG
fi

if [ $HAS_CONTAINER = true ] && [ $DEL_CONTAINER = true ]; then
    log "2.2.删除先前的容器"
    docker stop $CONTAINER_NAME >/dev/null
    docker rm $CONTAINER_NAME >/dev/null
fi

log "3.开始创建容器并执行,若出现Unable to find image请耐心等待"
docker run -dit \
    -v $CONFIG_PATH:/ql/config \
    -v $LOG_PATH:/ql/log \
    -v $SCRIPTS_PATH:/ql/scripts \
    --name $CONTAINER_NAME \
    --hostname $CONTAINER_NAME \
    -p 13570:5700 \
    -m 1524M \
    --restart always \
    --network bridge \
    $DOCKER_IMG_NAME:$TAG

RQLJ=$(docker inspect $CONTAINER_NAME|grep -m1 "MergedDir"|awk -F 'overlay2/' '{print $2}'|awk -F '/' '{print $1}')

if [ $INSTALL_WATCH = true ]; then
    log "3.1.开始创建容器并执行"
    docker run -d \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower
fi


if [ -x "$(command -v zsh)" ]; then
echo "检测到已安装zsh，跳过"
else
echo "准备安装zsh"
sleep 5
yes | sudo apt-get install zsh
sleep 5
fi

echo "安装ohmyzsh"
yes | sh -c "$(wget -O- https://gitee.com/shmhlsy/oh-my-zsh-install.sh/raw/master/install.sh)"
echo "ohmyzsh安装完成"
sleep 5

echo "安装zsh-auto"
git clone http://ghproxy.com/https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
echo "完成"
sleep 5

sed -i 's/plugins=(git/plugins=(git zsh-autosuggestions/g' ~/.zshrc
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="random"/g' ~/.zshrc

source ~/.zshrc &> /dev/null
echo "配置zsh-auto完成"

log "4.下面列出所有容器"
docker ps

#echo "下载红包雨"
#wget -P /var/lib/docker/overlay2/$RQLJ/merged/jd/scripts https://ghproxy.com/https://raw.githubusercontent.com/LCX149/8001zy/main/hbynew.js
#wget -P /var/lib/docker/overlay2/$RQLJ/merged/jd/scripts https://ghproxy.com/https://raw.githubusercontent.com/LCX149/8001zy/main/bdhby.js
#echo "红包雨下载完毕,请自行设置定时任务"
echo "安装已经完成，by:lcx149"
chsh -s /bin/zsh
zsh
