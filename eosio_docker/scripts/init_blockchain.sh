#!/usr/bin/env bash
set -o errexit

EOSIO_TOKEN_PRIVATE_OWNER_KEY="5J5t5MuUmMgNcrFWiXyeBZEsCfHvgYE7Lec4W2wCaV5SiSoEqQr"
EOSIO_TOKEN_PUBLIC_OWNER_KEY="EOS6P62N6D14ShhUnM7taEQHLTMmS7ohCyfikwAi46U7AT6jmUHyM"

EOSIO_TOKEN_PRIVATE_ACTIVE_KEY="5JhTPDSe9ugHomFnhMgAdzzE2HniuR8rG3SyzzqvQrgJNPC4685"
EOSIO_TOKEN_PUBLIC_ACTIVE_KEY="EOS5X6m7mxcKRsKvHDyCVp1DE5YAy5dEsb5TwFqG4F2xRvRYAAdZx"

SYSTEM_CONTRACTS_DIR="/contracts/"

echo "=== setup blockchain accounts and smart contract ==="

# set PATH
PATH="$PATH:/opt/eosio/bin:/opt/eosio/bin/scripts"


set -m


# start nodeos ( local node of blockchain )
# run it in a background job such that docker run could continue
nodeos -e -p eosio -d /mnt/dev/data \
  --config-dir /mnt/dev/config \
  --http-validate-host=false \
  --plugin eosio::producer_plugin \
  --plugin eosio::chain_api_plugin \
  --plugin eosio::http_plugin \
  --http-server-address=0.0.0.0:8888 \
  --access-control-allow-origin=* \
  --contracts-console \
  --verbose-http-errors &
sleep 1s
until curl localhost:8888/v1/chain/get_info
do
  sleep 1s
done

# Sleep for 2 to allow time 4 blocks to be created so we have blocks to reference when sending transactions
sleep 2s
echo "=== setup wallet: eosiomain ==="
# First key import is for eosio system account
cleos wallet create -n eosiomain --to-console | tail -1 | sed -e 's/^"//' -e 's/"$//' > eosiomain_wallet_password.txt
cleos wallet import -n eosiomain --private-key 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3

echo "=== setup wallet: blogwallet ==="
# key for eosio account and export the generated password to a file for unlocking wallet later
cleos wallet create -n blogwallet --to-console | tail -1 | sed -e 's/^"//' -e 's/"$//' > blog_wallet_password.txt
# Owner key for blogwallet wallet
cleos wallet import -n blogwallet --private-key 5JpWT4ehouB2FF9aCfdfnZ5AwbQbTtHBAwebRXt94FmjyhXwL4K
# Active key for blogwallet wallet
cleos wallet import -n blogwallet --private-key 5JD9AGTuTeD5BXZwGQ5AtwBqHK21aHmYnTetHgk1B3pjj7krT8N

# * Replace "blogwallet" with your own wallet name when you start your own project

echo "=== deploy dapp smart contract ==="
# create account for blogaccount with above wallet's public keys
cleos create account eosio blogaccount EOS6PUh9rs7eddJNzqgqDx1QrspSHLRxLMcRdwHZZRL4tpbtvia5B EOS8BCgapgYA2L4LJfCzekzeSr3rzgSTUXRXwNi8bNRoz31D14en9

# * Replace "blogaccount" with your own account name when you start your own project

# $1 smart contract name 
# $2 account holder name of the smart contract
# $3 wallet that holds the keys for the account
# $4 password for unlocking the wallet
deploy_contract.sh blog blogaccount blogwallet $(cat blog_wallet_password.txt)

echo "=== create user accounts ==="
# script for creating data into blockchain
create_accounts.sh

echo "=== create mock data for contract ==="
# script for calling actions on the smart contract to create mock data
create_mock_data.sh

# * Replace the script with different form of data that you would pushed into the blockchain when you start your own project

echo "=== end of setup blockchain accounts and smart contract ==="
# create a file to indicate the blockchain has been initialized
touch "/mnt/dev/data/initialized"

# put the background nodeos job to foreground for docker run
fg %1
