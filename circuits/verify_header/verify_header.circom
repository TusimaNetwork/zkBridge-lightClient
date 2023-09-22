pragma circom 2.0.2;

include "./header_verification.circom";

component main {public [signing_root]} = VerifyHeader(512, 55, 7);