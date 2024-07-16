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
    
    echo ""
    echo -e "\e[32mLoggin Back in...."
    echo -e "\e[39m"
    sudo -i -u $(whoami)
    
    
    
    
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
v2ray_listen_port=$(awk -F= '/^.*listen_port/{gsub(/ /,"",$2);print $2}' ${HOME}/.sentinelnode/v2ray.toml)

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
echo -e "\e[32mDo you want to host a v2ray node? [y = v2ray | n = wireguard]\e[m"
read v2ray_input </dev/tty
if [[ $v2ray_input == "Y" || $v2ray_input == "y" || $v2ray_input == "yes" || $v2ray_input == "Yes" || $v2ray_input == "zes" || $v2ray_input == "Zes" || $v2ray_input == "z" || $v2ray_input == "Z" ]]; then
    echo ""
    echo -e "\e[32mV2ray applied\e[m"
    awk '/enable/ {$NF="false"} /type/ {$NF="\"v2ray\""} 1' ~/.sentinelnode/config.toml > temp && mv temp ~/.sentinelnode/config.toml
else
    echo ""
    echo "Wireguard applied"
fi


echo ""
echo -e "\e[32mAre you hosting a residential node [y,n]\e[m"
read residential_input </dev/tty
if [[ $residential_input == "Y" || $residential_input == "y" || $residential_input == "yes" || $residential_input == "Yes" || $residential_input == "zes" || $residential_input == "Zes" || $residential_input == "z" || $residential_input == "Z" ]]; then
    echo ""    
    awk '/hourly_prices/ {$0="hourly_prices = \"18550ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,800ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,385600ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,4340ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,10000000udvpn\""} 1' ~/.sentinelnode/config.toml > temp && mv temp ~/.sentinelnode/config.toml
    awk '/gigabyte_prices/ {$0="gigabyte_prices = \"52573ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,9204ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1180852ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,122740ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15342624udvpn\""} 1' ~/.sentinelnode/config.toml > temp && mv temp ~/.sentinelnode/config.toml
    echo -e "\e[32mResidential...\e[m"
else
    echo ""
    awk '/hourly_prices/ {$0="hourly_prices = \"18550ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,800ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,385600ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,4340ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,4160000udvpn\""} 1' ~/.sentinelnode/config.toml > temp && mv temp ~/.sentinelnode/config.toml
    awk '/gigabyte_prices/ {$0="gigabyte_prices = \"52573ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,9204ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1180852ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,122740ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15342624udvpn\""} 1' ~/.sentinelnode/config.toml > temp && mv temp ~/.sentinelnode/config.toml
    echo -e "\e[32mCloud...\e[m"
fi


echo ""
echo -e "\e[32mDo you want to import an existing wallet of yours? [y,n]\e[m"
read input </dev/tty
if [[ $input == "Y" || $input == "y" || $input == "yes" || $input == "Yes" || $input == "zes" || $input == "Zes" || $input == "z" || $input == "Z" ]]; then
    echo ""
    echo -e "\e[32mOk, import/recover your key after the script is finished with the following lines. Use the same keyname you enter in the next prompt\e[m"
    echo ""
    echo "docker run --rm \\"
    echo "    --interactive \\"
    echo "    --tty \\"
    echo "    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \\"
    echo -e "    sentinel-dvpn-node process keys add \e[32m\$keyname\e[m \e[35m--recover\e[m"
    sleep 5
    echo ""
    echo -e "\e[32mEnter your key name:\e[m" 
    read key_temp </dev/tty
else
    echo ""
    echo -e "\e[32mEnter your key name:\e[m" 
    read key_temp </dev/tty
fi


moniker=\"${moniker_temp}\"

key=\"${key_temp}\"

backend_temp=test
backend=\"${backend_temp}\"

sed -i -e "s/\(moniker *= *\).*/\1$moniker/" ${HOME}/.sentinelnode/config.toml

sed -i -e "s/\(from *= *\).*/\1$key/" ${HOME}/.sentinelnode/config.toml

sed -i -e "s/\(backend *= *\).*/\1$backend/" ${HOME}/.sentinelnode/config.toml

awk '/rpc_addresses/ {$0="rpc_addresses = \"https://rpc.sentinel.quokkastake.io:443,https://rpc.mathnodes.com:443,https://sentinel-rpc.badgerbite.io:443,https://sentinel-rpc.publicnode.com:443\""} 1' ~/.sentinelnode/config.toml > temp && mv temp ~/.sentinelnode/config.toml

sleep 5 

#''''''''''''keys && seeds && farwell''''''''''''''''''''''''''''


key=${key_temp}


if [[ $input == "Y" || $input == "y" || $input == "yes" || $input == "Yes" || $input == "zes" || $input == "Zes" || $input == "z" || $input == "Z" ]]; then
        echo ""

else
seed=$(docker run --rm \
    --tty \
    --volume ${HOME}/.sentinelnode:/root/.sentinelnode \
    sentinel-dvpn-node process keys add $key)
    
echo "$seed" > output.txt


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


#echo -e "\e[32mYour wallet and node addresses are:\e[m"
#echo ""
#echo $wallet
#echo ""
echo ""
echo -e "\e[32mYour seedphrase, node/wallet address is:\e[m"
echo ""
cat output.txt

echo -e 
echo -e "\e[31m -----------SAVE BOTH------------ \e[m"
echo -e 

echo ""
echo -e "\e[32mTo start your node use the following command (Wireguard/V2Ray):\e[m"
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
echo ""
echo ""
echo "sudo docker run -d \\"
echo "    --name sentinel-dvpn-node \\"
echo "    --restart unless-stopped \\"
echo "    --volume "${HOME}/.sentinelnode:/root/.sentinelnode" \\"
echo "    --publish ${api_listen_port}:${api_listen_port}/tcp \\"
echo "    --publish ${v2ray_listen_port}:${v2ray_listen_port}/tcp \\"
echo "    sentinel-dvpn-node process start"

rm output.txt


}
run
