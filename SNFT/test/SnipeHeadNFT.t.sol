// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {SnipeHeadNFT} from "../src/SnipeHeadNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract SnipeHeadNFTTest is Test {
    SnipeHeadNFT nft;

    address owner = makeAddr("owner");
    address royaltyReceiver = makeAddr("royaltyReceiver");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint96 constant ROYALTY_BPS = 500; // 5%

    function setUp() public {
        vm.prank(owner);
        nft = new SnipeHeadNFT(owner, royaltyReceiver, ROYALTY_BPS);
    }

    // ---------- Deployment ----------

    function test_InitialState() public view {
        assertEq(nft.owner(), owner);
        assertEq(nft.name(), "SnipeHead NFT");
        assertEq(nft.symbol(), "SNFT");
        assertFalse(nft.mintingActive());
        assertEq(nft.totalMinted(), 0);
        assertEq(nft.MAX_SUPPLY(), 35);
        assertEq(nft.MAX_PER_WALLET(), 2);
    }

    function test_RoyaltyInfo() public view {
        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10_000 ether);
        assertEq(receiver, royaltyReceiver);
        assertEq(amount, (10_000 ether * ROYALTY_BPS) / 10_000);
    }

    // ---------- Minting gate ----------

    function test_RevertWhen_MintingNotActive() public {
        uint256 price = nft.mintPrice(); // getter runs here (before prank/expect)
        vm.deal(alice, price + 1 ether);
        vm.prank(alice);
        vm.expectRevert("Minting not active");
        nft.mint{value: price}(1);
    }

    function _activateMinting() internal {
        vm.prank(owner);
        nft.setMintingActive(true);
    }

    // ---------- Happy path public mint ----------

    function test_PublicMint_Success() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price * 2);

        vm.prank(alice);
        nft.mint{value: price}(1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.mintedPerWallet(alice), 1);
        assertEq(address(nft).balance, price);
    }

    function test_PublicMint_MultipleQuantity() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price * 2);

        vm.prank(alice);
        nft.mint{value: price * 2}(2);

        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
    }

    // ---------- Payment validation ----------

    function test_RevertWhen_IncorrectPayment() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price);

        vm.prank(alice);
        vm.expectRevert("Incorrect PLS sent");
        nft.mint{value: price - 1}(1);
    }

    function test_RevertWhen_ZeroQuantity() public {
        _activateMinting();
        vm.prank(alice);
        vm.expectRevert("Quantity must be > 0");
        nft.mint{value: 0}(0);
    }

    // ---------- Per-wallet cap ----------

    function test_RevertWhen_ExceedsPerWalletCap() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price * 3);

        vm.startPrank(alice);
        nft.mint{value: price * 2}(2); // hits the cap of 2
        vm.expectRevert("Exceeds per-wallet limit");
        nft.mint{value: price}(1); // third one should fail
        vm.stopPrank();
    }

    function test_PerWalletCap_DoesNotAffectOtherWallets() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price * 2);
        vm.deal(bob, price * 2);

        vm.prank(alice);
        nft.mint{value: price * 2}(2);

        vm.prank(bob);
        nft.mint{value: price * 2}(2); // bob has his own separate cap

        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 2);
    }

    // ---------- Max supply cap ----------

    function test_RevertWhen_ExceedsMaxSupply() public {
        _activateMinting();
        uint256 price = nft.mintPrice();

        // Fill up to 35 using owner mints to distinct addresses (dodges per-wallet cap)
        for (uint256 i = 0; i < 35; i++) {
            address minter = address(uint160(1000 + i));
            vm.prank(owner);
            nft.ownerMint(minter, 1);
        }

        assertEq(nft.totalMinted(), 35);

        // Any further mint attempt, public or owner, should revert — no way around the cap
        vm.deal(alice, price);
        vm.prank(alice);
        vm.expectRevert("Exceeds max supply");
        nft.mint{value: price}(1);

        vm.prank(owner);
        vm.expectRevert("Exceeds max supply");
        nft.ownerMint(alice, 1);
    }

    // ---------- Partial supply / exact remaining quantity ----------

    function test_PublicMint_ExactRemainingSupply() public {
        // Fill 33 of 35 via owner mints to distinct wallets, leaving exactly 2 left
        for (uint256 i = 0; i < 33; i++) {
            address minter = address(uint160(2000 + i));
            vm.prank(owner);
            nft.ownerMint(minter, 1);
        }
        assertEq(nft.totalMinted(), 33);

        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price * 2);

        // Alice mints exactly the 2 remaining tokens (also her full per-wallet cap)
        vm.prank(alice);
        nft.mint{value: price * 2}(2);

        assertEq(nft.totalMinted(), 35);
        assertEq(nft.balanceOf(alice), 2);

        // Supply is now exhausted — even a 1-token attempt from a fresh wallet reverts
        vm.deal(bob, price);
        vm.prank(bob);
        vm.expectRevert("Exceeds max supply");
        nft.mint{value: price}(1);
    }

    // ---------- Owner mint ----------

    function test_OwnerMint_Success() public {
        vm.prank(owner);
        nft.ownerMint(alice, 2);

        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.totalMinted(), 2);
        // owner mints don't touch the public per-wallet counter
        assertEq(nft.mintedPerWallet(alice), 0);
    }

    function test_RevertWhen_NonOwnerCallsOwnerMint() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.ownerMint(alice, 1);
    }

    function test_PublicMint_AfterOwnerMint_PerWalletIndependent() public {
        // Owner reserves 2 tokens to alice before public sale even opens
        vm.prank(owner);
        nft.ownerMint(alice, 2);
        assertEq(nft.mintedPerWallet(alice), 0);

        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price * 2);

        // Alice can still mint her full public allocation — ownerMint doesn't
        // touch mintedPerWallet, so the two tracks are fully independent.
        vm.prank(alice);
        nft.mint{value: price * 2}(2);

        assertEq(nft.mintedPerWallet(alice), 2);
        assertEq(nft.balanceOf(alice), 4); // 2 reserved + 2 public
        assertEq(nft.totalMinted(), 4);
    }

    // ---------- Owner mint edge cases: address(0) / self / contract ----------

    function test_RevertWhen_OwnerMintToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert();
        nft.ownerMint(address(0), 1);
    }

    function test_OwnerMint_ToSelf() public {
        vm.prank(owner);
        nft.ownerMint(owner, 1);
        assertEq(nft.ownerOf(1), owner);
        assertEq(nft.balanceOf(owner), 1);
    }

    function test_OwnerMint_ToContract_WithReceiverSupport() public {
        GoodReceiver good = new GoodReceiver();
        vm.prank(owner);
        nft.ownerMint(address(good), 1);
        assertEq(nft.ownerOf(1), address(good));
    }

    function test_RevertWhen_OwnerMintToContract_WithoutReceiverSupport() public {
        NonReceiver bad = new NonReceiver();
        vm.prank(owner);
        vm.expectRevert();
        nft.ownerMint(address(bad), 1);
    }

    // ---------- tokenURI ----------

    function test_TokenURI_SingleDigitPadding() public {
        vm.prank(owner);
        nft.ownerMint(owner, 9); // mints tokens 1..9

        assertEq(
            nft.tokenURI(1),
            "ipfs://bafybeiaathkuhqmyfvjssilwqeri57cbe3n3ely7ga2iipqhxjtx52k4ju/001.json"
        );
        assertEq(
            nft.tokenURI(9),
            "ipfs://bafybeiaathkuhqmyfvjssilwqeri57cbe3n3ely7ga2iipqhxjtx52k4ju/009.json"
        );
    }

    function test_TokenURI_DoubleDigitPadding() public {
        vm.prank(owner);
        nft.ownerMint(owner, 12); // mints tokens 1..12

        assertEq(
            nft.tokenURI(12),
            "ipfs://bafybeiaathkuhqmyfvjssilwqeri57cbe3n3ely7ga2iipqhxjtx52k4ju/012.json"
        );
    }

    function test_RevertWhen_TokenURI_NonexistentToken() public {
        vm.expectRevert();
        nft.tokenURI(1);
    }

    // ---------- Price changes ----------

    function test_PriceChange_AffectsFutureMintsOnly() public {
        _activateMinting();
        uint256 oldPrice = nft.mintPrice();

        // Alice mints at the old price — succeeds
        vm.deal(alice, oldPrice);
        vm.prank(alice);
        nft.mint{value: oldPrice}(1);
        assertEq(nft.balanceOf(alice), 1);

        // Owner changes the price
        uint256 newPrice = oldPrice * 2;
        vm.prank(owner);
        nft.setMintPrice(newPrice);
        assertEq(nft.mintPrice(), newPrice);

        // Bob trying to mint at the now-stale old price reverts
        vm.deal(bob, oldPrice);
        vm.prank(bob);
        vm.expectRevert("Incorrect PLS sent");
        nft.mint{value: oldPrice}(1);

        // Bob mints correctly at the new price — the earlier mint at the old
        // price is untouched, only the *future* mint is affected
        vm.deal(bob, newPrice);
        vm.prank(bob);
        nft.mint{value: newPrice}(1);

        assertEq(nft.balanceOf(bob), 1);
        assertEq(address(nft).balance, oldPrice + newPrice);
    }

    function test_OwnerCanSetPriceToZero_FreeMint() public {
        // Intentional but dangerous: onlyOwner gate is the only thing stopping
        // an accidental or malicious free-for-all mint.
        vm.prank(owner);
        nft.setMintPrice(0);
        assertEq(nft.mintPrice(), 0);

        _activateMinting();

        vm.prank(alice);
        nft.mint{value: 0}(2); // quantity * 0 == 0, passes the payment check

        assertEq(nft.balanceOf(alice), 2);
        assertEq(address(nft).balance, 0);
    }

    function test_RevertWhen_NonOwnerSetsMintPrice() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setMintPrice(1);
    }

    // ---------- Withdraw ----------

    function test_Withdraw_Success() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price);
        vm.prank(alice);
        nft.mint{value: price}(1);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + price);
    }

    function test_RevertWhen_NonOwnerWithdraws() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.withdraw();
    }

    function test_RevertWhen_WithdrawWithZeroBalance() public {
        vm.prank(owner);
        vm.expectRevert("Nothing to withdraw");
        nft.withdraw();
    }

    function test_Withdraw_AlwaysSendsToCurrentOwner_NotOriginalOwner() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price);
        vm.prank(alice);
        nft.mint{value: price}(1);

        // Ownership moves to bob before anyone withdraws
        vm.prank(owner);
        nft.transferOwnership(bob);

        uint256 bobBalanceBefore = bob.balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(bob);
        nft.withdraw();

        // Funds follow the *current* owner() at call time, not whoever
        // owned the contract when the balance accrued.
        assertEq(bob.balance, bobBalanceBefore + price);
        assertEq(owner.balance, ownerBalanceBefore); // original owner got nothing
        assertEq(address(nft).balance, 0);

        // The original owner can no longer withdraw at all
        vm.prank(owner);
        vm.expectRevert();
        nft.withdraw();
    }

    function test_MultipleWithdrawals_AccumulateCorrectly() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        uint256 ownerTotal = 0;
        uint256 ownerBalanceBefore = owner.balance;

        // Round 1: alice mints, owner withdraws
        vm.deal(alice, price);
        vm.prank(alice);
        nft.mint{value: price}(1);

        vm.prank(owner);
        nft.withdraw();
        ownerTotal += price;
        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + ownerTotal);

        // Round 2: bob mints twice (2 tokens), owner withdraws again
        vm.deal(bob, price * 2);
        vm.prank(bob);
        nft.mint{value: price * 2}(2);

        vm.prank(owner);
        nft.withdraw();
        ownerTotal += price * 2;
        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + ownerTotal);

        // Round 3: alice mints her remaining allocation (1 more token)
        vm.deal(alice, price);
        vm.prank(alice);
        nft.mint{value: price}(1);

        vm.prank(owner);
        nft.withdraw();
        ownerTotal += price;
        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + ownerTotal);
    }

    // ---------- Ownership ----------

    function test_TransferOwnership() public {
        vm.prank(owner);
        nft.transferOwnership(alice);
        assertEq(nft.owner(), alice);
    }

    function test_RenounceOwnership_LocksOutAdminFunctions() public {
        vm.prank(owner);
        nft.renounceOwnership();

        assertEq(nft.owner(), address(0));

        vm.expectRevert();
        nft.setMintingActive(true);
    }

    /// @notice CRITICAL: renouncing ownership permanently bricks withdraw().
    ///
    /// withdraw() is `onlyOwner`. Once owner() is address(0), there is no
    /// account left that can ever pass that check again — not the old
    /// owner, not the deployer, nobody. Any PLS sitting in the contract at
    /// the moment of renouncement (or sent afterward, e.g. via a public
    /// mint that's somehow still reachable, or a plain transfer) is
    /// permanently unrecoverable. This is the single most common way funds
    /// are lost in Ownable + pull-withdraw patterns like this one.
    ///
    /// Do NOT call renounceOwnership() on a deployed instance of this
    /// contract while it might ever hold a balance.
    function test_RenounceOwnership_LocksFundsForever() public {
        _activateMinting();
        uint256 price = nft.mintPrice();
        vm.deal(alice, price);
        vm.prank(alice);
        nft.mint{value: price}(1);
        assertEq(address(nft).balance, price);

        vm.prank(owner);
        nft.renounceOwnership();
        assertEq(nft.owner(), address(0));

        // Nobody — not even the former owner — can withdraw anymore.
        vm.prank(owner);
        vm.expectRevert();
        nft.withdraw();

        vm.prank(alice);
        vm.expectRevert();
        nft.withdraw();

        // The balance is provably stuck: it never leaves the contract.
        assertEq(address(nft).balance, price);
    }

    // ---------- Royalties ----------

    function test_SetDefaultRoyalty_CanBeChanged() public {
        address newReceiver = makeAddr("newReceiver");
        uint96 newBps = 1000; // 10%

        vm.prank(owner);
        nft.setDefaultRoyalty(newReceiver, newBps);

        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10_000 ether);
        assertEq(receiver, newReceiver);
        assertEq(amount, (10_000 ether * newBps) / 10_000);
    }

    function test_RevertWhen_NonOwnerSetsDefaultRoyalty() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setDefaultRoyalty(alice, 100);
    }

    // ---------- Reentrancy ----------

    function test_Reentrancy_BlockedOnMint() public {
        _activateMinting();
        uint256 price = nft.mintPrice();

        MaliciousMinter attacker = new MaliciousMinter(nft, price);
        vm.deal(address(attacker), price * 2);

        // The re-entrant inner call reverts due to nonReentrant, which bubbles up
        // and reverts the entire outer attack() call.
        vm.expectRevert();
        attacker.attack();

        // Confirm nothing was minted to the attacker despite the attempt
        assertEq(nft.balanceOf(address(attacker)), 0);
    }

    // ---------- Fuzz tests ----------

    /// @dev Any quantity within the per-wallet cap, paid exactly, always succeeds.
    function testFuzz_PublicMint_ValidQuantity(uint8 quantityRaw) public {
        uint256 quantity = bound(quantityRaw, 1, nft.MAX_PER_WALLET());
        _activateMinting();
        uint256 price = nft.mintPrice();

        vm.deal(alice, price * quantity);
        vm.prank(alice);
        nft.mint{value: price * quantity}(quantity);

        assertEq(nft.balanceOf(alice), quantity);
        assertEq(nft.mintedPerWallet(alice), quantity);
        assertEq(address(nft).balance, price * quantity);
    }

    /// @dev Any payment that doesn't exactly equal price * quantity must revert,
    /// whether it's too little or too much.
    function testFuzz_RevertWhen_PaymentIsNotExact(uint96 offsetRaw) public {
        uint256 offset = bound(uint256(offsetRaw), 1, 10 ether);
        _activateMinting();
        uint256 price = nft.mintPrice();

        // Both underpay and overpay by the same fuzzed offset should revert
        vm.deal(alice, price + offset);
        vm.prank(alice);
        vm.expectRevert("Incorrect PLS sent");
        nft.mint{value: price + offset}(1);

        if (offset < price) {
            vm.deal(bob, price - offset);
            vm.prank(bob);
            vm.expectRevert("Incorrect PLS sent");
            nft.mint{value: price - offset}(1);
        }
    }

    /// @dev Whatever price the owner sets, mint() only ever accepts payment
    /// matching that exact current price — never the old one.
    function testFuzz_SetMintPrice_ExactPaymentAtNewPrice(uint128 newPriceRaw) public {
        uint256 newPrice = bound(uint256(newPriceRaw), 0, 1_000_000 ether);

        vm.prank(owner);
        nft.setMintPrice(newPrice);
        _activateMinting();

        vm.deal(alice, newPrice);
        vm.prank(alice);
        nft.mint{value: newPrice}(1);

        assertEq(nft.balanceOf(alice), 1);
        assertEq(address(nft).balance, newPrice);
    }

    /// @dev No matter how many independent wallets mint, a single withdraw()
    /// call always sweeps the entire accumulated balance to the owner —
    /// never more, never less, never leaves a remainder.
    function testFuzz_Withdraw_AlwaysSendsFullAccumulatedBalance(uint8 mintersCountRaw) public {
        uint256 mintersCount = bound(mintersCountRaw, 1, 15); // 15 * 2 = 30 <= MAX_SUPPLY
        _activateMinting();
        uint256 price = nft.mintPrice();

        uint256 expectedBalance = 0;
        for (uint256 i = 0; i < mintersCount; i++) {
            address minter = address(uint160(9000 + i));
            vm.deal(minter, price * 2);
            vm.prank(minter);
            nft.mint{value: price * 2}(2);
            expectedBalance += price * 2;
        }

        assertEq(address(nft).balance, expectedBalance);

        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        nft.withdraw();

        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + expectedBalance);
    }

    // ---------- Royalty bounds ----------

    /// @dev OZ's _setDefaultRoyalty reverts if feeBps > 10_000 (i.e. > 100%).
    /// Constructor path: a bad royalty passed at deploy time must revert too.
    function test_RevertWhen_ConstructorRoyaltyExceedsMax() public {
        uint96 invalidBps = 10_001;
        vm.expectRevert();
        new SnipeHeadNFT(owner, royaltyReceiver, invalidBps);
    }

    /// @dev setDefaultRoyalty path: same bound enforced post-deployment.
    function test_RevertWhen_SetDefaultRoyaltyExceedsMax() public {
        uint96 invalidBps = 10_001;
        vm.prank(owner);
        vm.expectRevert();
        nft.setDefaultRoyalty(royaltyReceiver, invalidBps);
    }

    // ---------- Enumerable consistency ----------

    /// @dev totalSupply() should always track totalMinted(), and
    /// tokenOfOwnerByIndex()/tokenByIndex() should stay consistent after a
    /// mix of owner mints and public mints across multiple wallets.
    function test_TotalSupply_And_Enumeration_ConsistentAfterMixedMints() public {
        // Owner reserves 2 tokens to alice up front (tokens 1, 2)
        vm.prank(owner);
        nft.ownerMint(alice, 2);

        _activateMinting();
        uint256 price = nft.mintPrice();

        // Bob public-mints 2 (tokens 3, 4)
        vm.deal(bob, price * 2);
        vm.prank(bob);
        nft.mint{value: price * 2}(2);

        // Owner reserves 1 more to bob (token 5)
        vm.prank(owner);
        nft.ownerMint(bob, 1);

        // Alice public-mints her remaining allocation, 0 left since she already
        // has 2 from ownerMint but that doesn't touch mintedPerWallet — she can
        // still mint her full public cap of 2 (tokens 6, 7)
        vm.deal(alice, price * 2);
        vm.prank(alice);
        nft.mint{value: price * 2}(2);

        // totalSupply() must always equal totalMinted()
        assertEq(nft.totalSupply(), nft.totalMinted());
        assertEq(nft.totalSupply(), 7);

        // Global enumeration: tokenByIndex should cover token IDs 1..7 exactly once
        bool[8] memory seen; // index 0 unused, tokens are 1..7
        for (uint256 i = 0; i < nft.totalSupply(); i++) {
            uint256 tokenId = nft.tokenByIndex(i);
            assertFalse(seen[tokenId], "duplicate token in global enumeration");
            seen[tokenId] = true;
        }
        for (uint256 tokenId = 1; tokenId <= 7; tokenId++) {
            assertTrue(seen[tokenId], "missing token in global enumeration");
        }

        // Per-owner enumeration: alice holds tokens {1,2,6,7}, bob holds {3,4,5}
        assertEq(nft.balanceOf(alice), 4);
        assertEq(nft.balanceOf(bob), 3);

        for (uint256 i = 0; i < nft.balanceOf(alice); i++) {
            uint256 tokenId = nft.tokenOfOwnerByIndex(alice, i);
            assertEq(nft.ownerOf(tokenId), alice);
        }
        for (uint256 i = 0; i < nft.balanceOf(bob); i++) {
            uint256 tokenId = nft.tokenOfOwnerByIndex(bob, i);
            assertEq(nft.ownerOf(tokenId), bob);
        }
    }

    // ---------- supportsInterface ----------

    /// @dev Marketplaces check these interface IDs — confirm they all resolve true.
    function test_SupportsInterface() public view {
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC721Enumerable).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC2981).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC165).interfaceId));

        // Sanity check: a random/garbage interface ID should return false
        assertFalse(nft.supportsInterface(0xffffffff));
    }
}

// A malicious contract that tries to re-enter mint() from inside its own
// onERC721Received callback, fired by _safeMint during the first mint call.
contract MaliciousMinter {
    SnipeHeadNFT public target;
    uint256 public price;
    bool public attacking;

    constructor(SnipeHeadNFT _target, uint256 _price) {
        target = _target;
        price = _price;
    }

    function attack() external {
        attacking = true;
        target.mint{value: price}(1);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (attacking) {
            attacking = false;
            // This re-entrant call should revert — ReentrancyGuard is still
            // "locked" from the outer mint() call still executing.
            target.mint{value: price}(1);
        }
        return this.onERC721Received.selector;
    }
}

// A well-behaved contract recipient implementing IERC721Receiver correctly.
contract GoodReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

// A contract that does NOT implement IERC721Receiver — safeMint to this
// address must revert.
contract NonReceiver {}
