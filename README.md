
# Move Baseline

This is a starting template to build a Move project on Aptos.

## Features

-   Pre-configured Move project structure.
    
-   Ready-to-use Aptos framework integration.
    
-   Example Move modules and scripts.
    
-   Basic tests and deployment scripts.
    

## Prerequisites

Before you begin, ensure you have the following installed:

-   Aptos CLI
    
-   Move CLI
    
-   Rust and Cargo (for building dependencies)
    
-   Node.js (if interacting with the Aptos blockchain using JavaScript)
    

## Installation

Clone the repository:

```
git clone https://github.com/han0495/move-baseline.git
cd move-baseline
```

## Build & Test

Compile the Move modules:

```
aptos move compile
```

Run tests:

```
aptos move test
```

## Deploying to Aptos

To publish your module, you need an Aptos account. First, create a new account:

```
aptos init
```

Then, deploy the Move package:

```
aptos move publish
```

## Contributing

Contributions are welcome! Feel free to fork this repo and submit a pull request.

## License

This project is licensed under the MIT License.
