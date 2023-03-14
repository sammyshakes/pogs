test deploy ``forge script script/Deploy.s.sol:Deploy --rpc-url goerli``

deploy on goerli ``forge script script/Deploy.s.sol:Deploy --rpc-url goerli --broadcast``

verify contract ``forge verify-contract --chain-id 5 --num-of-optimizations 200 --watch <address> src/Pogs.sol:Pogs $ETHERSCAN_API --compiler-version 0.8.17``