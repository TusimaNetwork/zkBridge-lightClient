# Overview

1. Update submodules
    ```bash
    git submodule init
    git submodule update
    ```

1. Install dependencies
    ```bash
    npm install
    ```

2. Build circuit `verify_header`
    ```bash
    cd verify_header
    bash run.sh
    ```

1. Build circuit `verify_syncCommittee`
    ```bash
    cd verify_syncCommittee
    bash run.sh
    ```