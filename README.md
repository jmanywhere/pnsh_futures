Uses Foundry,
Installation: `forge install`
Build: `forge build`
Deploy: If not testing, be sure to (1) comment out the deployment of the test pnsh and test tokens in DeployFutures.s.sol and (2) check the contract addresses for the constants at the top of the script.

The below `forge script` command will deploy the smart contract ecosystem. Use the proper $RPC_URL and $ETHERSCAN_KEY (bscscan key) for the network you are deploying to, and the $PRIVATE_KEY that will administer the contracts. It will take some time to run as it simulates the transactions locally first.

`
forge script script/DeployFutures.s.sol:DeployFutures --broadcast --verify -vvv \
 --rpc-url $RPC_URL \
 --etherscan-api-key $ETHERSCAN_KEY
 --private-key $PRIVATE_KEY
 `
