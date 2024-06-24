# omnicat-NFT

Steps to keep in mind while deploying - 

- deploy omniNFTA
- set mindstgas for 0 and 1 on omniNFTA for all future contracts.
- setTrustedRemoteAddress
- setDstChainIdToBatchLimit
- 

- deploy omniNFT
- set mindstgas for 0 and 1 on omniNFTA for all future contracts.
- setTrustedRemoteAddress
- setDstChainIdToBatchLimit
- setOmniBridgeFee


# Steps to deploy
- first set up your `.nftConfig` -> this has the nfts configuration.
- make sure your private key `.privateKey` is set, and the `.deploy` file is set for all the chains.
- run deployNFTA.sh from your command line.

- add the deployed address to `.baseChainConfig` and to `.chainAddresses`. Set any chains you wont deploy to be zero address in `.chainAddresses` as well.

- run deployNFT.sh for all the chains you want to deploy.
- add each contract address to the `.chainAddresses` file.

- run `configureNFTAParams.sh`. and all the other `configureNFTParams.sh` as well.