require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-truffle5");
require("solidity-coverage");

module.exports = {
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.8.6",
            },
            // {
            //     version: "0.6.12",
            // },
            {
                version: "0.5.16",
            },
            {
                version: "0.6.6",
            }
        ],
        overrides: {
            "contracts/mdex/MdexFactory.sol": {
                version: "0.5.16",
            },
            "contracts/mdex/MdexRouter.sol": {
                version: "0.6.6",
            }
        },
        settings: {
            optimizer: {
                enabled: true,
                runs: 999999
            }
        }
    },
};