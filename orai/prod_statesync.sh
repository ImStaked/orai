# PRINT EVERY COMMAND
set -ux

CHAIN_ID="Oraichain"
SNAP_RPC2="https://rpc-oraichain.vchain.zone:443"
SNAP_RPC1="http://64.225.53.108:26657"
SNAP_RPC="https://rpc.orai.io:443"
TRUST_HEIGHT_RANGE=${TRUST_HEIGHT_RANGE:-10}
STATESYNC_APP_TOML=$HOME/.oraid/config/app.toml
STATESYNC_CONFIG=$HOME/.oraid/config/config.toml
GAS_PRICE="0.00001orai"
PEERS="eb2a6ac0f4d21456573941fd8a12c1b415ad5372@159.203.175.30:26656,efb9d22a6fdf7460f965982ae013d242bbbfd53c@65.108.232.168:33656,0baa806b3a4dd17be6e06369d899f140c3897d6e@18.223.242.70:26656,9749da4a81526266d7b8fe9a03d260cd3db241ad@18.116.209.76:26656,35c1f999d67de56736b412a1325370a8e2fdb34a@5.189.169.99:26656,5ad3b29bf56b9ba95c67f282aa281b6f0903e921@64.225.53.108:26656,d091cabe3584cb32043cc0c9199b0c7a5b68ddcb@seed.orai.synergynodes.com:26656,c14df7b2e097d743aa7574c7cf65397a06ea3833@peer-oraichain.mms.team:56103,90b5535a5ccdb89260f7b6bdb4125c1af63f5eba@194.146.12.212:26656,70a2b4a48b6109450eeb27c4a5f90350167e000e@92.119.112.118:26656,4bd1653082db72f7fca70aeb41658659e2d82dea@3.135.247.52:26656,d4535a724a45ee78d127a28b533eb314f24c9cc1@194.163.173.26:26656,18adec16898843884cf891e828a7a0406575c3e1@173.249.30.171:26656"
SEEDS="0baa806b3a4dd17be6e06369d899f140c3897d6e@18.223.242.70:26656,9749da4a81526266d7b8fe9a03d260cd3db241ad@18.116.209.76:26656,35c1f999d67de56736b412a1325370a8e2fdb34a@5.189.169.99:26656,5ad3b29bf56b9ba95c67f282aa281b6f0903e921@64.225.53.108:26656,d091cabe3584cb32043cc0c9199b0c7a5b68ddcb@seed.orai.synergynodes.com:26656,f223f1be06ef35a6dfe54995f05daeb1897d94d7@seed-node.mms.team:42656"


# Set your Moniker and initialize the node
echo "Please enter the node moniker"; read MONIKER && oraid init "$MONIKER" --chain-id="$CHAIN_ID" --home $HOME/.oraid

# GET GENESIS
wget -O "$HOME"/.oraid/config/genesis.json https://raw.githubusercontent.com/oraichain/oraichain-static-files/master/genesis.json

# GET TRUST HASH AND TRUST HEIGHT
LATEST_HEIGHT=$(curl -s "$SNAP_RPC"/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - $TRUST_HEIGHT_RANGE)); \
TRUST_HASH=$(curl -s "$SNAP_RPC"/block?height="$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

# Change network settings
# Admin
#sed -i -E 's|tcp://0.0.0.0:1317|tcp://0.0.0.0:1350|g' $STATESYNC_APP_TOML
# GRPC
#sed -i -E 's|0.0.0.0:9090|0.0.0.0:9080|g' $STATESYNC_APP_TOML
# GRPC Web
#sed -i -E 's|0.0.0.0:9091|0.0.0.0:9081|g' $STATESYNC_APP_TOML
# Address of the ABCI application
#sed -i -E 's|tcp://127.0.0.1:26658|tcp://0.0.0.0:26648|g' $STATESYNC_CONFIG
# RPC
#sed -i -E 's|tcp://127.0.0.1:26657|tcp://0.0.0.0:26647|g' $STATESYNC_CONFIG
# P2P
#sed -i -E 's|tcp://0.0.0.0:26656|tcp://0.0.0.0:26643|g' $STATESYNC_CONFIG
# Prometheus
#sed -i -E 's|0.0.0.0:26660|0.0.0.0:26640|g' $STATESYNC_CONFIG
# pprof listen address
#sed -i -E 's|localhost:6060|localhost:6070|g' $STATESYNC_CONFIG


# Set minimum gas price
sed -i.bak -E "s|^(minimum-gas-prices[[:space:]]+=[[:space:]]+).*$|\1\"$GAS_PRICE"| $STATESYNC_APP_TOML

# Change config files (set the node name, add persistent peers, set indexer = "null")
sed -i -e "s%^indexer *=.*%indexer = \"null\"%; " $STATESYNC_CONFIG
# GET TRUST HASH AND TRUST HEIGHT
LATEST_HEIGHT=$(curl -s "$SNAP_RPC"/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - $TRUST_HEIGHT_RANGE)); \
TRUST_HASH=$(curl -s "$SNAP_RPC"/block?height="$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
# TELL USER WHAT WE ARE DOING
echo "LATEST HEIGHT: $LATEST_HEIGHT"
echo "TRUST HEIGHT: $BLOCK_HEIGHT"
echo "TRUST HASH: $TRUST_HASH"
echo -e "\n Updating the config file with above values"

sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC1,$SNAP_RPC2\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
s|^(persistent_peers[[:space:]]+=[[:space:]]+).*$|\1\"$PEERS\"| ; \
s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"$SEEDS\"|" $STATESYNC_CONFIG

# Start the node
echo "\n Starting state sync now"
sudo systemctl enable oraivisor
sudo systemctl start oraivisor

echo "Waiting 10 seconds before verifying the node is syncing"
sleep 10

CATCHUP=$(curl -s 127.0.0.1:26657/status | jq .result.sync_info.catching_up)
PEER_ID=$(curl -s http://127.0.0.1:26657/status | jq -r '.result.node_info.id')
ORAI_STATUS=$(systemctl status oraivisor | grep running)

if [ -z "$ORAI_STATUS" ]; then
  echo "A problem has been detected. Exiting"
else
  echo "The node appears to be working now"
  echo "The node peer id is $PEER_ID "
fi

if [ "$CATCHUP" = false ]; then
  echo "The nodes sync status is caught up"
else
  echo "The nodes sync status is catching up"
fi
