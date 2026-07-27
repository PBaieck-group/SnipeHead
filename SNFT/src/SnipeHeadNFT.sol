// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract SnipeHeadNFT is ERC721, ERC721Enumerable, ERC721URIStorage, ERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // ---------- Config ----------

    uint256 public constant MAX_SUPPLY = 35;

    // Per-wallet cap on PUBLIC mints only. Owner reserve mints (ownerMint) do not
    // count against this — they're for team/giveaway allocations.
    uint256 public constant MAX_PER_WALLET = 2;

    // Metadata CID — matches the folder holding 001.json ... 035.json
    string private constant METADATA_CID = "bafybeiaathkuhqmyfvjssilwqeri57cbe3n3ely7ga2iipqhxjtx52k4ju";

    // TESTNET price: 0.000001 PLS. Before mainnet launch, call
    // setMintPrice(3_000_000 ether) to switch to the real 3,000,000 PLS price.
    uint256 public mintPrice = 3000000 ether;

    // Public sale is off by default 
    bool public mintingActive = false;

    uint256 private _nextTokenId = 1;

    mapping(address => uint256) public mintedPerWallet;

    // ---------- Constructor ----------

    // initialOwner    - your wallet, becomes the contract owner
    // royaltyReceiver - where EIP-2981 secondary-sale royalties are sent (can equal initialOwner)
    // royaltyFeeBps   - royalty fee in basis points
    constructor(address initialOwner, address royaltyReceiver, uint96 royaltyFeeBps)
        ERC721("SnipeHead NFT", "SNFT")
        Ownable(initialOwner)
    {
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeBps);
    }

    // ---------- Public minting ----------

    function mint(uint256 quantity) external payable nonReentrant {
        require(mintingActive, "Minting not active");
        require(quantity > 0, "Quantity must be > 0");
        require(_nextTokenId - 1 + quantity <= MAX_SUPPLY, "Exceeds max supply");
        require(mintedPerWallet[msg.sender] + quantity <= MAX_PER_WALLET, "Exceeds per-wallet limit");
        require(msg.value == mintPrice * quantity, "Incorrect PLS sent");

        mintedPerWallet[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            // Effects (counter increment) before interactions (_safeMint's callback)
            uint256 tokenId = _nextTokenId;
            _nextTokenId++;
            _safeMint(msg.sender, tokenId);
        }
    }

    // For team/reserve/giveaway mints, doesn't require payment.
    // Shares the same 35-token cap as public mint — once totalMinted() hits
    // MAX_SUPPLY, neither this nor mint() can be called again, ever.
    function ownerMint(address to, uint256 quantity) external onlyOwner nonReentrant {
        require(_nextTokenId - 1 + quantity <= MAX_SUPPLY, "Exceeds max supply");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId++;
            _safeMint(to, tokenId);
        }
    }

    function totalMinted() public view returns (uint256) {
        return _nextTokenId - 1;
    }

    // ---------- Owner controls ----------

    function setMintPrice(uint256 newPriceWei) external onlyOwner {
        mintPrice = newPriceWei;
    }

    function setMintingActive(bool active) external onlyOwner {
        mintingActive = active;
    }

    // Lets you change the royalty split/receiver later if needed
    function setDefaultRoyalty(address receiver, uint96 feeBps) external onlyOwner {
        _setDefaultRoyalty(receiver, feeBps);
    }

    // Pulls all PLS held by the contract to the current owner.
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }

    // ---------- Metadata ----------

    function _baseURI() internal pure override returns (string memory) {
        return string.concat("ipfs://", METADATA_CID, "/");
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        _requireOwned(tokenId);
        return string.concat(_baseURI(), _paddedId(tokenId), ".json");
    }

    // Pads a token ID to match 3-digit filenames: 1 -> "001", 12 -> "012", 123 -> "123"
    function _paddedId(uint256 tokenId) internal pure returns (string memory) {
        if (tokenId < 10) {
            return string.concat("00", tokenId.toString());
        } else if (tokenId < 100) {
            return string.concat("0", tokenId.toString());
        } else {
            return tokenId.toString();
        }
    }

    // ---------- Required overrides ----------

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
