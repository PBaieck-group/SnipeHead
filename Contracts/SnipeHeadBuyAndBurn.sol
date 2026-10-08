// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title SnipeHeadBuyAndBurn
 * @notice Permissionless buy-and-burn for SNIPEHEAD (SHD) on PulseChain.
 *         Anyone can send PLS (or already-held WPLS) and the contract will:
 *           1. Wrap all native PLS held → WPLS
 *           2. Swap up to MAX_BUY_BPS of the pool's WPLS reserve → SHD on PulseX V1
 *           3. Call SHD.burn() on the received tokens
 *
 *         No owner. No pause. No rescue. Fully immutable.
 *
 * Addresses (PulseChain mainnet):
 *   SHD   : 0xB95bC84f9B6D0373642D586b81979B067572f7bc
 *   WPLS  : 0xA1077a294dDE1B09bB078844df40758a5D0f9a27
 *   Router: 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02  (PulseX V1)
 *
 * Security notes:
 *   - ReentrancyGuard on every state-changing entry point.
 *   - SafeERC20 for approvals; allowance is reset to 0 after the swap.
 *   - On-chain TWAP price floor (PulseX pair cumulative price, ~30 min window):
 *     the swap can never execute worse than MAX_SLIPPAGE_BPS below the TWAP,
 *     no matter what minShdOut the caller passes. This caps sandwich losses.
 *   - Per-call size cap (MAX_BUY_BPS of the pool's WPLS reserve). Big deposits are
 *     drip-fed over several calls instead of slamming a thin pool in one trade.
 *     Leftover WPLS stays in the contract and is used by later buyAndBurn() calls.
 *   - Custom errors instead of revert strings (cheaper, easier to decode).
 *   - Native PLS sent via receive() or forced in is wrapped on the next call.
 */

interface IWPLS is IERC20 {
    function deposit() external payable;
}

interface ISnipeHead is IERC20 {
    function burn(uint256 value) external;
}

interface IPulseXFactory {
    function getPair(address a, address b) external view returns (address);
}

interface IPulseXPair {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
}

interface IPulseXRouter {
    function factory() external view returns (address);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

contract SnipeHeadBuyAndBurn is ReentrancyGuard {
    using SafeERC20 for IWPLS;

    // ------------------------------------------------------------------
    // Immutable addresses (PulseChain)
    // ------------------------------------------------------------------
    ISnipeHead public constant SHD =
        ISnipeHead(0xB95bC84f9B6D0373642D586b81979B067572f7bc);

    IWPLS public constant WPLS =
        IWPLS(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);

    IPulseXRouter public constant ROUTER =
        IPulseXRouter(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02);

    // ------------------------------------------------------------------
    // TWAP oracle config
    // ------------------------------------------------------------------
    /// @notice Minimum averaging window for the TWAP.
    uint256 public constant TWAP_WINDOW = 30 minutes;

    /// @notice Max allowed shortfall vs TWAP (fee + price impact + drift + tolerated MEV).
    ///         500 = 5%. Lower it (e.g. 200-300) if the SHD/WPLS pool is deep.
    uint256 public constant MAX_SLIPPAGE_BPS = 500;

    /// @notice Max WPLS spent per call, as a share of the pool's WPLS reserve.
    ///         200 = 2% (≈2.3% execution shortfall incl. fee, ≈4% end-price move), which
    ///         leaves headroom under MAX_SLIPPAGE_BPS. Anything above the cap stays in the
    ///         contract and is spent by later calls.
    uint256 public constant MAX_BUY_BPS = 200;

    uint256 private constant BPS = 10_000;

    IPulseXPair public immutable PAIR;
    bool public immutable WPLS_IS_TOKEN0;

    struct Observation {
        uint32 timestamp;
        uint256 cumulative; // cumulative price of WPLS quoted in SHD (UQ112x112 * seconds)
    }

    /// @dev `oldObs` is the reference point for the TWAP, `newObs` is the next one.
    Observation public oldObs;
    Observation public newObs;

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------
    error DeadlineExpired();
    error PairNotFound();
    error OracleNotReady();
    error NothingToSwap();
    error ZeroSHDReceived();
    error NothingToBurn();
    error SlippageExceeded();

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event BuyAndBurn(
        address indexed caller,
        uint256 plsWrapped,
        uint256 wplsUsed,
        uint256 shdBurned
    );

    event BurnStuckSHD(address indexed caller, uint256 amount);
    event ObservationRolled(uint32 timestamp, uint256 cumulative);

    // ------------------------------------------------------------------
    // On-chain counter (nice for dashboards)
    // ------------------------------------------------------------------
    uint256 public totalBurned;

    // ------------------------------------------------------------------
    // Constructor – locate the pair and record the first observation
    // ------------------------------------------------------------------
    constructor() {
        address pair = IPulseXFactory(ROUTER.factory()).getPair(
            address(WPLS),
            address(SHD)
        );
        if (pair == address(0)) revert PairNotFound();

        bool isToken0 = IPulseXPair(pair).token0() == address(WPLS);
        PAIR = IPulseXPair(pair);
        WPLS_IS_TOKEN0 = isToken0;

        newObs = _observe(IPulseXPair(pair), isToken0);
    }

    // ------------------------------------------------------------------
    // Main entry point
    // ------------------------------------------------------------------

    /**
     * @notice Buy SHD with PLS + any WPLS already in this contract, then burn it.
     *         At most MAX_BUY_BPS of the pool's WPLS reserve is spent per call; the rest
     *         stays queued in the contract. Call again (with 0 value is fine) to continue.
     * @param minShdOut  Your own minimum SHD out. The contract also enforces a TWAP-based
     *                   floor, so the effective minimum is max(minShdOut, twapFloor).
     *                   Pass a tighter value than the floor if you can.
     * @param deadline   Unix timestamp after which the swap reverts.
     */
    function buyAndBurn(
        uint256 minShdOut,
        uint256 deadline
    ) external payable nonReentrant {
        if (block.timestamp > deadline) revert DeadlineExpired();

        // 1. Wrap ALL native PLS held (msg.value + anything sent earlier/forced in)
        uint256 plsWrapped = address(this).balance;
        if (plsWrapped > 0) {
            WPLS.deposit{value: plsWrapped}();
        }

        // 2. Spend the WPLS we hold, capped to a share of the pool so a thin pool
        //    isn't hit with one huge trade. The remainder waits for the next call.
        uint256 wplsBal = _cappedAmountIn(WPLS.balanceOf(address(this)));
        if (wplsBal == 0) revert NothingToSwap();

        // 2b. Roll the oracle if due, then compute the TWAP floor for this trade
        _update();
        uint256 floor_ = _twapFloor(wplsBal);
        uint256 minOut = minShdOut > floor_ ? minShdOut : floor_;

        // 3. Approve router for the exact amount (handles non-standard tokens)
        WPLS.forceApprove(address(ROUTER), wplsBal);

        // 4. Swap WPLS → SHD
        address[] memory path = new address[](2);
        path[0] = address(WPLS);
        path[1] = address(SHD);

        uint256 shdBefore = SHD.balanceOf(address(this));

        ROUTER.swapExactTokensForTokens(
            wplsBal,
            minOut,
            path,
            address(this),
            deadline
        );

        // 5. Clear any leftover allowance
        WPLS.forceApprove(address(ROUTER), 0);

        // Measure actual received (robust to fee-on-transfer behaviour)
        uint256 shdReceived = SHD.balanceOf(address(this)) - shdBefore;
        if (shdReceived == 0) revert ZeroSHDReceived();
        if (shdReceived < minOut) revert SlippageExceeded();

        // 6. Burn everything (received + any dust that was already here)
        uint256 toBurn = SHD.balanceOf(address(this));
        totalBurned += toBurn;
        SHD.burn(toBurn);

        emit BuyAndBurn(msg.sender, plsWrapped, wplsBal, toBurn);
    }

    // ------------------------------------------------------------------
    // TWAP oracle
    // ------------------------------------------------------------------

    /// @notice Permissionless: roll the oracle forward if a full window has passed.
    function update() external {
        _update();
    }

    /// @notice The minimum SHD a swap of `wplsAmount` must return right now (reverts if oracle not ready).
    function twapFloor(uint256 wplsAmount) external view returns (uint256) {
        return _twapFloor(wplsAmount);
    }

    /// @notice WPLS + PLS currently queued in the contract, waiting to be spent.
    function pending() external view returns (uint256) {
        return WPLS.balanceOf(address(this)) + address(this).balance;
    }

    /// @notice How much WPLS one buyAndBurn call will spend right now at most.
    function maxBuyNow() external view returns (uint256) {
        return _cappedAmountIn(type(uint256).max);
    }

    function _cappedAmountIn(uint256 available) private view returns (uint256) {
        (uint112 r0, uint112 r1, ) = PAIR.getReserves();
        uint256 reserveWpls = WPLS_IS_TOKEN0 ? r0 : r1;
        uint256 cap = (reserveWpls * MAX_BUY_BPS) / BPS;
        return available < cap ? available : cap;
    }

    function _update() private {
        Observation memory cur = _observe(PAIR, WPLS_IS_TOKEN0);
        uint32 last = newObs.timestamp;
        uint32 elapsed;
        unchecked {
            elapsed = cur.timestamp - last; // uint32 wrap is intentional
        }
        if (elapsed >= TWAP_WINDOW) {
            oldObs = newObs;
            newObs = cur;
            emit ObservationRolled(cur.timestamp, cur.cumulative);
        }
    }

    function _twapFloor(uint256 wplsAmount) private view returns (uint256) {
        Observation memory o = oldObs;
        if (o.timestamp == 0) revert OracleNotReady();

        Observation memory cur = _observe(PAIR, WPLS_IS_TOKEN0);
        uint32 dt;
        uint256 avgPrice; // SHD per WPLS, UQ112x112
        unchecked {
            dt = cur.timestamp - o.timestamp;
            if (dt < TWAP_WINDOW) revert OracleNotReady();
            avgPrice = (cur.cumulative - o.cumulative) / dt;
        }

        uint256 expected = Math.mulDiv(avgPrice, wplsAmount, 1 << 112);
        return Math.mulDiv(expected, BPS - MAX_SLIPPAGE_BPS, BPS);
    }

    /// @dev Same technique as Uniswap V2's OracleLibrary: extend the stored cumulative
    ///      price with the current reserves for the time since the pair's last update.
    function _observe(
        IPulseXPair pair,
        bool wplsIsToken0
    ) private view returns (Observation memory o) {
        uint256 cum = wplsIsToken0
            ? pair.price0CumulativeLast()
            : pair.price1CumulativeLast();
        (uint112 r0, uint112 r1, uint32 tsLast) = pair.getReserves();
        uint32 ts = uint32(block.timestamp); // truncation is intentional

        if (tsLast != ts) {
            unchecked {
                uint256 spot = wplsIsToken0
                    ? (uint256(r1) << 112) / r0
                    : (uint256(r0) << 112) / r1;
                cum += spot * uint32(ts - tsLast);
            }
        }
        o = Observation({timestamp: ts, cumulative: cum});
    }

    /**
     * @notice Quote how much SHD you would get for `wplsAmount`.
     *         NOTE: this is a spot quote; always apply a slippage tolerance.
     */
    function quote(uint256 wplsAmount) external view returns (uint256 shdOut) {
        if (wplsAmount == 0) return 0;
        address[] memory path = new address[](2);
        path[0] = address(WPLS);
        path[1] = address(SHD);
        uint256[] memory amounts = ROUTER.getAmountsOut(wplsAmount, path);
        return amounts[1];
    }

    /**
     * @notice Burn any SHD sent directly to this contract.
     *         Permissionless – anyone can clean it up.
     */
    function burnStuckSHD() external nonReentrant {
        uint256 bal = SHD.balanceOf(address(this));
        if (bal == 0) revert NothingToBurn();
        totalBurned += bal;
        SHD.burn(bal);
        emit BurnStuckSHD(msg.sender, bal);
    }

    // Accept plain PLS transfers (wrapped and used on the next buyAndBurn)
    receive() external payable {}
}
