// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title SnipeHeadBuyAndBurnV2
 * @notice Permissionless buy-and-burn for SNIPEHEAD (SHD) on PulseChain.
 *         Anyone can send PLS (or already-held WPLS) and the contract will:
 *           1. Wrap all native PLS held -> WPLS
 *           2. Swap up to MAX_BUY_BPS of the pool's WPLS reserve -> SHD on PulseX V1
 *           3. Call SHD.burn() on the received tokens
 *
 *         No owner. No pause. No rescue. Fully immutable.
 *         The per-call size cap is a percentage of current pool reserves, so the
 *         contract automatically spends larger absolute amounts as liquidity grows.
 *
 * Addresses (PulseChain mainnet):
 *   SHD   : 0xB95bC84f9B6D0373642D586b81979B067572f7bc
 *   WPLS  : 0xA1077a294dDE1B09bB078844df40758a5D0f9a27
 *   Router: 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02  (PulseX V1)
 *
 * Design decisions (intentional):
 *   - PulseX V1 is the proper / primary liquidity venue for SHD-WPLS.
 *     The pair is resolved once at construction and stored as immutable.
 *     The contract does not follow liquidity to V2 or any other venue.
 *   - SHD.burn() is an internal burn on the token contract and is trusted.
 *
 * ---------------------------------------------------------------------------
 * CHANGES vs. the previous version (security fixes)
 * ---------------------------------------------------------------------------
 *   1. ORDERING BUG FIXED. Previously buyAndBurn() rolled the oracle
 *      (_update) BEFORE computing the price floor. The roll reset the reference
 *      point to "now", so the floor always saw a zero-length window and fell
 *      back to the manipulable spot floor. The TWAP was never actually used on
 *      a swap. The floor is now computed FIRST, then the oracle is rolled.
 *
 *   2. TWO OBSERVATIONS (`observation` = newest, `previousObservation` = the one
 *      before it). When the newest point rolls, it becomes the previous point,
 *      so a TWAP of at least TWAP_WINDOW is available immediately after every
 *      roll. Previously a single reference meant roughly half of all calls
 *      landed in a "warming up" gap.
 *
 *   3. NO MORE SPOT FALLBACK ON SWAPS. A spot-derived floor is computed from the
 *      very reserves an attacker can move in the same transaction, so it gives
 *      no sandwich protection. If no usable TWAP exists (first TWAP_WINDOW after
 *      deployment, or after a long quiet period) buyAndBurn() now DEFERS: it
 *      wraps any PLS, advances/restarts the oracle, emits `Deferred`, and
 *      returns without swapping. Funds stay queued in the contract and are
 *      spent by a later call. Nothing is lost and the oracle restart persists
 *      (a revert would have rolled the restart back).
 *
 *   4. Constructor now reverts with NoLiquidity if the pair has empty reserves.
 *
 *   Removed: SPOT_SLIPPAGE_BPS, FEE_NUMERATOR/DENOMINATOR, _spotFloor().
 *   Added:   MAX_OBSERVATION_GAP, previousObservation, Deferred event,
 *            NoLiquidity error. MAX_TWAP_WINDOW is now 120 minutes.
 *   Unchanged: BuyAndBurn event signature (usedTwap is now always true).
 *
 * Oracle behaviour:
 *   - Floor = TWAP-implied output x (1 - MAX_SLIPPAGE_BPS). The caller's
 *     minShdOut can only tighten it, never loosen it.
 *   - Cumulative prices follow the Uniswap-V2 pattern. Same-block manipulation
 *     does not enter the cumulative (it only accrues price x elapsed seconds).
 *   - The newest observation rolls once it is >= TWAP_WINDOW old. If it is
 *     older than MAX_OBSERVATION_GAP the oracle restarts (both points = now).
 *   - TWAP window used is between TWAP_WINDOW and MAX_TWAP_WINDOW.
 *
 * Known limits (inherent to on-chain TWAP floors):
 *   - A sandwich can still extract up to roughly (MAX_SLIPPAGE_BPS minus own
 *     fee + price impact), about 1.2 %, of a single call's size.
 *   - After a sharp move the TWAP lags: buys revert (price rose) or the floor is
 *     loose (price fell) until the average catches up.
 *   - TWAPs are only as strong as pool depth. Thin pools are cheap to push.
 *   - Keepers (or anyone) should call update() at least every ~60-90 min so the
 *     oracle never needs to restart.
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

contract SnipeHeadBuyAndBurnV2 is ReentrancyGuard {
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
    // TWAP oracle & sizing config
    // ------------------------------------------------------------------
    /// @notice Minimum averaging window for the TWAP.
    uint256 public constant TWAP_WINDOW = 30 minutes;

    /// @notice If the newest observation is older than this when the oracle is
    ///         rolled, the oracle restarts (both points set to now) instead of
    ///         averaging over a long quiet gap.
    uint256 public constant MAX_OBSERVATION_GAP = 90 minutes;

    /// @notice Longest TWAP window that will be used. The previous observation is
    ///         at most MAX_OBSERVATION_GAP + TWAP_WINDOW old while the oracle is
    ///         healthy, so there is never a gap in TWAP availability.
    uint256 public constant MAX_TWAP_WINDOW = MAX_OBSERVATION_GAP + TWAP_WINDOW;

    /// @notice Max allowed shortfall vs TWAP (fee + price impact + drift + tolerated MEV).
    ///         300 = 3 %.
    uint256 public constant MAX_SLIPPAGE_BPS = 300;

    /// @notice Max WPLS spent per call, as a share of the pool's current WPLS reserve.
    ///         150 = 1.5 % (about 1.8 % execution shortfall incl. fee).
    ///         Anything above the cap stays in the contract and is spent by later calls.
    uint256 public constant MAX_BUY_BPS = 150;

    /// @notice Absolute dust threshold. If the contract holds <= this amount of WPLS,
    ///         the full balance is spent even if it exceeds MAX_BUY_BPS of the reserve.
    uint256 public constant DUST_WPLS = 1e18; // 1 WPLS

    uint256 private constant BPS = 10_000;

    IPulseXPair public immutable PAIR;
    bool public immutable WPLS_IS_TOKEN0;

    /// @dev `timestamp` and `cumulative` are both subject to intentional overflow;
    ///      differences are taken in unchecked blocks exactly as in Uniswap V2 libraries.
    struct Observation {
        uint32 timestamp;
        uint256 cumulative; // cumulative price of WPLS quoted in SHD (UQ112x112 * seconds)
    }

    /// @notice Newest observation.
    Observation public observation;

    /// @notice The observation before `observation`.
    Observation public previousObservation;

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------
    error DeadlineExpired();
    error PairNotFound();
    error NoLiquidity();
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
        uint256 shdBurned,
        uint256 floorUsed,
        bool usedTwap
    );

    /// @dev Emitted instead of swapping when no usable TWAP exists yet. Funds stay queued.
    event Deferred(address indexed caller, uint256 plsWrapped, uint256 wplsQueued);

    event BurnStuckSHD(address indexed caller, uint256 amount);
    event ObservationUpdated(uint32 timestamp, uint256 cumulative);
    /// @dev Emitted when the oracle had gone stale and was restarted from the current point.
    event OracleRestarted(uint32 timestamp, uint256 cumulative);

    // ------------------------------------------------------------------
    // On-chain counter (nice for dashboards)
    // ------------------------------------------------------------------
    uint256 public totalBurned;

    // ------------------------------------------------------------------
    // Constructor - locate the pair and record the first observation
    // ------------------------------------------------------------------
    constructor() {
        address pair = IPulseXFactory(ROUTER.factory()).getPair(
            address(WPLS),
            address(SHD)
        );
        if (pair == address(0)) revert PairNotFound();

        (uint112 r0, uint112 r1, ) = IPulseXPair(pair).getReserves();
        if (r0 == 0 || r1 == 0) revert NoLiquidity();

        bool isToken0 = IPulseXPair(pair).token0() == address(WPLS);
        PAIR = IPulseXPair(pair);
        WPLS_IS_TOKEN0 = isToken0;

        // Seed both slots. A full TWAP_WINDOW must elapse before swaps are
        // allowed; until then buyAndBurn() defers (funds stay queued).
        Observation memory o = _observe(IPulseXPair(pair), isToken0);
        observation = o;
        previousObservation = o;
    }

    // ------------------------------------------------------------------
    // Main entry point
    // ------------------------------------------------------------------

    /**
     * @notice Buy SHD with PLS + any WPLS already in this contract, then burn it.
     *         At most MAX_BUY_BPS of the pool's WPLS reserve is spent per call
     *         (except dust <= DUST_WPLS which is cleared in full). The rest stays
     *         queued in the contract. Call again (with 0 value is fine) to continue.
     *
     *         The price floor is always the on-chain TWAP floor. If no usable TWAP
     *         exists yet, the call wraps PLS, advances the oracle, emits `Deferred`
     *         and returns without swapping. Check oracleReady() first to avoid
     *         spending gas on a deferral.
     *
     * @param minShdOut  Your own minimum SHD out. The effective minimum is
     *                   max(minShdOut, TWAP floor).
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

        // 2. Size the trade (capped to a share of the pool; dust cleared in full)
        uint256 wplsBal = _cappedAmountIn(WPLS.balanceOf(address(this)));
        if (wplsBal == 0) revert NothingToSwap();

        // 3. Compute the TWAP floor FIRST, using the observations as they stand,
        //    and only THEN roll the oracle. (Rolling first resets the window to
        //    zero and defeats the TWAP.)
        Observation memory cur = _observe(PAIR, WPLS_IS_TOKEN0);
        (uint256 floor_, bool twapReady) = _twapFloor(cur, wplsBal);
        _roll(cur);

        // 4. No usable TWAP: do not trade against a manipulable spot price.
        if (!twapReady) {
            emit Deferred(msg.sender, plsWrapped, WPLS.balanceOf(address(this)));
            return;
        }

        uint256 minOut = minShdOut > floor_ ? minShdOut : floor_;

        // 5. Approve router for the exact amount
        WPLS.forceApprove(address(ROUTER), wplsBal);

        // 6. Swap WPLS -> SHD
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

        // 7. Clear any leftover allowance
        WPLS.forceApprove(address(ROUTER), 0);

        // Measure actual received (robust to fee-on-transfer behaviour)
        uint256 shdReceived = SHD.balanceOf(address(this)) - shdBefore;
        if (shdReceived == 0) revert ZeroSHDReceived();
        if (shdReceived < minOut) revert SlippageExceeded();

        // 8. Burn everything currently held (received + any prior dust).
        uint256 toBurn = SHD.balanceOf(address(this));
        totalBurned += toBurn;
        SHD.burn(toBurn);

        emit BuyAndBurn(msg.sender, plsWrapped, wplsBal, toBurn, floor_, true);
    }

    // ------------------------------------------------------------------
    // TWAP oracle
    // ------------------------------------------------------------------

    /// @notice Permissionless: roll the oracle forward if a full window has passed
    ///         (or restart it if the newest point has gone stale). Call this at
    ///         least every ~60-90 minutes to keep the TWAP warm.
    function update() external {
        _roll(_observe(PAIR, WPLS_IS_TOKEN0));
    }

    /// @notice The minimum SHD a swap of `wplsAmount` must return right now.
    ///         `usedTwap` is false (and floor 0) when no usable TWAP exists, in
    ///         which case buyAndBurn() would defer instead of swapping.
    function priceFloor(uint256 wplsAmount) external view returns (uint256 floor, bool usedTwap) {
        return _twapFloor(_observe(PAIR, WPLS_IS_TOKEN0), wplsAmount);
    }

    /// @notice True when a usable TWAP exists, i.e. buyAndBurn() will swap.
    function oracleReady() external view returns (bool) {
        (bool ok, , ) = _twapReference(_observe(PAIR, WPLS_IS_TOKEN0));
        return ok;
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
        if (available == 0) return 0;

        (uint112 r0, uint112 r1, ) = PAIR.getReserves();
        uint256 reserveWpls = WPLS_IS_TOKEN0 ? r0 : r1;
        if (reserveWpls == 0) return 0;

        // Clear dust in full so residual WPLS cannot stay stuck forever on a thin pool.
        if (available <= DUST_WPLS) return available;

        uint256 cap = (reserveWpls * MAX_BUY_BPS) / BPS;
        return available < cap ? available : cap;
    }

    /// @dev Advances the two-slot oracle using an already-taken observation `cur`.
    ///      - newest younger than TWAP_WINDOW: nothing to do
    ///      - newest older than MAX_OBSERVATION_GAP: restart (both = cur)
    ///      - otherwise: previous = newest, newest = cur
    function _roll(Observation memory cur) private {
        uint32 elapsed;
        unchecked {
            elapsed = cur.timestamp - observation.timestamp; // uint32 wrap intentional
        }

        if (elapsed < TWAP_WINDOW) return;

        if (elapsed > MAX_OBSERVATION_GAP) {
            previousObservation = cur;
            observation = cur;
            emit OracleRestarted(cur.timestamp, cur.cumulative);
        } else {
            previousObservation = observation;
            observation = cur;
        }
        emit ObservationUpdated(cur.timestamp, cur.cumulative);
    }

    /// @dev Picks the reference observation for the TWAP: the previous point if its
    ///      age is within [TWAP_WINDOW, MAX_TWAP_WINDOW], else the newest point if
    ///      its age is within the same range, else none.
    function _twapReference(
        Observation memory cur
    ) private view returns (bool ok, Observation memory ref, uint32 dt) {
        Observation memory p = previousObservation;
        if (p.timestamp != 0) {
            unchecked {
                dt = cur.timestamp - p.timestamp;
            }
            if (dt >= TWAP_WINDOW && dt <= MAX_TWAP_WINDOW) {
                return (true, p, dt);
            }
        }

        Observation memory n = observation;
        if (n.timestamp != 0) {
            unchecked {
                dt = cur.timestamp - n.timestamp;
            }
            if (dt >= TWAP_WINDOW && dt <= MAX_TWAP_WINDOW) {
                return (true, n, dt);
            }
        }

        return (false, p, 0);
    }

    /// @dev TWAP-based floor. Returns (0, false) when no usable TWAP exists.
    function _twapFloor(
        Observation memory cur,
        uint256 wplsAmount
    ) private view returns (uint256 floor, bool ready) {
        (bool ok, Observation memory ref, uint32 dt) = _twapReference(cur);
        if (!ok) return (0, false);

        uint256 avgPrice; // SHD per WPLS, UQ112x112
        unchecked {
            // cumulative overflow is intentional; subtraction remains correct
            avgPrice = (cur.cumulative - ref.cumulative) / dt;
        }
        // expected = avgPrice * wplsAmount / 2^112
        uint256 expected = Math.mulDiv(avgPrice, wplsAmount, 1 << 112);
        floor = Math.mulDiv(expected, BPS - MAX_SLIPPAGE_BPS, BPS);
        ready = true;
    }

    /// @dev Same technique as Uniswap V2's OracleLibrary: extend the stored cumulative
    ///      price with the current reserves for the time since the pair's last update.
    ///      Both timestamp and cumulative are allowed to overflow; callers must use
    ///      unchecked differences.
    function _observe(
        IPulseXPair pair,
        bool wplsIsToken0
    ) private view returns (Observation memory o) {
        uint256 cum = wplsIsToken0
            ? pair.price0CumulativeLast()
            : pair.price1CumulativeLast();
        (uint112 r0, uint112 r1, uint32 tsLast) = pair.getReserves();
        uint32 ts = uint32(block.timestamp); // truncation intentional

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
     *         NOTE: this is a spot quote from the router; always apply a slippage tolerance.
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
     *         Permissionless - anyone can clean it up.
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
