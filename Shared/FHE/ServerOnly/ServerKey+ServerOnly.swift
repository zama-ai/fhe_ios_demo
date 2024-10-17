// Copyright © 2024 Zama. All rights reserved.

import TFHE

extension ServerKey {
    func setServerKey() {
        set_server_key(pointer)
    }
}
