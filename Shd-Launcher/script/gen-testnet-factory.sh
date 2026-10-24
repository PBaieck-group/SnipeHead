#!/usr/bin/env bash
# Generates src/testnet/SHDLaunchFactoryTestnet.sol from the production factory.
# Only difference: SHD / BUY_AND_BURN / FACTORY become constructor-set immutables
# (the mainnet addresses don't exist on testnet). All logic is byte-for-byte the same source.
# Re-run this whenever src/SHDLaunchFactory.sol changes.
set -euo pipefail
SRC="src/SHDLaunchFactory.sol"
OUT="src/testnet/SHDLaunchFactoryTestnet.sol"
mkdir -p src/testnet

sed -E \
  -e 's#^import \{LaunchToken, TokenMetadata\} from "\./SnipeLaunchToken\.sol";#import {LaunchToken, TokenMetadata} from "../SnipeLaunchToken.sol";#' \
  -e 's#^contract SHDLaunchFactory \{#contract SHDLaunchFactoryTestnet {#' \
  -e 's#^( *)IERC20 public constant SHD = IERC20\(0x[0-9a-fA-F]{40}\);#\1IERC20 public immutable SHD;#' \
  -e 's#^( *)address public constant BUY_AND_BURN = 0x[0-9a-fA-F]{40};#\1address public immutable BUY_AND_BURN;#' \
  -e 's#^( *)IPulseXFactory public constant FACTORY = IPulseXFactory\(0x[0-9a-fA-F]{40}\);#\1IPulseXFactory public immutable FACTORY;#' \
  "$SRC" \
| awk '
  { print }
  /uint256 public constant TOKEN_SUPPLY/ {
    print ""
    print "    /// @dev TESTNET ONLY: addresses injected at deploy time instead of hardcoded mainnet constants."
    print "    constructor(address shd_, address buyAndBurn_, address v2Factory_) {"
    print "        require(shd_ != address(0) && buyAndBurn_ != address(0) && v2Factory_ != address(0), \"zero address\");"
    print "        SHD = IERC20(shd_);"
    print "        BUY_AND_BURN = buyAndBurn_;"
    print "        FACTORY = IPulseXFactory(v2Factory_);"
    print "    }"
  }' > "$OUT"

# sanity: no mainnet addresses may remain
if grep -qiE '0xB95bC84f|0x3677e61A|0x29eA7545' "$OUT"; then
  echo "ERROR: mainnet address still present in $OUT" >&2; exit 1
fi
echo "wrote $OUT"
