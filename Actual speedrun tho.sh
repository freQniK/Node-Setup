#!/bin/bash


run () {

    echo -e "\e[32mUpdate the list of available software packages"
    echo -e "\e[39m"
    sudo apt-get update

    echo ""
    echo -e "\e[32mInstall cURL package"
    echo -e "\e[39m"
    sudo apt-get install --yes curl
    
    echo ""
    echo -e "\e[32mGet the official Docker installation script"
    echo -e "\e[39m"
    curl -fsSL get.docker.com -o ${HOME}/get-docker.sh
    
    echo ""
    echo -e "\e[32mInstall Docker" 
    echo -e "\e[39m"
    sudo sh ${HOME}/get-docker.sh
    
    echo ""
    echo -e "\e[32mAdd user to Docker group" 
    echo -e "\e[39m"
    sudo usermod -aG docker $(whoami)


    echo ""
    echo -e "\e[32mAdding...."
    echo -e "\e[39m"
    newgrp docker
    
    
    
#    us=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
#    uss=( $us )
#    numb=$(echo -n "$us" | wc -w)
#    var=0
#    
#    while (( $var < $numb))
#    do
#        
#    echo ""
#    echo -e "\e[32mAdd user to Docker group" 
#    echo -e "\e[39m"
#    sudo usermod -aG docker ${uss[$var]}
#
#
#    echo ""
#    echo -e "\e[32mAdding...."
#    echo -e "\e[39m"
#    newgrp docker ${uss[$var]}
#    
#    var=$((var+1))
#    done
 

#''''''''''''INSTALL DOCKER AND STUFF''''''''''''''''''''''''''''

    
    echo -e "\e[32mEnable IPv6 support for Docker"
    echo -e "\e[39m"
    echo '{
    "ipv6": true,
    "fixed-cidr-v6": "2001:db8:1::/64"
}' | sudo tee -a /etc/docker/daemon.json

    echo ""
    echo -e "\e[32mRestart the Docker process"
    echo -e "\e[39m"
    sudo systemctl restart docker
    
    
    sudo mkdir /etc/iptables/
    echo ""
    echo -e "\e[32mInstall iptables-persistent package"
    echo -e "\e[39m"
    sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install iptables-persistent
    sudo rm /etc/iptables/rules.v4
    sleep 2
    sudo rm /etc/iptables/rules.v6
    sleep 2

    echo ""
    echo -e "\e[32mEnable NAT for the private Docker subnet on the host" 
    echo -e "\e[39m"
    rule=(POSTROUTING -s 2001:db8:1::/64 ! -o docker0 -j MASQUERADE) && \
sudo ip6tables -t nat -C "${rule[@]}" 2>/dev/null || \
sudo ip6tables -t nat -A "${rule[@]}" && \
sudo ip6tables-save >/etc/iptables/rules.v6

#     rule="POSTROUTING -s 2001:db8:1::/64 ! -o docker0 -j MASQUERADE" && \
# sudo ip6tables -t nat -C ${rule} || \
# sudo ip6tables -t nat -A ${rule} && \
# sudo sh -c "ip6tables-save > /etc/iptables/rules.v6"

    echo ""
    echo -e "\e[32mInstall Git package" 
    echo -e "\e[39m"
    sudo apt-get install --yes git

    echo ""
    echo -e "\e[32mClone the GitHub repository"
    echo -e "\e[39m"
    git clone https://github.com/sentinel-official/dvpn-node.git \
    ${HOME}/dvpn-node/

    echo ""
    echo -e "\e[32mChange the working directory and checkout to the latest tag"
    echo -e "\e[39m"
    cd ${HOME}/dvpn-node/ && \
commit=$(git rev-list --tags --max-count=1) && \
git checkout $(git describe --tags ${commit})

    echo ""
    echo -e "\e[32mBuild the image"
    echo -e "\e[39m"
    docker build --file Dockerfile \
    --tag sentinel-dvpn-node \
    --force-rm \
    --no-cache \
    --compress .

    echo ""
    echo -e "\e[32mInstall openssl package"
    echo -e "\e[39m"
    sudo apt-get install --yes openssl


    echo ""
    echo -e "\e[32mInitialize the application configuration"
    echo -e "\e[39m"
    docker run --rm \
    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \
    sentinel-dvpn-node process config init


    echo ""
    echo -e "\e[32mInitialize the wireguard configuration"
    echo -e "\e[39m"
    docker run --rm \
    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \
    sentinel-dvpn-node process wireguard config init
    
    
    echo ""
    echo -e "\e[32mInitialize the v2ray configuration"
    echo -e "\e[39m"    
    docker run --rm \
    --volume "${HOME}/.sentinelnode:/root/.sentinelnode" \
    sentinel-dvpn-node process v2ray config init



    #''''''''''''CERTIFICATE STUFF''''''''''''''''''''''''''''


    echo ""
    echo -e "\e[32mCreate a self-signed TLS certificate"
    echo -e "\e[39m"
    yes "" | sudo openssl req -new \
  -newkey ec \
  -pkeyopt ec_paramgen_curve:prime256v1 \
  -x509 \
  -sha256 \
  -days 365 \
  -nodes \
  -out ${HOME}/tls.crt \
  -keyout ${HOME}/tls.key
  echo ""

sleep 5

  echo ""
    echo -e "\e[32mMove created TLS keys"
    echo -e "\e[39m"
    mv ${HOME}/tls.crt ${HOME}/.sentinelnode/tls.crt
mv ${HOME}/tls.key ${HOME}/.sentinelnode/tls.key

sudo chown root:root "${HOME}/.sentinelnode/tls.crt" && \
sudo chown root:root "${HOME}/.sentinelnode/tls.key"
echo ""
echo ""
sleep 5    



#''''''''''''get ports && add remote url''''''''''''''''''''''''''''

wireguard_listen_port=$(awk -F= '/^.*listen_port/{gsub(/ /,"",$2);print $2}' ${HOME}/.sentinelnode/wireguard.toml)

api_listen_port=$(awk -F= '/^.*listen_on/{gsub(/ /,"",$2);print $2}' ${HOME}/.sentinelnode/config.toml)

api=${api_listen_port: 9}
api_listen_port=${api%?}

ip=`wget -q -O - checkip.dyndns.org|sed -e 's/.*Current IP Address: //' -e 's/<.*$//'`
http=https://
remote_url_temp="${http}${ip}:${api_listen_port}"
remote_url=\"${remote_url_temp}\"


sed -i -e "s%\(remote_url *= *\).*%\1$remote_url%" ${HOME}/.sentinelnode/config.toml

sleep 5

#''''''''''''ask for moniker && key name && price && test''''''''''''''''''''''''''''

echo ""
echo -e "\e[32mEnter node Moniker (the name your node is shown as) (4 letters or more):\e[m" 
read moniker_temp </dev/tty

echo ""
echo -e "\e[32mEnter the gigabyte price you want to charge in ___udvpn (1dvpn=1000000udvpn) (udvpn at the end):\e[m" 
read gigabyte_prices_temp </dev/tty

echo ""
echo -e "\e[32mEnter the hourly price you want to charge in ___udvpn (1dvpn=1000000udvpn) (udvpn at the end):\e[m" 
read hourly_prices_temp </dev/tty




echo -e "\e[32mDo you want to import an existing wallet of yours? [y,n]\e[m"
read input </dev/tty
if [[ $input == "Y" || $input == "y" || $input == "yes" || $input == "Yes" || $input == "zes" || $input == "Zes" || $input == "z" || $input == "Z" ]]; then
        echo ""
        echo -e "\e[32mOk, import your key after the script is finished and use the same keyname you enter in the next prompt\e[m"
sleep 10
echo ""
echo -e "\e[32mEnter your key name:\e[m" 
read key_temp </dev/tty

else
echo ""
echo -e "\e[32mEnter your key name:\e[m" 
read key_temp </dev/tty
fi




#echo ""
#echo -e "\e[32mEnter your key name:\e[m" 
#read key_temp </dev/tty



moniker=\"${moniker_temp}\"

gigabyte_prices=\"${gigabyte_prices_temp}\"

hourly_prices=\"${hourly_prices_temp}\"

key=\"${key_temp}\"

backend_temp=test
backend=\"${backend_temp}\"

sed -i -e "s/\(moniker *= *\).*/\1$moniker/" ${HOME}/.sentinelnode/config.toml

#sed -i -e "s/\(gigabyte_prices *= *\).*/\1$gigabyte_prices/" ${HOME}/.sentinelnode/config.toml
awk -v prices="$gigabyte_prices" '{gsub(/gigabyte_prices *= *\".*\"/, "gigabyte_prices = " prices)}1' ${HOME}/.sentinelnode/config.toml > temp && mv temp ${HOME}/.sentinelnode/config.toml



#sed -i -e "s/\(hourly_prices *= *\).*/\1$hourly_prices/" ${HOME}/.sentinelnode/config.toml
awk -v prices="$hourly_prices" '{gsub(/hourly_prices *= *\".*\"/, "hourly_prices = " prices)}1' ${HOME}/.sentinelnode/config.toml > temp && mv temp ${HOME}/.sentinelnode/config.toml



sed -i -e "s/\(from *= *\).*/\1$key/" ${HOME}/.sentinelnode/config.toml

sed -i -e "s/\(backend *= *\).*/\1$backend/" ${HOME}/.sentinelnode/config.toml


#''''''''''''keys && seeds && farwell''''''''''''''''''''''''''''


key=${key_temp}


if [[ $input == "Y" || $input == "y" || $input == "yes" || $input == "Yes" || $input == "zes" || $input == "Zes" || $input == "z" || $input == "Z" ]]; then
        echo ""

else
seed=$(docker run --rm \
    --tty \
    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \
    sentinel-dvpn-node process keys add $key)


wallet=$(docker run --rm \
    --tty \
    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \
    sentinel-dvpn-node process keys list private)
fi


#seed=$(docker run --rm \
#    --tty \
#    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \
#    sentinel-dvpn-node process keys add $key)


#wallet=$(docker run --rm \
#    --tty \
#    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \
#    sentinel-dvpn-node process keys list private)


echo -e "\e[32mYour wallet and node addresses are:\e[m"
echo ""
echo $wallet
echo ""
echo ""
echo -e "\e[32mYour seedphrase is:\e[m"
echo ""
echo $seed

echo -e 
echo -e "\e[31m -----------SAVE BOTH------------ \e[m"
echo -e 

echo ""
echo -e "\e[32mTo start your node use the following command (maybe use tmux or screen):\e[m"
echo ""
echo "sudo docker run -d \\"
echo "    --name sentinel-dvpn-node \\"
echo "    --restart unless-stopped \\"
echo "    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \\"
echo "    --volume /lib/modules:/lib/modules \\"
echo "    --cap-drop ALL \\"
echo "    --cap-add NET_ADMIN \\"
echo "    --cap-add NET_BIND_SERVICE \\"
echo "    --cap-add NET_RAW \\"
echo "    --cap-add SYS_MODULE \\"
echo "    --sysctl net.ipv4.ip_forward=1 \\"
echo "    --sysctl net.ipv6.conf.all.disable_ipv6=0 \\"
echo "    --sysctl net.ipv6.conf.all.forwarding=1 \\"
echo "    --sysctl net.ipv6.conf.default.forwarding=1 \\"
echo "    --publish ${api_listen_port}:${api_listen_port}/tcp \\"
echo "    --publish ${wireguard_listen_port}:${wireguard_listen_port}/udp \\"
echo "    sentinel-dvpn-node process start"



}
run
