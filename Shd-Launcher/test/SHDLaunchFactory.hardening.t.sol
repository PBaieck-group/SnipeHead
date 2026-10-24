// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SHDLaunchFactory} from "../src/SHDLaunchFactory.sol";
import {LaunchToken, TokenMetadata} from "../src/SnipeLaunchToken.sol";
import {MockSHD, MockPair, MockV2Factory} from "./mocks/MockPulseX.sol";
import {FactoryBase} from "./SHDLaunchFactory.t.sol";

/*//////////////////////////////////////////////////////////////
  HARDENING TESTS  -  only covers what the existing suite does NOT.

  Offline (no RPC needed):
    forge test --match-path test/SHDLaunchFactory.hardening.t.sol \
               --no-match-contract HardeningForkTest -vv

  Fork (real PulseChain):
    RUN_FORK=1 forge test --match-contract HardeningForkTest -vvv

  Contents
    1. EvmScan                 bytecode walker (skips PUSH data + CBOR metadata)
    2. HardeningOpcodeTest     no PUSH0/MCOPY/TSTORE/TLOAD/BLOB* in what you deploy
    3. HardeningLockedTokenTest  burn-while-locked, tokens sent to factory,
                                 holder can't seed a pre-created pair
    4. HardeningInvariantTest  multi-token invariants: createToken (both modes),
                                 buy, sell, burn, donate, auto-graduation, liveness
    5. HardeningForkTest       SHD trust checks + real PulseX pair behaviour
//////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////
                        1. BYTECODE SCANNER
//////////////////////////////////////////////////////////////*/

library EvmScan {
    /// @dev Opcodes that do not exist on a Paris EVM.
    function forbidden(uint8 op) internal pure returns (bool) {
        return op == 0x5f // PUSH0        (Shanghai)
            || op == 0x5e // MCOPY        (Cancun)
            || op == 0x5d // TSTORE       (Cancun)
            || op == 0x5c // TLOAD        (Cancun)
            || op == 0x49 // BLOBHASH     (Cancun)
            || op == 0x4a; // BLOBBASEFEE (Cancun)
    }

    function opName(uint8 op) internal pure returns (string memory) {
        if (op == 0x5f) return "PUSH0 (Shanghai)";
        if (op == 0x5e) return "MCOPY (Cancun)";
        if (op == 0x5d) return "TSTORE (Cancun)";
        if (op == 0x5c) return "TLOAD (Cancun)";
        if (op == 0x49) return "BLOBHASH (Cancun)";
        if (op == 0x4a) return "BLOBBASEFEE (Cancun)";
        return "unknown";
    }

    /// @dev Index where the trailing solc CBOR metadata starts (or code.length if none detected).
    function codeEnd(bytes memory code) internal pure returns (uint256) {
        uint256 n = code.length;
        if (n < 2) return n;
        uint256 metaLen = (uint256(uint8(code[n - 2])) << 8) | uint256(uint8(code[n - 1]));
        if (metaLen + 2 > n) return n;
        uint8 first = uint8(code[n - 2 - metaLen]);
        if (first < 0xa1 || first > 0xa6) return n; // CBOR map header
        return n - 2 - metaLen;
    }

    /// @dev Walks instructions (skipping PUSH immediates), ignoring [exclStart, exclEnd).
    function scan(bytes memory code, uint256 exclStart, uint256 exclEnd)
        internal
        pure
        returns (uint256 hits, uint256 firstPc, uint8 firstOp)
    {
        uint256 end = codeEnd(code);
        uint256 pc;
        while (pc < end) {
            if (pc >= exclStart && pc < exclEnd) {
                pc = exclEnd;
                continue;
            }
            uint8 op = uint8(code[pc]);
            if (forbidden(op)) {
                if (hits == 0) {
                    firstPc = pc;
                    firstOp = op;
                }
                ++hits;
            }
            // PUSH1..PUSH32 = 0x60..0x7f, instruction length = 1 + (op - 0x5f)
            if (op >= 0x60 && op <= 0x7f) pc += uint256(op) - 0x5e;
            else ++pc;
        }
    }

    /// @dev Locates `needle` inside `hay` (used to find the token initcode embedded in the factory).
    function find(bytes memory hay, bytes memory needle) internal pure returns (bool, uint256) {
        uint256 nLen = needle.length;
        if (nLen < 32 || hay.length < nLen) return (false, 0);
        bytes32 want;
        assembly {
            want := mload(add(needle, 0x20))
        }
        bytes32 needleHash = keccak256(needle);
        uint256 last = hay.length - nLen;
        for (uint256 i; i <= last; ++i) {
            bytes32 w;
            assembly {
                w := mload(add(add(hay, 0x20), i))
            }
            if (w != want) continue;
            bytes32 h;
            assembly {
                h := keccak256(add(add(hay, 0x20), i), nLen)
            }
            if (h == needleHash) return (true, i);
        }
        return (false, 0);
    }

    /// @dev True if the dispatcher-style `PUSH4 <sel>` appears in the code.
    function containsSelector(bytes memory code, bytes4 sel) internal pure returns (bool) {
        uint256 end = code.length;
        // named `pos` not `pc` — Yul treats bare `pc` as the program-counter builtin
        uint256 pos;
        while (pos + 5 <= end) {
            uint8 op = uint8(code[pos]);
            if (op == 0x63) {
                bytes4 got;
                assembly {
                    got := and(
                        mload(add(add(code, 0x21), pos)),
                        0xffffffff00000000000000000000000000000000000000000000000000000000
                    )
                }
                if (got == sel) return true;
            }
            if (op >= 0x60 && op <= 0x7f) pos += uint256(op) - 0x5e;
            else ++pos;
        }
        return false;
    }
}

/*//////////////////////////////////////////////////////////////
                    2. OPCODE COMPATIBILITY
//////////////////////////////////////////////////////////////*/

/// @notice PulseChain may not support PUSH0 / Cancun opcodes. This checks the bytecode your
///         foundry.toml profile actually produces for BOTH contracts, including constructors
///         (creationCode) which a runtime-only scan would miss.
///         If foundry.toml does not say evm_version = "paris", these tests should fail.
contract HardeningOpcodeTest is FactoryBase {
    function _assertParis(string memory label, bytes memory code, bytes memory embedded) internal {
        uint256 s;
        uint256 e;
        if (embedded.length != 0) {
            (bool found, uint256 off) = EvmScan.find(code, embedded);
            if (found) {
                s = off;
                e = off + embedded.length;
            }
        }
        (uint256 hits, uint256 pc, uint8 op) = EvmScan.scan(code, s, e);
        if (hits != 0) {
            emit log_named_string("contract", label);
            emit log_named_uint("first forbidden pc", pc);
            emit log_named_string("opcode", EvmScan.opName(op));
            emit log_named_uint("total hits", hits);
        }
        assertEq(
            hits,
            0,
            string.concat(label, ": post-Paris opcode found. Set evm_version = \"paris\" and rebuild (forge clean)")
        );
    }

    /// @dev Scanner self-check so a passing result above actually means something.
    function test_scanner_selfCheck() public pure {
        // bare PUSH0 -> 1 hit
        (uint256 hits,,) = EvmScan.scan(hex"5f", 0, 0);
        assertEq(hits, 1);
        // PUSH1 0x5f -> 0x5f is data, not an opcode
        (hits,,) = EvmScan.scan(hex"605f", 0, 0);
        assertEq(hits, 0);
        // PUSH32 of 32 x 0x5f -> all data
        bytes memory p32 = abi.encodePacked(bytes1(0x7f), bytes32(type(uint256).max / 0xff * 0x5f));
        (hits,,) = EvmScan.scan(p32, 0, 0);
        assertEq(hits, 0);
        // PUSH32 data then a real MCOPY
        bytes memory withMcopy = abi.encodePacked(p32, bytes1(0x5e));
        (hits,,) = EvmScan.scan(withMcopy, 0, 0);
        assertEq(hits, 1);
        // exclusion range hides a hit
        (hits,,) = EvmScan.scan(hex"00005f00", 2, 3);
        assertEq(hits, 0);
    }

    function test_opcodes_tokenCreationCode() public {
        _assertParis("LaunchToken creationCode", type(LaunchToken).creationCode, "");
    }

    function test_opcodes_tokenRuntime_deployedByFactory() public {
        address t = _curve();
        _assertParis("LaunchToken runtime (factory-deployed)", t.code, "");
    }

    function test_opcodes_factoryCreationCode() public {
        _assertParis("SHDLaunchFactory creationCode", type(SHDLaunchFactory).creationCode, type(LaunchToken).creationCode);
    }

    function test_opcodes_factoryRuntime() public {
        _assertParis("SHDLaunchFactory runtime", address(f).code, type(LaunchToken).creationCode);
    }

    /// @dev The factory embeds the token initcode as data. If we cannot locate it, the factory
    ///      scans above may false-positive on that data - this test tells you why.
    function test_opcodes_embeddedTokenInitcodeIsLocatable() public view {
        (bool found,) = EvmScan.find(address(f).code, type(LaunchToken).creationCode);
        assertTrue(found, "token initcode not found in factory runtime: factory opcode scan may be unreliable");
    }
}

/*//////////////////////////////////////////////////////////////
              3. LOCKED-TOKEN EDGE CASES (offline)
//////////////////////////////////////////////////////////////*/

contract HardeningLockedTokenTest is FactoryBase {
    /// @dev The whole anti-grief argument for PoolNotEmpty: while locked, no holder can put
    ///      tokens into a pre-created pair, so the pair's token reserve is always 0 at seeding.
    function test_locked_holderCannotSeedPreCreatedPair() public {
        address t = _curve();
        address pair = MockV2Factory(V2F_ADDR).createPair(t, SHD_ADDR);
        _buy(alice, t, 10_000 ether);

        // direct transfer
        vm.startPrank(alice);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        LaunchToken(t).transfer(pair, 1);

        // via allowance
        LaunchToken(t).approve(attacker, 1);
        vm.stopPrank();
        vm.prank(attacker);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        LaunchToken(t).transferFrom(alice, pair, 1);

        // attacker sync() cannot create a token-side reserve
        MockPair(pair).sync();
        (uint256 tr,) = _reserves(t);
        assertEq(tr, 0, "token-side reserve must stay 0 while locked");

        // graduation still succeeds
        _graduate(t);
        (,, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tokenRes,) = _reserves(t);
        (, uint256 sold,,) = f.getCurve(t);
        assertEq(tokenRes, CURVE_SUPPLY - sold);
    }

    /// @dev Existing donation test only donates SHD. Tokens CAN be sent to the factory while
    ///      locked (recipient == factory). Graduation must use accounting, not balanceOf.
    function test_locked_tokensDonatedToFactoryDoNotBreakGraduation() public {
        address t = _curve();
        LaunchToken tk = LaunchToken(t);

        uint256 got = _buy(alice, t, 100_000 ether);
        uint256 donated = got / 3;
        vm.prank(alice);
        tk.transfer(address(f), donated);

        (, uint256 soldBefore,,) = f.getCurve(t);
        assertEq(tk.balanceOf(address(f)), SUPPLY - soldBefore + donated);

        _graduate(t);

        (, uint256 sold, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY - sold, "pool must be seeded from accounting, not balanceOf");
        assertEq(sr, TARGET - REWARD);
        assertEq(tk.balanceOf(address(f)), donated, "donation stays stuck (no rescue, by design)");
        assertEq(tk.balanceOf(creator), CREATOR_ALLOC);
        assertEq(
            tk.balanceOf(creator) + tk.balanceOf(alice) + tk.balanceOf(bob) + tr + tk.balanceOf(address(f)),
            SUPPLY,
            "token conservation"
        );
    }

    /// @dev burn() works while locked. Burned tokens stay counted in tokensSold; nobody may be
    ///      able to sell more than they actually hold, curve stays solvent, graduation works.
    function test_burnWhileLocked_curveStaysSolventAndGraduates() public {
        address t = _curve();
        LaunchToken tk = LaunchToken(t);

        uint256 aliceGot = _buy(alice, t, 1_000_000 ether);
        uint256 bobGot = _buy(bob, t, 500_000 ether);

        uint256 burnAmt = aliceGot / 2;
        vm.prank(alice);
        tk.burn(burnAmt);

        (uint256 collected, uint256 sold,,) = f.getCurve(t);
        assertEq(sold, aliceGot + bobGot, "burn must not touch curve accounting");
        assertEq(tk.totalSupply(), SUPPLY - burnAmt);

        // Alice cannot sell tokens she burned, even though `sold` still counts them
        vm.startPrank(alice);
        tk.approve(address(f), aliceGot);
        vm.expectRevert();
        f.sell(t, aliceGot, 0, 0);
        vm.stopPrank();

        // Curve could still pay out for every token that was ever sold
        assertLe(f.quoteSell(t, sold), collected, "curve insolvent after burn");

        // Both holders can still exit with what they hold
        assertGt(_sell(bob, t, bobGot), 0);
        assertGt(_sell(alice, t, aliceGot - burnAmt), 0);

        // Curve then graduates normally
        _graduate(t);
        (, uint256 soldEnd, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        assertEq(soldEnd, burnAmt + _held(t), "sold == burned + held by buyers");

        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY - soldEnd);
        assertEq(sr, TARGET - REWARD);
        assertEq(tk.totalSupply(), SUPPLY - burnAmt);
        assertEq(
            tk.balanceOf(creator) + tk.balanceOf(alice) + tk.balanceOf(bob) + tr + tk.balanceOf(address(f)),
            tk.totalSupply(),
            "conservation after burn + graduation"
        );
    }

    function _held(address t) internal view returns (uint256) {
        return LaunchToken(t).balanceOf(alice) + LaunchToken(t).balanceOf(bob);
    }

    function testFuzz_burnThenExit_curveStaysSolvent(uint256 buyAmt, uint256 burnBps) public {
        buyAmt = bound(buyAmt, 1 ether, 4_900_000 ether); // stays below graduation window
        burnBps = bound(burnBps, 0, 10_000);

        address t = _curve();
        uint256 got = _buy(alice, t, buyAmt);
        uint256 burnAmt = got * burnBps / 10_000;
        if (burnAmt > 0) {
            vm.prank(alice);
            LaunchToken(t).burn(burnAmt);
        }
        uint256 rem = got - burnAmt;
        if (rem > 0 && f.quoteSell(t, rem) > 0) _sell(alice, t, rem);

        (uint256 collected, uint256 sold,,) = f.getCurve(t);
        assertLe(f.quoteSell(t, sold), collected, "insolvent");
        assertEq(shd.balanceOf(address(f)), collected, "custody != accounting");
    }
}

/*//////////////////////////////////////////////////////////////
          4. MULTI-TOKEN INVARIANTS (create/buy/sell/burn/donate)
//////////////////////////////////////////////////////////////*/

/// @dev Existing handler: one token, buy+sell only. This one drives MANY tokens in BOTH modes,
///      plus burn and direct-to-factory donations, and tracks liveness failures.
contract MultiTokenHandler is Test {
    address internal constant SHD_ADDR = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;
    uint256 internal constant MAX_TOKENS = 6;

    SHDLaunchFactory public immutable f;
    MockSHD internal shd = MockSHD(SHD_ADDR);

    address[] public tokens;
    address[] public actors;
    address[] public creators;

    mapping(address => uint256) public burned; // token => total burned
    mapping(address => uint256) public burnedByActors; // token => burned by actors
    mapping(address => uint256) public donated; // token => sent straight to factory
    mapping(address => uint256) public instantShd; // token => SHD paired (Instant only)

    uint256 public createFailures;
    uint256 public buyFailures;
    uint256 public sellFailures;

    constructor(SHDLaunchFactory f_) {
        f = f_;
        for (uint256 i; i < 5; ++i) {
            actors.push(makeAddr(string.concat("hactor", vm.toString(i))));
        }
        for (uint256 i; i < 3; ++i) {
            creators.push(makeAddr(string.concat("hcreator", vm.toString(i))));
        }
    }

    function tokensLength() external view returns (uint256) {
        return tokens.length;
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    // ---------------------------------------------------------------- create
    function createCurve(uint256 seed) external {
        _create(seed, SHDLaunchFactory.Mode.BondingCurve, 0);
    }

    function createInstant(uint256 seed, uint256 shdAmount) external {
        shdAmount = bound(shdAmount, 1 ether, 5_000_000 ether);
        _create(seed, SHDLaunchFactory.Mode.Instant, shdAmount);
    }

    function _create(uint256 seed, SHDLaunchFactory.Mode mode, uint256 shdAmount) internal {
        if (tokens.length >= MAX_TOKENS) return;
        address c = creators[seed % creators.length];
        uint256 need = f.CREATION_FEE() + shdAmount;
        shd.mint(c, need);
        vm.startPrank(c);
        shd.approve(address(f), need);
        try f.createToken("H", "H", bytes32(seed), TokenMetadata("", "", ""), mode, shdAmount, 0) returns (address t) {
            tokens.push(t);
            if (mode == SHDLaunchFactory.Mode.Instant) instantShd[t] = shdAmount;
        } catch {
            ++createFailures;
        }
        vm.stopPrank();
    }

    // ------------------------------------------------------------------ curve
    function buy(uint256 tSeed, uint256 aSeed, uint256 amount) external {
        address t = _pickCurve(tSeed);
        if (t == address(0)) return;
        (,, bool grad,) = f.getCurve(t);
        if (grad) return;

        address a = actors[aSeed % actors.length];
        amount = bound(amount, 1 ether, 3_000_000 ether);
        shd.mint(a, amount);
        vm.startPrank(a);
        shd.approve(address(f), amount);
        // On a live curve with funds + allowance, a buy must NEVER revert.
        try f.buy(t, amount, 0, 0) {} catch {
            ++buyFailures;
        }
        vm.stopPrank();
    }

    function sell(uint256 tSeed, uint256 aSeed, uint256 amount) external {
        address t = _pickCurve(tSeed);
        if (t == address(0)) return;
        (,, bool grad,) = f.getCurve(t);
        if (grad) return;

        address a = actors[aSeed % actors.length];
        uint256 bal = LaunchToken(t).balanceOf(a);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        bool shouldWork = f.quoteSell(t, amount) > 0; // tiny sells legitimately revert ZeroOutput
        vm.startPrank(a);
        LaunchToken(t).approve(address(f), amount);
        try f.sell(t, amount, 0, 0) {} catch {
            if (shouldWork) ++sellFailures;
        }
        vm.stopPrank();
    }

    // ---------------------------------------------------------- burn / donate
    function burn(uint256 tSeed, uint256 aSeed, uint256 amount) external {
        if (tokens.length == 0) return;
        address t = tokens[tSeed % tokens.length];
        address a = actors[aSeed % actors.length];
        uint256 bal = LaunchToken(t).balanceOf(a);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(a);
        LaunchToken(t).burn(amount);
        burned[t] += amount;
        burnedByActors[t] += amount;
    }

    function donate(uint256 tSeed, uint256 aSeed, uint256 amount) external {
        if (tokens.length == 0) return;
        address t = tokens[tSeed % tokens.length];
        address a = actors[aSeed % actors.length];
        uint256 bal = LaunchToken(t).balanceOf(a);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(a);
        LaunchToken(t).transfer(address(f), amount);
        donated[t] += amount;
    }

    function _pickCurve(uint256 seed) internal view returns (address) {
        uint256 n = tokens.length;
        if (n == 0) return address(0);
        for (uint256 i; i < n; ++i) {
            address t = tokens[(seed + i) % n];
            if (f.modeOf(t) == SHDLaunchFactory.Mode.BondingCurve) return t;
        }
        return address(0);
    }
}

contract HardeningInvariantTest is Test {
    address internal constant SHD_ADDR = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;
    address internal constant V2F_ADDR = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;
    address internal constant BURN_ADDR = 0x0000000000000000000000000000000000000369;
    address internal constant BUY_AND_BURN = 0x3677e61A7a9E79Fe45a882C201365C5165A5540e;

    uint256 internal constant SUPPLY = 21_000_000 ether;
    uint256 internal constant CURVE_SUPPLY = 19_950_000 ether;
    uint256 internal constant TARGET = 5_000_000 ether;
    uint256 internal constant REWARD = 50_000 ether;
    uint256 internal constant FEE = 10 ether;
    uint256 internal constant DUST = 1e6;

    SHDLaunchFactory internal f;
    MockSHD internal shd = MockSHD(SHD_ADDR);
    MultiTokenHandler internal handler;

    function setUp() public {
        vm.warp(1_800_000_000);
        vm.etch(SHD_ADDR, address(new MockSHD()).code);
        vm.etch(V2F_ADDR, address(new MockV2Factory()).code);
        f = new SHDLaunchFactory();
        handler = new MultiTokenHandler(f);

        targetContract(address(handler));
        bytes4[] memory sels = new bytes4[](6);
        sels[0] = MultiTokenHandler.createCurve.selector;
        sels[1] = MultiTokenHandler.createInstant.selector;
        sels[2] = MultiTokenHandler.buy.selector;
        sels[3] = MultiTokenHandler.sell.selector;
        sels[4] = MultiTokenHandler.burn.selector;
        sels[5] = MultiTokenHandler.donate.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function _reserves(address t) internal view returns (MockPair p, uint256 tokenRes, uint256 shdRes) {
        p = MockPair(MockV2Factory(V2F_ADDR).getPair(t, SHD_ADDR));
        (uint112 r0, uint112 r1,) = p.getReserves();
        (tokenRes, shdRes) = t < SHD_ADDR ? (r0, r1) : (r1, r0);
    }

    /// @dev Custody: factory SHD == sum(collected of LIVE curves); factory token balance per token
    ///      == (SUPPLY - sold) for live curves, and only donations for graduated/instant tokens.
    /// forge-config: default.invariant.runs = 500
    /// forge-config: default.invariant.depth = 150
    function invariant_custodyAcrossAllTokens() public view {
        uint256 n = handler.tokensLength();
        uint256 liveCollected;
        for (uint256 i; i < n; ++i) {
            address t = handler.tokens(i);
            LaunchToken tk = LaunchToken(t);

            if (f.modeOf(t) == SHDLaunchFactory.Mode.Instant) {
                assertEq(tk.balanceOf(address(f)), handler.donated(t), "instant: factory token residue");
                assertTrue(tk.launched(), "instant token not launched");
                continue;
            }

            (uint256 collected, uint256 sold, bool grad,) = f.getCurve(t);
            if (grad) {
                assertEq(tk.balanceOf(address(f)), handler.donated(t), "graduated: factory token residue");
                assertTrue(tk.launched(), "graduated but locked");
                assertGe(collected + DUST, TARGET, "graduated too early");
                assertLe(collected, TARGET, "graduation overshoot");
            } else {
                liveCollected += collected;
                assertEq(tk.balanceOf(address(f)), SUPPLY - sold + handler.donated(t), "live: token custody");
                assertFalse(tk.launched(), "live curve already unlocked");
                assertLt(collected + DUST, TARGET, "live curve inside graduation window");
            }
        }
        assertEq(shd.balanceOf(address(f)), liveCollected, "factory SHD != sum(live collected)");
    }

    /// @dev Total supply only ever shrinks by burns; for curves, tokensSold is fully explained by
    ///      what actors still hold + what they burned + what they sent straight to the factory.
    /// forge-config: default.invariant.runs = 500
    /// forge-config: default.invariant.depth = 150
    function invariant_supplyAndSoldAccounting() public view {
        uint256 n = handler.tokensLength();
        uint256 na = handler.actorsLength();
        for (uint256 i; i < n; ++i) {
            address t = handler.tokens(i);
            LaunchToken tk = LaunchToken(t);
            assertEq(tk.totalSupply(), SUPPLY - handler.burned(t), "totalSupply != SUPPLY - burned");

            if (f.modeOf(t) != SHDLaunchFactory.Mode.BondingCurve) continue;
            (, uint256 sold,,) = f.getCurve(t);
            uint256 held;
            for (uint256 j; j < na; ++j) {
                held += tk.balanceOf(handler.actors(j));
            }
            assertEq(held + handler.burnedByActors(t) + handler.donated(t), sold, "sold != held+burned+donated");
        }
    }

    /// @dev Every seeded pool: exact reserves from accounting, LP fully burned, none left in factory.
    /// forge-config: default.invariant.runs = 500
    /// forge-config: default.invariant.depth = 150
    function invariant_seededPoolsAreExactAndLpBurned() public view {
        uint256 n = handler.tokensLength();
        for (uint256 i; i < n; ++i) {
            address t = handler.tokens(i);
            bool instant = f.modeOf(t) == SHDLaunchFactory.Mode.Instant;
            (uint256 collected, uint256 sold, bool grad,) = f.getCurve(t);
            if (!instant && !grad) continue;

            (MockPair p, uint256 tr, uint256 sr) = _reserves(t);
            if (instant) {
                assertEq(tr, CURVE_SUPPLY, "instant token reserve");
                assertEq(sr, handler.instantShd(t), "instant shd reserve");
            } else {
                assertEq(tr, CURVE_SUPPLY - sold, "graduated token reserve");
                assertEq(sr, collected - REWARD, "graduated shd reserve");
            }
            assertEq(p.balanceOf(address(f)), 0, "factory holds LP");
            assertGt(p.balanceOf(BURN_ADDR), 0, "LP not burned");
        }
    }

    /// @dev Liveness: nothing the handler did on a live curve should have reverted unexpectedly.
    /// forge-config: default.invariant.runs = 500
    /// forge-config: default.invariant.depth = 150
    function invariant_noUnexpectedReverts() public view {
        assertEq(handler.createFailures(), 0, "createToken reverted unexpectedly");
        assertEq(handler.buyFailures(), 0, "buy on a live curve reverted unexpectedly");
        assertEq(handler.sellFailures(), 0, "sell with positive quote reverted unexpectedly");
    }

    /// @dev Every created token paid exactly one creation fee to BuyAndBurn, nothing else goes there.
    /// forge-config: default.invariant.runs = 500
    /// forge-config: default.invariant.depth = 150
    function invariant_feesConserved() public view {
        assertEq(shd.balanceOf(BUY_AND_BURN), handler.tokensLength() * FEE, "BuyAndBurn SHD != tokens * fee");
    }
}

/*//////////////////////////////////////////////////////////////
                     5. FORK: SHD + REAL PULSEX
//////////////////////////////////////////////////////////////*/

interface IERC20Hard {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

interface IPairHard {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract HardeningForkTest is Test {
    IERC20Hard internal constant SHD = IERC20Hard(0xB95bC84f9B6D0373642D586b81979B067572f7bc);
    address internal constant SHD_ADDR = 0xB95bC84f9B6D0373642D586b81979B067572f7bc;
    address internal constant BURN = 0x0000000000000000000000000000000000000369;
    uint256 internal constant SUPPLY = 21_000_000 ether;
    uint256 internal constant CREATOR_ALLOC = 1_050_000 ether;
    uint256 internal constant CURVE_SUPPLY = 19_950_000 ether;
    uint256 internal constant TARGET = 5_000_000 ether;
    uint256 internal constant FEE = 10 ether;

    SHDLaunchFactory internal f;
    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        if (!vm.envOr("RUN_FORK", false)) vm.skip(true);
        vm.createSelectFork("pulsechain");
        f = new SHDLaunchFactory();
    }

    // ================================================================ helpers

    function _fund(address who, uint256 amount) internal {
        deal(address(SHD), who, amount);
        vm.prank(who);
        SHD.approve(address(f), type(uint256).max);
    }

    function _createBonding() internal returns (address t) {
        _fund(creator, FEE);
        vm.prank(creator);
        t = f.createToken(
            "Fork", "FRK", bytes32(0), TokenMetadata("", "", ""), SHDLaunchFactory.Mode.BondingCurve, 0, 0
        );
    }

    function _createInstant(uint256 shdAmount) internal returns (address t) {
        _fund(creator, FEE + shdAmount);
        vm.prank(creator);
        t = f.createToken(
            "Fork", "FRK", bytes32(0), TokenMetadata("", "", ""), SHDLaunchFactory.Mode.Instant, shdAmount, 0
        );
    }

    function _pair(address t) internal view returns (IPairHard) {
        return IPairHard(f.FACTORY().getPair(t, address(SHD)));
    }

    function _reserves(address t) internal view returns (uint256 tokenRes, uint256 shdRes) {
        IPairHard p = _pair(t);
        (uint112 r0, uint112 r1,) = p.getReserves();
        (tokenRes, shdRes) = p.token0() == t ? (r0, r1) : (r1, r0);
    }

    /// @dev Uniswap-V2 style output at 0.3% fee (PulseX fee is <= this, so 95% of it always passes K).
    function _out(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 inWithFee = amountIn * 997;
        return inWithFee * reserveOut / (reserveIn * 1000 + inWithFee);
    }

    function _tryUint(address target, string memory sig) internal view returns (bool ok, uint256 v) {
        (bool s, bytes memory r) = target.staticcall(abi.encodeWithSignature(sig));
        if (s && r.length >= 32) {
            ok = true;
            v = abi.decode(r, (uint256));
        }
    }

    // ============================================================ SHD trust

    /// @notice The factory holds user SHD. SHD must not be an upgradeable proxy.
    function test_shd_isNotUpgradeableProxy() public {
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 beaconSlot = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
        assertEq(vm.load(SHD_ADDR, implSlot), bytes32(0), "EIP-1967 implementation slot set: SHD is upgradeable");
        assertEq(vm.load(SHD_ADDR, adminSlot), bytes32(0), "EIP-1967 admin slot set");
        assertEq(vm.load(SHD_ADDR, beaconSlot), bytes32(0), "EIP-1967 beacon slot set");
    }

    /// @notice Heuristic: no privileged-looking selectors in SHD's dispatcher. A failure does NOT
    ///         prove malice (e.g. mint() locked behind a renounced owner) - read the verified
    ///         source on the explorer - but it must be understood before launch.
    function test_shd_noPrivilegedSelectorsInBytecode() public {
        bytes memory code = SHD_ADDR.code;
        string[16] memory sigs = [
            "mint(address,uint256)",
            "pause()",
            "unpause()",
            "blacklist(address)",
            "addToBlacklist(address)",
            "addBlacklist(address)",
            "setBlacklist(address,bool)",
            "blockAddress(address)",
            "freeze(address)",
            "upgradeTo(address)",
            "upgradeToAndCall(address,bytes)",
            "setFee(uint256)",
            "setTax(uint256)",
            "setTaxFee(uint256)",
            "setFees(uint256,uint256)",
            "forceTransfer(address,address,uint256)"
        ];
        uint256 found;
        for (uint256 i; i < sigs.length; ++i) {
            if (EvmScan.containsSelector(code, bytes4(keccak256(bytes(sigs[i]))))) {
                emit log_named_string("PRIVILEGED-LOOKING SELECTOR PRESENT", sigs[i]);
                ++found;
            }
        }
        assertEq(found, 0, "SHD exposes privileged-looking functions: review source before launch");
    }

    function test_shd_decimalsIs18AndNotPaused() public {
        (bool ok, uint256 d) = _tryUint(SHD_ADDR, "decimals()");
        assertTrue(ok, "decimals() missing");
        assertEq(d, 18, "curve constants + fee assume 18 decimals");

        (bool hasPaused, uint256 p) = _tryUint(SHD_ADDR, "paused()");
        if (hasPaused) {
            emit log("SHD has paused()");
            assertEq(p, 0, "SHD is paused");
        }

        // informational
        (bool hasOwner, uint256 o) = _tryUint(SHD_ADDR, "owner()");
        if (hasOwner) emit log_named_address("SHD owner()", address(uint160(o)));
        emit log_named_uint("SHD runtime size", SHD_ADDR.code.length);
    }

    // ===================================== real PulseX pair: contract callers

    /// @notice pair.mint(to, senderOrigin): the factory passes msg.sender. If the real pair ever
    ///         requires senderOrigin == tx.origin, smart-wallet creators (Safe, etc.) are blocked.
    ///         The mock ignores this argument, so only the real pair can answer.
    function test_fork_instant_fromContractCreator_msgSenderDiffersFromOrigin() public {
        address wallet = makeAddr("smartWallet");
        address eoa = makeAddr("eoaOrigin");
        vm.etch(wallet, hex"00"); // give it code so it really is a contract
        _fund(wallet, FEE + 100_000 ether);

        vm.prank(wallet, eoa); // msg.sender = wallet, tx.origin = eoa
        address t = f.createToken(
            "Fork", "FRK", bytes32(0), TokenMetadata("", "", ""), SHDLaunchFactory.Mode.Instant, 100_000 ether, 0
        );

        assertTrue(LaunchToken(t).launched());
        assertEq(LaunchToken(t).balanceOf(wallet), CREATOR_ALLOC);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY);
        assertEq(sr, 100_000 ether);
    }

    function test_fork_graduation_triggeredByContractBuyer_originDiffers() public {
        address t = _createBonding();
        address wallet = makeAddr("buyerWallet");
        address eoa = makeAddr("buyerOrigin");
        vm.etch(wallet, hex"00");
        _fund(wallet, TARGET);

        vm.prank(wallet, eoa);
        f.buy(t, TARGET, 0, 0);

        (, uint256 sold, bool grad,) = f.getCurve(t);
        assertTrue(grad);
        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY - sold);
        assertEq(sr, TARGET - 50_000 ether);
        assertTrue(LaunchToken(t).launched());
    }

    // =========================================== real PulseX pair: trading + LP

    /// @notice After an Instant launch the token must actually trade on the real pair, both ways.
    function test_fork_instant_tradableOnRealPair() public {
        address t = _createInstant(100_000 ether);
        IPairHard p = _pair(t);
        bool tokenIs0 = p.token0() == t;

        // --- SHD -> token
        uint256 shdIn = 1_000 ether;
        (uint256 rt, uint256 rs) = _reserves(t);
        uint256 out = _out(shdIn, rs, rt) * 95 / 100;
        assertGt(out, 0);
        deal(address(SHD), alice, shdIn);
        vm.startPrank(alice);
        SHD.transfer(address(p), shdIn);
        p.swap(tokenIs0 ? out : 0, tokenIs0 ? 0 : out, alice, "");
        vm.stopPrank();
        assertEq(LaunchToken(t).balanceOf(alice), out, "buy swap failed to deliver tokens");

        // --- token -> SHD (creator sells part of their 5%)
        uint256 tokIn = 10_000 ether;
        (rt, rs) = _reserves(t);
        uint256 shdOut = _out(tokIn, rt, rs) * 95 / 100;
        assertGt(shdOut, 0);
        uint256 before = SHD.balanceOf(creator);
        vm.startPrank(creator);
        LaunchToken(t).transfer(address(p), tokIn);
        p.swap(tokenIs0 ? 0 : shdOut, tokenIs0 ? shdOut : 0, creator, "");
        vm.stopPrank();
        assertEq(SHD.balanceOf(creator) - before, shdOut, "sell swap failed to deliver SHD");
    }

    function _assertLpBurned(address t) internal view {
        IPairHard p = _pair(t);
        uint256 ts = p.totalSupply();
        assertGt(ts, 0);
        assertEq(p.balanceOf(address(f)), 0, "factory still holds LP");
        assertEq(p.balanceOf(creator), 0, "creator holds LP");
        // >= 99.9999% at the burn address (the remainder is the pair's MINIMUM_LIQUIDITY lock)
        assertGe(p.balanceOf(BURN) * 1_000_000, ts * 999_999, "LP not (almost entirely) burned");
    }

    function test_fork_lpFullyBurned_instantAndGraduated() public {
        address ti = _createInstant(100_000 ether);
        _assertLpBurned(ti);

        address tb = _createBonding();
        _fund(alice, TARGET);
        vm.prank(alice);
        f.buy(tb, TARGET, 0, 0);
        _assertLpBurned(tb);
    }

    // ================================== real PulseX pair: pre-creation attacks

    /// @notice Existing fork test donates 1 wei. Here the attacker pre-creates the pair for the
    ///         (predictable) token address and donates 1M SHD. Instant launch must still succeed
    ///         and the donation is simply absorbed into the burned pool.
    ///
    ///         Note: real PulseX `pair.sync()` calls `balanceOf` on both tokens and reverts when
    ///         the predicted token has no code yet. That is fine — Uniswap-V2 `mint` uses
    ///         `balanceOf` (not the stored reserves) to size liquidity, so a plain transfer of
    ///         SHD into the pair is enough for the donation to be absorbed.
    function test_fork_instant_survivesLargeDonationToPrecreatedPair() public {
        address predicted = vm.computeCreateAddress(address(f), vm.getNonce(address(f)));

        (bool ok, bytes memory r) = address(f.FACTORY())
            .call(abi.encodeWithSignature("createPair(address,address)", predicted, address(SHD)));
        if (!ok) {
            emit log("real V2 factory refuses pre-creating a pair for an undeployed token (attack not possible)");
            return;
        }
        address pair = abi.decode(r, (address));

        deal(address(SHD), attacker, 1_000_000 ether);
        vm.prank(attacker);
        SHD.transfer(pair, 1_000_000 ether);
        // deliberately no sync(): it would revert on the undeployed token; mint does not need it

        address t = _createInstant(100_000 ether);
        assertEq(t, predicted, "token address prediction (factory nonce) broke");

        (uint256 tr, uint256 sr) = _reserves(t);
        assertEq(tr, CURVE_SUPPLY);
        assertEq(sr, 1_100_000 ether, "donation must be absorbed into the pool");
        assertTrue(LaunchToken(t).launched());
        _assertLpBurned(t);
    }

    /// @notice On the REAL pair: while locked, a holder cannot push tokens into a pre-created pair.
    function test_fork_locked_holderCannotSeedPrecreatedPair() public {
        address t = _createBonding();
        address pair = f.FACTORY().createPair(t, address(SHD));

        _fund(alice, 100_000 ether);
        vm.prank(alice);
        f.buy(t, 100_000 ether, 0, 0);

        vm.startPrank(alice);
        vm.expectRevert(LaunchToken.TransferWhileLocked.selector);
        LaunchToken(t).transfer(pair, 1);
        vm.stopPrank();

        IPairHard(pair).sync();
        (uint112 r0, uint112 r1,) = IPairHard(pair).getReserves();
        uint256 tokenSide = IPairHard(pair).token0() == t ? r0 : r1;
        assertEq(tokenSide, 0, "token reserve must be 0 while locked");
    }
}
