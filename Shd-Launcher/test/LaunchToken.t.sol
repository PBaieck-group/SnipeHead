// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Base64} from "solady/src/utils/Base64.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";

/// @dev Stand-in for the LaunchFactory: it deploys the token, so it is the
///      `initialRecipient`, holds the whole supply, and is the only one who can launch().
contract MockFactory {
    function deploy(
        string memory name_,
        string memory symbol_,
        address creator_,
        bytes32 graffiti_,
        TokenMetadata memory metadata_
    ) external returns (LaunchToken) {
        return new LaunchToken(name_, symbol_, creator_, graffiti_, address(this), metadata_);
    }

    function launch(LaunchToken t) external {
        t.launch();
    }

    function send(LaunchToken t, address to, uint256 amount) external {
        t.transfer(to, amount);
    }
}

contract LaunchTokenTest is Test {
    LaunchToken internal token;
    MockFactory internal factory;

    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    bytes32 internal constant GRAFFITI = bytes32("gm pulsechain");

    event Launched(address indexed caller);
    event MetadataSet(TokenMetadata metadata);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        factory = new MockFactory();
        token = factory.deploy("Snipe Test", "STEST", creator, GRAFFITI, _meta());
    }

    // ------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------

    function _meta() internal pure returns (TokenMetadata memory) {
        return TokenMetadata({
            description: "A test token", website: "https://example.com", image: "ipfs://bafyimage"
        });
    }

    function _deployRaw(
        string memory n,
        string memory s,
        address creator_,
        address recipient_,
        TokenMetadata memory m
    ) internal returns (LaunchToken) {
        return new LaunchToken(n, s, creator_, GRAFFITI, recipient_, m);
    }

    function _giveAlice(uint256 amt) internal {
        factory.send(token, alice, amt);
    }

    function _decodeURI(string memory uri) internal pure returns (string memory) {
        bytes memory b = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        assertGt(b.length, prefix.length, "uri too short");
        bytes memory payload = new bytes(b.length - prefix.length);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = b[i + prefix.length];
        }
        return string(Base64.decode(string(payload)));
    }

    // ============================================================
    // Constructor / initial state
    // ============================================================

    function test_Constructor_SetsState() public view {
        assertEq(token.name(), "Snipe Test");
        assertEq(token.symbol(), "STEST");
        assertEq(token.decimals(), 18);
        assertEq(token.creator(), creator);
        assertEq(token.graffiti(), GRAFFITI);
        assertEq(token.initialRecipient(), address(factory));
        assertEq(token.totalSupply(), 21_000_000 ether);
        assertEq(token.INITIAL_SUPPLY(), 21_000_000 ether);
        assertEq(token.balanceOf(address(factory)), 21_000_000 ether);
        assertFalse(token.launched());
        assertFalse(token.isLaunched());

        (string memory d, string memory w, string memory i) = token.metadata();
        assertEq(d, "A test token");
        assertEq(w, "https://example.com");
        assertEq(i, "ipfs://bafyimage");
    }

    function test_Constructor_EmitsMintAndMetadata() public {
        TokenMetadata memory m = _meta();
        address predicted = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));

        vm.expectEmit(true, true, false, true, predicted);
        emit Transfer(address(0), address(this), 21_000_000 ether);
        vm.expectEmit(false, false, false, true, predicted);
        emit MetadataSet(m);
        _deployRaw("Evt", "EVT", creator, address(this), m);
    }

    function test_Constructor_RevertsZeroRecipient() public {
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.ZeroAddress.selector);
        _deployRaw("A", "A", creator, address(0), m);
    }

    function test_Constructor_RevertsZeroCreator() public {
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.ZeroAddress.selector);
        _deployRaw("A", "A", address(0), address(this), m);
    }

    // ---------------- name ----------------

    function test_Name_RevertsEmpty() public {
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw("", "A", creator, address(this), m);
    }

    function test_Name_32CharsOk_33Reverts() public {
        string memory ok32 = "12345678901234567890123456789012";
        string memory bad33 = "123456789012345678901234567890123";
        _deployRaw(ok32, "A", creator, address(this), _meta());

        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw(bad33, "A", creator, address(this), m);
    }

    function test_Name_InnerSpaceOk() public {
        LaunchToken t = _deployRaw("My Cool Token", "A", creator, address(this), _meta());
        assertEq(t.name(), "My Cool Token");
    }

    function test_Name_RevertsLeadingOrTrailingSpace() public {
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw(" Lead", "A", creator, address(this), m);
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw("Trail ", "A", creator, address(this), m);
    }

    function test_Name_RevertsNonAsciiAndControl() public {
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw(unicode"Tök", "A", creator, address(this), m);
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw("Tab\tName", "A", creator, address(this), m);
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw("New\nLine", "A", creator, address(this), m);
        vm.expectRevert(LaunchToken.InvalidName.selector);
        _deployRaw("Del\x7fChar", "A", creator, address(this), m);
    }

    // ---------------- symbol ----------------

    function test_Symbol_RevertsEmpty() public {
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.InvalidSymbol.selector);
        _deployRaw("A", "", creator, address(this), m);
    }

    function test_Symbol_12CharsOk_13Reverts() public {
        _deployRaw("A", "ABCDEFGHIJKL", creator, address(this), _meta());
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.InvalidSymbol.selector);
        _deployRaw("A", "ABCDEFGHIJKLM", creator, address(this), m);
    }

    function test_Symbol_RevertsSpaceNonAsciiControl() public {
        TokenMetadata memory m = _meta();
        vm.expectRevert(LaunchToken.InvalidSymbol.selector);
        _deployRaw("A", "AB CD", creator, address(this), m);
        vm.expectRevert(LaunchToken.InvalidSymbol.selector);
        _deployRaw("A", unicode"É", creator, address(this), m);
        vm.expectRevert(LaunchToken.InvalidSymbol.selector);
        _deployRaw("A", "A\tB", creator, address(this), m);
    }

    // ---------------- metadata ----------------

    function test_Metadata_EmptyFieldsOk() public {
        TokenMetadata memory m = TokenMetadata("", "", "");
        LaunchToken t = _deployRaw("A", "A", creator, address(this), m);
        (string memory d, string memory w, string memory i) = t.metadata();
        assertEq(bytes(d).length + bytes(w).length + bytes(i).length, 0);
    }

    function test_Metadata_LengthBoundaries() public {
        TokenMetadata memory m = TokenMetadata(
            string(new bytes(512)),
            string.concat("https://", string(_fill(256 - 8, "a"))),
            string.concat("https://", string(_fill(2048 - 8, "a")))
        );
        m.description = string(_fill(512, "a"));
        _deployRaw("A", "A", creator, address(this), m);

        m.description = string(_fill(513, "a"));
        vm.expectRevert(LaunchToken.FieldTooLong.selector);
        _deployRaw("A", "A", creator, address(this), m);
    }

    function test_Metadata_WebsiteTooLong() public {
        TokenMetadata memory m = TokenMetadata("", string.concat("https://", string(_fill(257 - 8, "a"))), "");
        vm.expectRevert(LaunchToken.FieldTooLong.selector);
        _deployRaw("A", "A", creator, address(this), m);
    }

    function test_Metadata_ImageTooLong() public {
        TokenMetadata memory m = TokenMetadata("", "", string.concat("https://", string(_fill(2049 - 8, "a"))));
        vm.expectRevert(LaunchToken.FieldTooLong.selector);
        _deployRaw("A", "A", creator, address(this), m);
    }

    function test_Metadata_WebsiteSchemes() public {
        _deployRaw("A", "A", creator, address(this), TokenMetadata("", "https://a.io", ""));
        _deployRaw("A", "A", creator, address(this), TokenMetadata("", "ipfs://Qm", ""));

        string[5] memory bad = ["http://a.io", "javascript:alert(1)", "data:text/html,x", "file:///etc/passwd", "HTTPS://a.io"];
        for (uint256 i; i < bad.length; ++i) {
            TokenMetadata memory m = TokenMetadata("", bad[i], "");
            vm.expectRevert(LaunchToken.InvalidWebsite.selector);
            _deployRaw("A", "A", creator, address(this), m);
        }
    }

    function test_Metadata_ImageSchemes() public {
        _deployRaw("A", "A", creator, address(this), TokenMetadata("", "", "https://a.io/x.png"));
        _deployRaw("A", "A", creator, address(this), TokenMetadata("", "", "ipfs://Qm"));
        _deployRaw(
            "A", "A", creator, address(this), TokenMetadata("", "", "data:image/png;base64,AAAA")
        );

        string[4] memory bad = ["http://a.io/x.png", "javascript:alert(1)", "data:text/html,x", "file:///x.png"];
        for (uint256 i; i < bad.length; ++i) {
            TokenMetadata memory m = TokenMetadata("", "", bad[i]);
            vm.expectRevert(LaunchToken.InvalidImage.selector);
            _deployRaw("A", "A", creator, address(this), m);
        }
    }

    function _fill(uint256 len, bytes1 c) internal pure returns (bytes memory b) {
        b = new bytes(len);
        for (uint256 i; i < len; ++i) {
            b[i] = c;
        }
    }

    // ============================================================
    // Transfer lock before launch
    // ============================================================

    function test_Locked_RecipientCanSend() public {
        _giveAlice(1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function test_Locked_HolderCanReturnToRecipient() public {
        _giveAlice(1000 ether);
        vm.prank(alice);
        token.transfer(address(factory), 400 ether);
        assertEq(token.balanceOf(alice), 600 ether);
    }

    function test_Locked_HolderToHolderReverts() public {
        _giveAlice(1000 ether);
        vm.prank(alice);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        token.transfer(bob, 1 ether);
    }

    function test_Locked_TransferFromHolderToHolderReverts() public {
        _giveAlice(1000 ether);
        vm.prank(alice);
        token.approve(bob, 100 ether);
        vm.prank(bob);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        token.transferFrom(alice, carol, 10 ether);
    }

    function test_Locked_TransferFromHolderToRecipientWorks() public {
        _giveAlice(1000 ether);
        vm.prank(alice);
        token.approve(bob, 100 ether);
        vm.prank(bob);
        token.transferFrom(alice, address(factory), 10 ether);
        assertEq(token.balanceOf(alice), 990 ether);
        assertEq(token.allowance(alice, bob), 90 ether);
    }

    function test_Locked_ApproveIsNotRestricted() public {
        _giveAlice(10 ether);
        vm.prank(alice);
        token.approve(bob, 5 ether);
        assertEq(token.allowance(alice, bob), 5 ether);
    }

    // ============================================================
    // launch()
    // ============================================================

    function test_Launch_OnlyInitialRecipient() public {
        vm.prank(alice);
        vm.expectRevert(LaunchToken.OnlyInitialRecipient.selector);
        token.launch();

        vm.prank(creator);
        vm.expectRevert(LaunchToken.OnlyInitialRecipient.selector);
        token.launch();
    }

    function test_Launch_Works() public {
        vm.expectEmit(true, false, false, false, address(token));
        emit Launched(address(factory));
        factory.launch(token);

        assertTrue(token.launched());
        assertTrue(token.isLaunched());
    }

    function test_Launch_CannotRepeat() public {
        factory.launch(token);
        vm.expectRevert(LaunchToken.AlreadyLaunched.selector);
        factory.launch(token);
    }

    function test_AfterLaunch_HoldersTradeFreely() public {
        _giveAlice(1000 ether);
        factory.launch(token);

        vm.prank(alice);
        token.transfer(bob, 300 ether);
        vm.prank(bob);
        token.transfer(carol, 100 ether);

        assertEq(token.balanceOf(alice), 700 ether);
        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.balanceOf(carol), 100 ether);
    }

    // ============================================================
    // No time-based unlock (deadline removed)
    // ============================================================

    function test_NoTimeUnlock_StaysLockedForeverUntilLaunch() public {
        _giveAlice(1000 ether);

        vm.warp(block.timestamp + 365 days);
        assertFalse(token.isLaunched());
        assertFalse(token.launched());

        vm.prank(alice);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        token.transfer(bob, 1 ether);

        factory.launch(token);
        assertTrue(token.isLaunched());
        vm.prank(alice);
        token.transfer(bob, 1 ether);
        assertEq(token.balanceOf(bob), 1 ether);
    }

    // ============================================================
    // Recipient guards (zero address / token itself)
    // ============================================================

    function test_Transfer_RevertsToZero() public {
        vm.expectRevert(LaunchToken.InvalidRecipient.selector);
        factory.send(token, address(0), 1 ether);
    }

    function test_Transfer_RevertsToTokenItself() public {
        vm.expectRevert(LaunchToken.InvalidRecipient.selector);
        factory.send(token, address(token), 1 ether);
    }

    function test_TransferFrom_RevertsToZeroAndToken() public {
        _giveAlice(10 ether);
        factory.launch(token);
        vm.startPrank(alice);
        token.approve(bob, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(LaunchToken.InvalidRecipient.selector);
        token.transferFrom(alice, address(0), 1 ether);
        vm.expectRevert(LaunchToken.InvalidRecipient.selector);
        token.transferFrom(alice, address(token), 1 ether);
        vm.stopPrank();
    }

    function test_Transfer_GuardsHoldAfterLaunchToo() public {
        factory.launch(token);
        vm.expectRevert(LaunchToken.InvalidRecipient.selector);
        factory.send(token, address(0), 1 ether);
        vm.expectRevert(LaunchToken.InvalidRecipient.selector);
        factory.send(token, address(token), 1 ether);
    }

    function test_Transfer_InsufficientBalanceReverts() public {
        _giveAlice(1 ether);
        factory.launch(token);
        vm.prank(alice);
        vm.expectRevert(bytes4(0xf4d678b8)); // Solady InsufficientBalance()
        token.transfer(bob, 2 ether);
    }

    function testFuzz_TransferAfterLaunch_ConservesSupply(uint256 give, uint256 move) public {
        give = bound(give, 0, 21_000_000 ether);
        move = bound(move, 0, give);
        _giveAlice(give);
        factory.launch(token);
        vm.prank(alice);
        token.transfer(bob, move);

        assertEq(token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(address(factory)), 21_000_000 ether);
        assertEq(token.totalSupply(), 21_000_000 ether);
    }

    // ============================================================
    // Burn
    // ============================================================

    function test_Burn_ReducesSupplyAndBalance() public {
        _giveAlice(1000 ether);
        vm.prank(alice);
        token.burn(250 ether);

        assertEq(token.balanceOf(alice), 750 ether);
        assertEq(token.totalSupply(), 21_000_000 ether - 250 ether);
        assertEq(token.INITIAL_SUPPLY(), 21_000_000 ether, "constant never changes");
    }

    function test_Burn_WorksWhileLocked() public {
        _giveAlice(10 ether);
        assertFalse(token.isLaunched());
        vm.prank(alice);
        token.burn(10 ether);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Burn_EmitsTransferToZero() public {
        _giveAlice(10 ether);
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, address(0), 4 ether);
        vm.prank(alice);
        token.burn(4 ether);
    }

    function test_Burn_MoreThanBalanceReverts() public {
        _giveAlice(1 ether);
        vm.prank(alice);
        vm.expectRevert(bytes4(0xf4d678b8)); // InsufficientBalance()
        token.burn(2 ether);
    }

    function test_BurnFrom_UsesAllowance() public {
        _giveAlice(100 ether);
        vm.prank(alice);
        token.approve(bob, 60 ether);

        vm.prank(bob);
        token.burnFrom(alice, 40 ether);

        assertEq(token.balanceOf(alice), 60 ether);
        assertEq(token.allowance(alice, bob), 20 ether);
        assertEq(token.totalSupply(), 21_000_000 ether - 40 ether);
    }

    function test_BurnFrom_WithoutAllowanceReverts() public {
        _giveAlice(100 ether);
        vm.prank(bob);
        vm.expectRevert(bytes4(0x13be252b)); // InsufficientAllowance()
        token.burnFrom(alice, 1 ether);
    }

    function test_BurnFrom_InfiniteAllowanceNotDecreased() public {
        _giveAlice(100 ether);
        vm.prank(alice);
        token.approve(bob, type(uint256).max);
        vm.prank(bob);
        token.burnFrom(alice, 10 ether);
        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    function testFuzz_Burn_SupplyAccounting(uint256 give, uint256 burnAmt) public {
        give = bound(give, 0, 21_000_000 ether);
        burnAmt = bound(burnAmt, 0, give);
        _giveAlice(give);
        vm.prank(alice);
        token.burn(burnAmt);
        assertEq(token.totalSupply(), 21_000_000 ether - burnAmt);
    }

    // ============================================================
    // EIP-2612 permit
    // ============================================================

    function _permitDigest(address owner_, address spender, uint256 value, uint256 nonce, uint256 dl)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner_,
                spender,
                value,
                nonce,
                dl
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
    }

    function test_Permit_DomainSeparator() public view {
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Snipe Test")),
                keccak256(bytes("1")),
                block.chainid,
                address(token)
            )
        );
        assertEq(token.DOMAIN_SEPARATOR(), expected);
    }

    function test_Permit_Works() public {
        (address owner_, uint256 pk) = makeAddrAndKey("permitOwner");
        uint256 dl = block.timestamp + 1 hours;
        bytes32 digest = _permitDigest(owner_, bob, 123 ether, 0, dl);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        token.permit(owner_, bob, 123 ether, dl, v, r, s);

        assertEq(token.allowance(owner_, bob), 123 ether);
        assertEq(token.nonces(owner_), 1);
    }

    function test_Permit_WorksWhileLocked() public {
        assertFalse(token.isLaunched());
        test_Permit_Works();
    }

    function test_Permit_ReplayReverts() public {
        (address owner_, uint256 pk) = makeAddrAndKey("permitOwner");
        uint256 dl = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _permitDigest(owner_, bob, 1 ether, 0, dl));
        token.permit(owner_, bob, 1 ether, dl, v, r, s);

        vm.expectRevert(bytes4(0xddafbaef)); // InvalidPermit()
        token.permit(owner_, bob, 1 ether, dl, v, r, s);
    }

    function test_Permit_ExpiredReverts() public {
        (address owner_, uint256 pk) = makeAddrAndKey("permitOwner");
        uint256 dl = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _permitDigest(owner_, bob, 1 ether, 0, dl));

        vm.warp(dl + 1);
        vm.expectRevert(bytes4(0x1a15a3cc)); // PermitExpired()
        token.permit(owner_, bob, 1 ether, dl, v, r, s);
    }

    function test_Permit_ValidAtExactDeadline() public {
        (address owner_, uint256 pk) = makeAddrAndKey("permitOwner");
        uint256 dl = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _permitDigest(owner_, bob, 1 ether, 0, dl));
        vm.warp(dl);
        token.permit(owner_, bob, 1 ether, dl, v, r, s);
        assertEq(token.allowance(owner_, bob), 1 ether);
    }

    function test_Permit_WrongSignerReverts() public {
        (address owner_,) = makeAddrAndKey("permitOwner");
        (, uint256 otherPk) = makeAddrAndKey("someoneElse");
        uint256 dl = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherPk, _permitDigest(owner_, bob, 1 ether, 0, dl));

        vm.expectRevert(bytes4(0xddafbaef)); // InvalidPermit()
        token.permit(owner_, bob, 1 ether, dl, v, r, s);
    }

    function test_Permit_TamperedValueReverts() public {
        (address owner_, uint256 pk) = makeAddrAndKey("permitOwner");
        uint256 dl = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _permitDigest(owner_, bob, 1 ether, 0, dl));

        vm.expectRevert(bytes4(0xddafbaef));
        token.permit(owner_, bob, 2 ether, dl, v, r, s);
    }

    // ============================================================
    // tokenURI / contractURI
    // ============================================================

    function test_URI_BothMatch() public view {
        assertEq(token.tokenURI(), token.contractURI());
    }

    function test_URI_ExactJson() public view {
        string memory json = _decodeURI(token.tokenURI());
        assertEq(
            json,
            '{"name":"Snipe Test","symbol":"STEST","description":"A test token","image":"ipfs://bafyimage","external_url":"https://example.com"}'
        );
    }

    function test_URI_EscapesQuotesBackslashesAndControlChars() public {
        TokenMetadata memory m = TokenMetadata({
            description: 'say "hi" \\ end\n\ttab', website: "https://a.io", image: "ipfs://x"
        });
        LaunchToken t = _deployRaw('A"B\\C', 'S"Y', creator, address(this), m);

        string memory json = _decodeURI(t.tokenURI());
        assertEq(
            json,
            '{"name":"A\\"B\\\\C","symbol":"S\\"Y","description":"say \\"hi\\" \\\\ end\\u000a\\u0009tab","image":"ipfs://x","external_url":"https://a.io"}'
        );

        assertEq(vm.parseJsonString(json, ".name"), 'A"B\\C');
        assertEq(vm.parseJsonString(json, ".description"), 'say "hi" \\ end\n\ttab');
    }

    function testFuzz_URI_DescriptionRoundTrips(bytes memory raw) public {
        if (raw.length > 512) {
            assembly {
                mstore(raw, 512)
            }
        }
        for (uint256 i; i < raw.length; ++i) {
            raw[i] = bytes1(uint8(raw[i]) & 0x7f);
        }
        string memory desc = string(raw);
        TokenMetadata memory m = TokenMetadata(desc, "https://a.io", "ipfs://x");
        LaunchToken t = _deployRaw("A", "A", creator, address(this), m);

        string memory json = _decodeURI(t.tokenURI());
        assertEq(vm.parseJsonString(json, ".description"), desc);
    }

    function test_URI_EmptyMetadata() public {
        LaunchToken t = _deployRaw("A", "A", creator, address(this), TokenMetadata("", "", ""));
        assertEq(
            _decodeURI(t.tokenURI()),
            '{"name":"A","symbol":"A","description":"","image":"","external_url":""}'
        );
    }

    // ============================================================
    // Misc / edge cases
    // ============================================================

    function test_Recipient_CanBeEOA() public {
        LaunchToken t = _deployRaw("A", "A", creator, alice, _meta());
        assertEq(t.balanceOf(alice), 21_000_000 ether);
        vm.prank(alice);
        t.launch();
        assertTrue(t.launched());
    }

    function test_Creator_HasNoSpecialPowers() public {
        vm.prank(creator);
        vm.expectRevert(LaunchToken.OnlyInitialRecipient.selector);
        token.launch();
    }

    function test_RecipientToSelfWhileLocked() public {
        factory.send(token, address(factory), 1 ether);
        assertEq(token.balanceOf(address(factory)), 21_000_000 ether);
    }

    function test_SupplyConstants() public view {
        assertEq(token.MAX_NAME_LENGTH(), 32);
        assertEq(token.MAX_SYMBOL_LENGTH(), 12);
        assertEq(token.MAX_DESCRIPTION_LENGTH(), 512);
        assertEq(token.MAX_WEBSITE_LENGTH(), 256);
        assertEq(token.MAX_IMAGE_LENGTH(), 2048);
    }
}
