clear

echo "
     __    .___         ___.                         
    |__| __| _/         \_ |__ _____    ______ ____  
    |  |/ __ |   ______  | __ \\__  \  /  ___// __ \ 
    |  / /_/ |  /_____/  | \_\ \/ __ \_\___ \\  ___/ 
/\__|  \____ |           |___  (____  /____  >\___  >
\______|    \/               \/     \/     \/     \/
                                                                                                  
"

DOCKER_IMG_NAME="nevinee/jd"
JD_PATH=""
SHELL_FOLDER=$(pwd)
CONTAINER_NAME=""
CONFIG_PATH=""
LOG_PATH=""
TAG="v4-bot"

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
}

docker_install
warn "注意如果你什么都不清楚，建议所有选项都直接回车，使用默认选择！！！"
#配置文件目录
echo -n -e "\e[33m一.请输入配置文件保存的绝对路径,直接回车为当前目录:\e[0m"
read jd_path
JD_PATH=$jd_path
if [ -z "$jd_path" ]; then
    JD_PATH=$SHELL_FOLDER
fi
CONFIG_PATH=/home/$JD_PATH/config
LOG_PATH=/home/$JD_PATH/log

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

exho "请登录docker"
docker login


#配置已经创建完成，开始执行

log "1.开始创建配置文件目录"
mkdir -p $CONFIG_PATH
mkdir -p $LOG_PATH


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
    -v $CONFIG_PATH:/jd/config \
    -v $LOG_PATH:/jd/log \
    --name $CONTAINER_NAME \
    --hostname $CONTAINER_NAME \
    -e ENABLE_TG_BOT=true \
    -e ENABLE_WEB_PANEL=true \
    -p 1234:5678 \
    --restart always \
    --network bridge \
    $DOCKER_IMG_NAME:$TAG


if [ $INSTALL_WATCH = true ]; then
    log "3.1.开始创建容器并执行"
    docker run -d \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower
fi

log "4.下面列出所有容器"
docker ps

log "5.安装已经完成。"

echo "安装zsh"
echo y|sudo apt-get install zsh

echo "安装ohmyzsh"
echo y|sh -c "$(wget -O- https://gitee.com/shmhlsy/oh-my-zsh-install.sh/raw/master/install.sh)"
echo "ohmyzsh安装完成"

echo "安装zsh-auto"
git clone https://gitee.com/han8gui/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
echo "完成"

sed -i 's/plugins=(git/plugins=(git zsh-autosuggestions /g' ~/.zshrc
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="random"/g' ~/.zshrc
sed -i "15i alias i+sen='sudo chattr +i /var/lib/docker/overlay2/jdthlj/merged/jd/scripts/sendNotify.js '" ~/.zshrc
sed -i "15i alias i-sen='sudo chattr -i /var/lib/docker/overlay2/jdthlj/merged/jd/scripts/sendNotify.js '" ~/.zshrc
sed -i "15i alias cdjd='cd /var/lib/docker/overlay2/jdthlj/merged/jd'" ~/.zshrc
sed -i "15i alias cdjdscripts='cd /var/lib/docker/overlay2/jdthlj/merged/jd/scripts'" ~/.zshrc
sed -i "15i alias jup='docker exec -it jdthrq jup'" ~/.zshrc
sed -i "15i alias i+jshare='sudo chattr +i /var/lib/docker/overlay2/jdthlj/merged/jd/jshare.sh'" ~/.zshrc
sed -i "15i alias i-jshare='sudo chattr -i /var/lib/docker/overlay2/jdthlj/merged/jd/jshare.sh'" ~/.zshrc
sed -i "15i alias mb='docker exec -it jdthrq pm2 start /jd/panel/server.js'" ~/.zshrc
sed -i "15i alias hby='UpMachine(){ docker exec -it jdthrq bash /jd/hby.sh $1;};UpMachine'" ~/.zshrc
sed -i 's/jdthlj/"$jdthlj"/g' ~/.zshrc
sed -i 's/jdthrq/"$jdthrq"/g' ~/.zshrc
sed -i "15i  export jdthlj=" ~/.zshrc
sed -i "15i  export jdthrq=" ~/.zshrc

source ~/.zshrc
echo "配置zsh-auto完成"

echo "自行下载红包雨wget -P /var/lib/docker/overlay2/$jdthlj/merged/jd https://ghproxy.com/https://raw.githubusercontent.com/LCX149/8001zy/main/hby.sh"

