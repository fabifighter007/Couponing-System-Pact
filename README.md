
# Prototype Voucher System in Pact

Globally deployable blockchain-based couponing system written in the Pact smart contract language.
## Use Pre-Built VM


A pre-built test environment is available [here](www.google.com). All unit tests and formal verification can be performed here. Please import the VM to [Oracle Virtual Box](https://www.virtualbox.org/).

The VM comes with a funded Wallet for interacting with the Smart Contract on the public testnet and is able to run the Smart Contract locally.
## Use Chainweaver
You can interact with the Smart Contract by using [Chainweaver Web Wallet](https://chainweaver.kadena.network). Create a wallet and fund it with Coins using the [Testnet-Faucet](https://faucet.testnet.chainweb.com/). Within your wallet, navigate to *Contracts*, press *Module Explorer* and search for `free.deploy-test-couponsystem`. You can call all functions, feel free to test them.

```bash
Network: testnet04
Chain: 1
Smart Contract: free.deploy-test-couponsystem
API: https://api.testnet.chainweb.com/chainweb/0.0/testnet04/chain/1/pact/api/v1/
```
## Run Locally
### Install Pact
Install [Pact](https://github.com/kadena-io/pact/wiki/Building-Kadena-Projects) by using Nix.

Go to the bin directory
```bash
  cd /bin
```

Create pact command
```bash
  nano pact
```

Create a file named *pact* in */bin*

Example:
```bash
#!/bin/bash

~/Pact/pact-4.2.1/result/bin/pact $@
```
Test by issuing `pact` in a terminal or by executing your binary. Try out some commands:

```
$ pact
pact> (+ 1 2)
3
pact> (+ "hello, " "world")
"hello, world"
```
### Interact with the Smart Contract

Clone the project

```bash
  git clone https://link-to-project
```

Go to the project directory

```bash
  cd my-project
```

Start Pact

```bash
  pact
```

Load the REPL
```bash
  (load "coupon.repl" true)
```
## License

[MIT](https://choosealicense.com/licenses/apache-2.0/)


## Contact

If you have any questions, please send me an email to fabedh@protonmail.com.
