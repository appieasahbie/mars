#!/bin/bash
echo -e "\033[0;35m"

echo "            ####         ##########  ##########  ####   #########";
echo "           ######        ###    ###  ###    ###  ####   #########";
echo "          ###  ###       ###    ###  ###    ###  ####   ##";
echo "         ##########      ##########  ##########  ####   ######";
echo "        ############     ####        ####        ####   ##";
echo "       ####      ####    ####        ####        ####   #########";
echo "      ####        ####   ####        ####        ####   #########";

echo -e '\e[36mTwitter:\e[39m' https://twitter.com/ABDERRAZAKAKRI3
echo -e '\e[36mGithub: \e[39m' https://github.com/appieasahbie
echo -e "\e[0m"



sleep 2

# Variable
MARS_WALLET=wallet
MARS=marsd
MARS_ID=ares-1
MARS_FOLDER=.mars
MARS_VER=v1.0.0-rc7
MARS_REPO=https://github.com/mars-protocol/hub
MARS_DENOM=umars
MARS_PORT=39

echo "export MARS_WALLET=${MARS_WALLET}" >> $HOME/.bash_profile
echo "export MARS=${MARS}" >> $HOME/.bash_profile
echo "export MARS_ID=${MARS_ID}" >> $HOME/.bash_profile
echo "export MARS_FOLDER=${MARS_FOLDER}" >> $HOME/.bash_profile
echo "export MARS_VER=${MARS_VER}" >> $HOME/.bash_profile
echo "export MARS_REPO=${MARS_REPO}" >> $HOME/.bash_profile
echo "export MARS_DENOM=${MARS_DENOM}" >> $HOME/.bash_profile
echo "export MARS_PORT=${MARS_PORT}" >> $HOME/.bash_profile
source $HOME/.bash_profile

# Set Vars
if [ ! $MARS_NODENAME ]; then
	read -p "sxlzptprjkt@w00t666w00t:~# [ENTER YOUR NODE] > " MARS_NODENAME
	echo 'export MARS_NODENAME='$MARS_NODENAME >> $HOME/.bash_profile
fi
echo ""
echo -e "YOUR NODE NAME : \e[1m\e[31m$MARS_NODENAME\e[0m"
echo -e "NODE CHAIN ID  : \e[1m\e[31m$MARS_ID\e[0m"
echo -e "NODE PORT      : \e[1m\e[31m$MARS_PORT\e[0m"
echo ""

# Update
sudo apt update && sudo apt upgrade -y

# Package
sudo apt install make build-essential gcc git jq chrony -y

# Install GO
ver="1.19.5"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version

# Get testnet version of mars
cd $HOME
rm -rf hub
git clone $MARS_REPO
cd hub
git checkout $MARS_VER
make install
sudo mv $HOME/go/bin/$MARS /usr/bin/

# Create Service
sudo tee /etc/systemd/system/$MARS.service > /dev/null <<EOF
[Unit]
Description=$MARS
After=network-online.target

[Service]
User=$USER
ExecStart=$(which $MARS) start --home $HOME/$MARS_FOLDER
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Register service
sudo systemctl daemon-reload
sudo systemctl enable $MARS

# Init generation
$MARS config chain-id $MARS_ID
$MARS config keyring-backend test
$MARS config node tcp://localhost:${MARS_PORT}657
$MARS init $MARS_NODENAME --chain-id $MARS_ID

# Set peers and seeds
PEERS=$(curl -sS https://testnet-rpc.marsprotocol.io/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | sed -z 's|\n|,|g;s|.$||')
sed -i -e "s|^persistent_peers *=.*|persistent_peers = \"$PEERS\"|" $HOME/$MARS_FOLDER/config/config.toml

# Create file genesis.json
touch $HOME/$MARS_FOLDER/config/genesis.json

# Set Port
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${MARS_PORT}658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${MARS_PORT}657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${MARS_PORT}060\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${MARS_PORT}656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${MARS_PORT}660\"%" $HOME/$MARS_FOLDER/config/config.toml
sed -i.bak -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${MARS_PORT}317\"%; s%^address = \":8080\"%address = \":${MARS_PORT}080\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${MARS_PORT}090\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${MARS_PORT}091\"%" $HOME/$MARS_FOLDER/config/app.toml

# Set Config Pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="50"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/$MARS_FOLDER/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/$MARS_FOLDER/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/$MARS_FOLDER/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/$MARS_FOLDER/config/app.toml

# Set Config prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/$MARS_FOLDER/config/config.toml

# Set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.001$MARS_DENOM\"/" $HOME/$MARS_FOLDER/config/app.toml

# Set config snapshot
sed -i -e "s/^snapshot-interval *=.*/snapshot-interval = \"1000\"/" $HOME/$MARS_FOLDER/config/app.toml
sed -i -e "s/^snapshot-keep-recent *=.*/snapshot-keep-recent = \"2\"/" $HOME/$MARS_FOLDER/config/app.toml

# Enable state sync
$MARS tendermint unsafe-reset-all --home $HOME/$MARS_FOLDER

SNAP_RPC="https://testnet-rpc.marsprotocol.io:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo ""
echo -e "\e[1m\e[31m[!]\e[0m HEIGHT : \e[1m\e[31m$LATEST_HEIGHT\e[0m BLOCK : \e[1m\e[31m$BLOCK_HEIGHT\e[0m HASH : \e[1m\e[31m$TRUST_HASH\e[0m"
echo ""

sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/$MARS_FOLDER/config/config.toml

# Enable wasm
curl -o - -L https://anode.team/Mars/test/anode.team_mars_wasm.tar.lz4 | lz4 -c -d - | tar -x -C $HOME/$MARS_FOLDER/data

# Start Service
sudo systemctl start $MARS

echo -e "\e[1m\e[31mSETUP FINISHED\e[0m"
echo -e "\e[1m\e[31m[!]\e[0m STATE SYNC ESTIMATION CAN TAKE 1-5 MINS PLEASE WAITTING"
echo ""
echo -e "CHECK RUNNING LOGS : \e[1m\e[31mjournalctl -fu $MARS -o cat\e[0m"
echo -e "CHECK LOCAL STATUS : \e[1m\e[31mcurl -s localhost:${MARS_PORT}657/status | jq .result.sync_info\e[0m"
echo ""

# End
