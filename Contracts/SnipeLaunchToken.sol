// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// BUILD NOTE: compile for the Paris EVM (no PUSH0, no MCOPY) so the bytecode runs on PulseChain:
//   evm_version = "paris"   (foundry.toml)   /   evmVersion: "paris" (hardhat)
// Solidity 0.8.26 defaults to Cancun, which emits opcodes PulseChain may not support.
// Pin your Solady version/commit as well.

import {ERC20} from "solady/src/tokens/ERC20.sol";
import {Base64} from "solady/src/utils/Base64.sol";

/// @notice On-chain metadata stored with the token (immutable once deployed)
struct TokenMetadata {
    string description;
    string website;
    string image;
}

/// @title LaunchToken
/// @notice Fixed-supply ERC-20 (21 000 000 tokens, always 18 decimals) with:
///         - Solady gas-optimized base + EIP-2612 Permit
///         - Transfer lock until launch() (no time limit: lifts only on launch())
///         - Immutable creator + graffiti (no Ownable / no admin)
///         - Burnable
///         - Validated, length-capped on-chain metadata + tokenURI()/contractURI()
/// @dev Only `initialRecipient` can call launch(). There is NO time-based unlock:
///      the lock lifts only when launch() is called. While locked, tokens can only
///      move to or from `initialRecipient` (the SHDLaunchFactory), so holders can
///      always sell back to its bonding curve, and nobody can seed a rival pool
///      before the factory does.
contract LaunchToken is ERC20 {
    // ============================================================
    // Constants
    // ============================================================

    /// @notice Tokens minted at construction (18 decimals). Burns reduce totalSupply()
    ///         but this constant never changes.
    uint256 public constant INITIAL_SUPPLY = 21_000_000 ether;

    uint256 public constant MAX_NAME_LENGTH = 32;
    uint256 public constant MAX_SYMBOL_LENGTH = 12;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 512;
    uint256 public constant MAX_WEBSITE_LENGTH = 256;
    uint256 public constant MAX_IMAGE_LENGTH = 2048;

    // ============================================================
    // Immutable identity
    // ============================================================

    address public immutable creator;
    bytes32 public immutable graffiti;
    address public immutable initialRecipient;

    bytes32 private immutable _nameHash;
    string private _name;
    string private _symbol;

    TokenMetadata public metadata;

    // ============================================================
    // Launch state
    // ============================================================

    bool public launched;

    // ============================================================
    // Errors
    // ============================================================

    error AlreadyLaunched();
    error OnlyInitialRecipient();
    error TransferWhileLocked();
    error ZeroAddress();
    error InvalidRecipient();
    error InvalidName();
    error InvalidSymbol();
    error FieldTooLong();
    error InvalidWebsite();
    error InvalidImage();

    // ============================================================
    // Events
    // ============================================================

    event Launched(address indexed caller);
    /// @dev Emitted exactly once, at construction. Metadata is immutable.
    event MetadataSet(TokenMetadata metadata);

    // ============================================================
    // Constructor
    // ============================================================

    /// @param name_            Token name (1-32 printable ASCII chars, no leading/trailing space)
    /// @param symbol_          Token symbol (1-12 printable ASCII chars, no spaces)
    /// @param creator_         Immutable creator attribution (only as trustworthy as the deployer)
    /// @param graffiti_        Immutable graffiti (bytes32)
    /// @param recipient_       Receives the entire supply; only address allowed to call launch()
    /// @param metadata_        On-chain metadata (length-capped, URI prefixes validated)
    constructor(
        string memory name_,
        string memory symbol_,
        address creator_,
        bytes32 graffiti_,
        address recipient_,
        TokenMetadata memory metadata_
    ) {
        if (recipient_ == address(0)) revert ZeroAddress();
        if (creator_ == address(0)) revert ZeroAddress();

        _validateName(bytes(name_));
        _validateSymbol(bytes(symbol_));
        _validateMetadata(metadata_);

        _name = name_;
        _symbol = symbol_;
        _nameHash = keccak256(bytes(name_));

        creator = creator_;
        graffiti = graffiti_;
        initialRecipient = recipient_;
        metadata = metadata_;

        // Mint entire fixed supply to the recipient (normally your Launcher)
        _mint(recipient_, INITIAL_SUPPLY);

        emit MetadataSet(metadata_);
    }

    // ============================================================
    // ERC-20 metadata (decimals fixed at Solady's default of 18)
    // ============================================================

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @dev Required by Solady for the EIP-712 domain (Permit)
    function _constantNameHash() internal view override returns (bytes32) {
        return _nameHash;
    }

    // ============================================================
    // Launch (one-time)
    // ============================================================

    /// @notice True once launch() has been called (there is no time-based unlock)
    function isLaunched() public view returns (bool) {
        return launched;
    }

    /// @notice Unlocks free trading. Callable once, by the initialRecipient.
    function launch() external {
        if (msg.sender != initialRecipient) revert OnlyInitialRecipient();
        if (isLaunched()) revert AlreadyLaunched();

        launched = true;
        emit Launched(msg.sender);
    }

    // ============================================================
    // Transfer restriction
    // ============================================================

    /// @dev Solady hook: runs before every transfer / mint / burn
    function _beforeTokenTransfer(address from, address to, uint256) internal view override {
        // Allow mint and burn
        if (from == address(0) || to == address(0)) return;

        // After launch -> unrestricted
        if (isLaunched()) return;

        // Before launch -> only initialRecipient may send or receive
        if (from != initialRecipient && to != initialRecipient) {
            revert TransferWhileLocked();
        }
    }

    /// @dev Blocks "burn by transfer" to the zero address (use burn()) and tokens
    ///      accidentally sent to the token contract itself, where they'd be stuck.
    function transfer(address to, uint256 amount) public override returns (bool) {
        _checkRecipient(to);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _checkRecipient(to);
        return super.transferFrom(from, to, amount);
    }

    function _checkRecipient(address to) private view {
        if (to == address(0) || to == address(this)) revert InvalidRecipient();
    }

    // ============================================================
    // Burnable
    // ============================================================

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    // ============================================================
    // Metadata + tokenURI / contractURI
    // ============================================================

    /// @notice Returns a data-URI JSON metadata string
    function tokenURI() external view returns (string memory) {
        return _buildURI();
    }

    /// @notice Same as tokenURI(); provided because some indexers look for contractURI() on ERC-20s
    function contractURI() external view returns (string memory) {
        return _buildURI();
    }

    function _buildURI() internal view returns (string memory) {
        TokenMetadata memory m = metadata;

        bytes memory json = abi.encodePacked(
            '{"name":"', _escape(_name),
            '","symbol":"', _escape(_symbol),
            '","description":"', _escape(m.description),
            '","image":"', _escape(m.image),
            '","external_url":"', _escape(m.website),
            '"}'
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    /// @dev Full JSON string escape: quotes, backslashes, and all control chars (< 0x20 -> \u00XX)
    function _escape(string memory input) internal pure returns (string memory) {
        bytes memory src = bytes(input);
        uint256 extra;
        for (uint256 i; i < src.length; ++i) {
            uint8 c = uint8(src[i]);
            if (c == 0x22 || c == 0x5c) {
                extra += 1; // \" or \\
            } else if (c < 0x20) {
                extra += 5; // \u00XX (6 bytes replacing 1)
            }
        }

        if (extra == 0) return input;

        bytes16 hexChars = "0123456789abcdef";
        bytes memory dst = new bytes(src.length + extra);
        uint256 j;
        for (uint256 i; i < src.length; ++i) {
            uint8 c = uint8(src[i]);
            if (c == 0x22 || c == 0x5c) {
                dst[j++] = "\\";
                dst[j++] = src[i];
            } else if (c < 0x20) {
                dst[j++] = "\\";
                dst[j++] = "u";
                dst[j++] = "0";
                dst[j++] = "0";
                dst[j++] = hexChars[c >> 4];
                dst[j++] = hexChars[c & 0x0f];
            } else {
                dst[j++] = src[i];
            }
        }
        return string(dst);
    }

    // ============================================================
    // Input validation (constructor only)
    // ============================================================

    function _validateName(bytes memory n) private pure {
        if (
            n.length == 0 || n.length > MAX_NAME_LENGTH || !_isPrintableAscii(n, true) || n[0] == 0x20
                || n[n.length - 1] == 0x20
        ) revert InvalidName();
    }

    function _validateSymbol(bytes memory s) private pure {
        if (s.length == 0 || s.length > MAX_SYMBOL_LENGTH || !_isPrintableAscii(s, false)) {
            revert InvalidSymbol();
        }
    }

    function _validateMetadata(TokenMetadata memory m) private pure {
        bytes memory website = bytes(m.website);
        bytes memory image = bytes(m.image);

        if (bytes(m.description).length > MAX_DESCRIPTION_LENGTH) revert FieldTooLong();
        if (website.length > MAX_WEBSITE_LENGTH) revert FieldTooLong();
        if (image.length > MAX_IMAGE_LENGTH) revert FieldTooLong();

        // Empty is allowed. Otherwise only https:// or ipfs:// (blocks javascript:, file:, etc.)
        if (website.length != 0 && !_startsWith(website, "https://") && !_startsWith(website, "ipfs://")) {
            revert InvalidWebsite();
        }
        if (
            image.length != 0 && !_startsWith(image, "https://") && !_startsWith(image, "ipfs://")
                && !_startsWith(image, "data:image/")
        ) revert InvalidImage();
    }

    function _isPrintableAscii(bytes memory b, bool allowSpace) private pure returns (bool) {
        uint8 lo = allowSpace ? 0x20 : 0x21;
        for (uint256 i; i < b.length; ++i) {
            uint8 c = uint8(b[i]);
            if (c < lo || c > 0x7e) return false;
        }
        return true;
    }

    function _startsWith(bytes memory s, bytes memory prefix) private pure returns (bool) {
        if (s.length < prefix.length) return false;
        for (uint256 i; i < prefix.length; ++i) {
            if (s[i] != prefix[i]) return false;
        }
        return true;
    }
}
