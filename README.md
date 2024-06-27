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
    - Omnicat.estimateSendFee
    - 0x0001000000000000000000000000000000000000000000000000000000000020ce70 (for 2150000)
    - 0x00010000000000000000000000000000000000000000000000000000000000118c30 (for 1150000)
    - 0x000100000000000000000000000000000000000000000000000000000000000927c0 (for 600000)
    - 0x0001000000000000000000000000000000000000000000000000000000000007a120 (for 500000)
    - 0x00010000000000000000000000000000000000000000000000000000000000061a80 (for 400000)
    - 0x00010000000000000000000000000000000000000000000000000000000000055730 (for 350000)
    - 0x0001000000000000000000000000000000000000000000000000000000000003d090 (for 250000)
    - 0x00010000000000000000000000000000000000000000000000000000000000030d40 (for 200000)
    - 0x000100000000000000000000000000000000000000000000000000000000000f4240
0000000000000000000000000000000000000000000000000000000000030d40

0x0000000000000000000000000000000000000000

2e5+15e4+2.1e5


# Steps to deploy
- first set up your `.nftConfig` -> this has the nfts configuration.
- make sure your private key `.privateKey` is set, and the `.deploy` file is set for all the chains.
- the .deploy should have OMNI_BRIDGE_FEE set for each chain.
- run deployNFTA.sh from your command line.

- add the deployed address to `.baseChainConfig` and to `.chainAddresses`. Set any chains you wont deploy to be zero address in `.chainAddresses` as well.

- run deployNFT.sh for all the chains you want to deploy.
- add each contract address to the `.chainAddresses` file.

- run `configureNFTAParams.sh`. and all the other `configureNFTParams.sh` as well.