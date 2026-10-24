// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {LaunchToken, TokenMetadata} from "../SnipeLaunchToken.sol";

/*//////////////////////////////////////////////////////////////
                        INTERFACES
//////////////////////////////////////////////////////////////*/

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IPulseXFactory {
    function getPair(address tokenA, address tokenB) external view returns (address);
    function createPair(address tokenA, address tokenB) external returns (address);
}

interface IPulseXPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function mint(address to, address senderOrigin) external returns (uint256 liquidity);
    function transfer(address to, uint256 value) external returns (bool);
}

/*//////////////////////////////////////////////////////////////
                    SHD LAUNCH FACTORY
//////////////////////////////////////////////////////////////*/

/// @title SHDLaunchFactory
/// @notice Factory for launching tokens on PulseChain paired with SHD.
///         Supports two modes (neither has any time limit):
///           1. Instant  – created AND launched in one createToken() transaction: 5 % of the
///              supply goes to the creator, the creator's SHD + the remaining 95 % are seeded into
///              a fresh PulseX V2 pool, the LP is burned and the token is unlocked, so it trades
///              immediately.
///           2. BondingCurve – constant-product curve over 95 % of the supply, open until 5 M SHD
///              is collected, then the factory automatically graduates (pays the creator, seeds
///              the pool, burns LP, unlocks token). Holders can sell back to the curve at any
///              time until graduation. The creator's 5 % is held by the factory and released to
///              the creator at graduation (see CREATOR_ALLOCATION).
/// @dev Immutable after deployment. No owner, no pause, no rescue.
///
///      Liquidity is seeded by transferring directly to the pair and calling pair.mint(),
///      NOT through the router. The router's addLiquidity() reverts if anyone has
///      donated SHD to the (still empty) pair and called sync(), which would otherwise
///      let an attacker permanently block every launch for ~1 wei of SHD.
contract SHDLaunchFactoryTestnet {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Official PulseChain burn address
    address public constant DEAD = 0x0000000000000000000000000000000000000369;

    /// @notice SNIPEHEAD (SHD)
    IERC20 public immutable SHD;

    /// @notice BuyAndBurn contract – creation fees land here
    address public immutable BUY_AND_BURN;

    /// @notice PulseX V2 factory
    IPulseXFactory public immutable FACTORY;

    /// @notice Creation fee taken in SHD and sent to BuyAndBurn
    uint256 public constant CREATION_FEE = 10 ether;

    /// @notice Bonding-curve graduation target
    uint256 public constant GRADUATION_TARGET = 5_000_000 ether;

    /// @notice Creator reward on graduation (1 % of target)
    uint256 public constant CREATOR_REWARD = 50_000 ether;

    /// @notice Treat the curve as complete when this many wei (or less) remain below target.
    ///         Prevents a 1-wei grief where the last buy would yield 0 tokens and graduate()
    ///         would otherwise be unreachable without a sell+rebuy.
    uint256 public constant GRADUATION_DUST = 1e6;

    /// @notice Fixed supply of every LaunchToken
    uint256 public constant TOKEN_SUPPLY = 21_000_000 ether;

    /// @dev TESTNET ONLY: addresses injected at deploy time instead of hardcoded mainnet constants.
    constructor(address shd_, address buyAndBurn_, address v2Factory_) {
        require(shd_ != address(0) && buyAndBurn_ != address(0) && v2Factory_ != address(0), "zero address");
        SHD = IERC20(shd_);
        BUY_AND_BURN = buyAndBurn_;
        FACTORY = IPulseXFactory(v2Factory_);
    }

    /// @notice Creator's share of the supply (5 %). Instant: sent to the creator at creation.
    ///         BondingCurve: sent to the creator at graduation.
    uint256 public constant CREATOR_ALLOCATION = TOKEN_SUPPLY / 20;

    /// @notice Supply available to the pool (Instant) or the curve + pool (BondingCurve)
    uint256 public constant CURVE_SUPPLY = TOKEN_SUPPLY - CREATOR_ALLOCATION;

    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    enum Mode {
        Instant,
        BondingCurve
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CurveState {
        uint256 shdCollected;   // SHD paid into the curve
        uint256 tokensSold;     // tokens sold from the curve
        bool graduated;
        address creator;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice token => mode. NOTE: defaults to Instant for unknown addresses; use creatorOf != 0 to test registration.
    mapping(address => Mode) public modeOf;

    /// @notice token => creator (non-zero only for tokens deployed by this factory)
    mapping(address => address) public creatorOf;

    /// @notice Bonding-curve state (only used when mode == BondingCurve)
    mapping(address => CurveState) public curves;

    /// @notice All tokens created by this factory
    address[] public allTokens;

    uint256 private _lock = 1;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenCreated(address indexed token, address indexed creator, Mode mode, string name, string symbol);
    event InstantLaunched(address indexed token, address indexed creator, uint256 shdAmount, uint256 lpBurned);
    /// @dev Emitted when the creator receives their token allocation (creation for Instant, graduation for BondingCurve)
    event CreatorAllocation(address indexed token, address indexed creator, uint256 amount);
    event Bought(address indexed token, address indexed buyer, uint256 shdIn, uint256 tokensOut);
    event Sold(address indexed token, address indexed seller, uint256 tokensIn, uint256 shdOut);
    event Graduated(
        address indexed token,
        address indexed creator,
        uint256 shdToLp,
        uint256 tokensToLp,
        uint256 lpBurned,
        uint256 creatorReward
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidMode();
    error InsufficientSHD();
    error UnexpectedSHD();
    error TransferFailed();
    error AlreadyGraduated();
    error NotBondingCurve();
    error NotGraduatedYet();
    error Slippage();
    error DeadlineExpired();
    error NothingToSell();
    error CurveEmpty();
    error ZeroOutput();
    error PoolNotEmpty();
    error NoLiquidityMinted();
    error Reentrancy();

    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            TOKEN CREATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new LaunchToken and registers it with the chosen mode. There is no
    ///         launch deadline or curve time limit of any kind.
    ///
    ///         Instant: creation and launch happen in this single transaction. The creator receives
    ///         CREATOR_ALLOCATION (5 %) of the supply; `shdAmount_` SHD (pulled from the caller) is
    ///         paired with the remaining 95 % in a fresh PulseX V2 pool, the LP is burned and the
    ///         token is unlocked, so it trades immediately. The token is born in this same
    ///         transaction and is locked until seeding completes, so nobody can front-run the
    ///         launch or seed the pool first.
    ///
    ///         BondingCurve: the curve (over 95 % of the supply) opens immediately and stays open
    ///         until it graduates. The creator's 5 % is paid out at graduation.
    ///
    /// @dev The caller must have approved the factory for CREATION_FEE + shdAmount_ SHD (Instant)
    ///      or CREATION_FEE (BondingCurve).
    /// @param shdAmount_  Instant: exact SHD to pair with the full supply (must be > 0).
    ///                    BondingCurve: must be 0.
    /// @param txDeadline_ Transaction expiry, 0 = none. NOT a launch limit: it only makes this
    ///                    call revert if it is mined after that time.
    function createToken(
        string calldata name_,
        string calldata symbol_,
        bytes32 graffiti_,
        TokenMetadata calldata metadata_,
        Mode mode_,
        uint256 shdAmount_,
        uint256 txDeadline_
    ) external nonReentrant returns (address token) {
        if (mode_ != Mode.Instant && mode_ != Mode.BondingCurve) revert InvalidMode();
        if (txDeadline_ != 0 && block.timestamp > txDeadline_) revert DeadlineExpired();
        if (mode_ == Mode.Instant) {
            if (shdAmount_ == 0) revert InsufficientSHD();
        } else if (shdAmount_ != 0) {
            revert UnexpectedSHD();
        }

        // Creation fee straight to BuyAndBurn
        if (!SHD.transferFrom(msg.sender, BUY_AND_BURN, CREATION_FEE)) revert TransferFailed();

        // Factory is initialRecipient: holds the whole supply and is the only address allowed to call launch()
        token = address(new LaunchToken(name_, symbol_, msg.sender, graffiti_, address(this), metadata_));

        modeOf[token] = mode_;
        creatorOf[token] = msg.sender;
        allTokens.push(token);

        if (mode_ == Mode.BondingCurve) {
            curves[token] = CurveState({shdCollected: 0, tokensSold: 0, graduated: false, creator: msg.sender});
        }

        emit TokenCreated(token, msg.sender, mode_, name_, symbol_);

        if (mode_ == Mode.Instant) _launchInstant(token, shdAmount_);
    }

    /*//////////////////////////////////////////////////////////////
                           INSTANT MODE
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs inside createToken() (which holds the reentrancy lock). The token was deployed a
    ///      moment ago, is locked, and the factory holds its entire supply.
    function _launchInstant(address token, uint256 shdAmount) internal {
        _pullSHD(msg.sender, shdAmount);

        // Factory holds exactly TOKEN_SUPPLY here (token is locked, nobody else can have sent any).
        // Creator gets 5 %, the pool gets the rest.
        if (IERC20(token).balanceOf(address(this)) != TOKEN_SUPPLY) revert CurveEmpty();

        _pushToken(token, msg.sender, CREATOR_ALLOCATION);
        emit CreatorAllocation(token, msg.sender, CREATOR_ALLOCATION);

        uint256 liquidity = _seedPoolAndBurn(token, CURVE_SUPPLY, shdAmount);
        _unlock(token);

        emit InstantLaunched(token, msg.sender, shdAmount, liquidity);
    }

    /*//////////////////////////////////////////////////////////////
                         BONDING CURVE MODE
    //////////////////////////////////////////////////////////////*/

    /// @notice Buy tokens on the bonding curve (open until it graduates; no time limit). Spends at most `shdIn`: if the purchase would overshoot
    ///         the graduation target it is capped to exactly reach it (only the capped amount is pulled).
    ///         Reaching the target graduates the curve in the same transaction.
    /// @param minTokensOut Minimum tokens expected (slippage protection)
    /// @param deadline     Optional deadline (0 = none)
    function buy(address token, uint256 shdIn, uint256 minTokensOut, uint256 deadline) external nonReentrant {
        if (deadline != 0 && block.timestamp > deadline) revert DeadlineExpired();
        CurveState storage c = curves[token];
        if (modeOf[token] != Mode.BondingCurve || c.creator == address(0)) revert NotBondingCurve();
        if (c.graduated) revert AlreadyGraduated();
        if (shdIn == 0) revert InsufficientSHD();

        (uint256 shdUsed, uint256 tokensOut) = _buyAmounts(c, shdIn);
        // Near the target, 1 wei of SHD can buy 0 token wei. Allow that dust buy so the
        // curve can still complete; otherwise require a positive token output.
        if (tokensOut == 0) {
            if (shdUsed == 0 || c.shdCollected + shdUsed + GRADUATION_DUST < GRADUATION_TARGET) {
                revert ZeroOutput();
            }
        } else if (tokensOut < minTokensOut) {
            revert Slippage();
        }

        c.shdCollected += shdUsed;
        c.tokensSold += tokensOut;

        _pullSHD(msg.sender, shdUsed);
        if (tokensOut > 0) _pushToken(token, msg.sender, tokensOut);

        emit Bought(token, msg.sender, shdUsed, tokensOut);

        if (c.shdCollected + GRADUATION_DUST >= GRADUATION_TARGET) _graduate(token);
    }

    /// @notice Sell tokens back to the curve for SHD. Works at any time until graduation (there is
    ///         no curve time limit), so holders can always exit.
    function sell(address token, uint256 tokensIn, uint256 minShdOut, uint256 deadline) external nonReentrant {
        if (deadline != 0 && block.timestamp > deadline) revert DeadlineExpired();
        CurveState storage c = curves[token];
        if (modeOf[token] != Mode.BondingCurve || c.creator == address(0)) revert NotBondingCurve();
        if (c.graduated) revert AlreadyGraduated();
        if (tokensIn == 0 || tokensIn > c.tokensSold) revert NothingToSell();

        uint256 shdOut = _quoteSell(c, tokensIn);
        if (shdOut == 0) revert ZeroOutput();
        if (shdOut < minShdOut) revert Slippage();

        c.shdCollected -= shdOut;
        c.tokensSold -= tokensIn;

        _pullToken(token, msg.sender, tokensIn);
        _pushSHD(msg.sender, shdOut);

        emit Sold(token, msg.sender, tokensIn, shdOut);
    }

    /// @notice Permissionless safety net; normally graduation happens inside buy().
    function graduate(address token) external nonReentrant {
        CurveState storage c = curves[token];
        if (modeOf[token] != Mode.BondingCurve || c.creator == address(0)) revert NotBondingCurve();
        if (c.graduated) revert AlreadyGraduated();
        if (c.shdCollected + GRADUATION_DUST < GRADUATION_TARGET) revert NotGraduatedYet();
        _graduate(token);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL GRADUATION
    //////////////////////////////////////////////////////////////*/

    function _graduate(address token) internal {
        CurveState storage c = curves[token];
        c.graduated = true;

        address creator = c.creator;
        uint256 shdToLp = c.shdCollected - CREATOR_REWARD; // collected >= TARGET > REWARD
        uint256 tokensToLp = CURVE_SUPPLY - c.tokensSold; // creator's 5 % is carved out of the supply

        _pushSHD(creator, CREATOR_REWARD);

        // Creator's token allocation: held by the factory until now so it can never be sold into the curve
        _pushToken(token, creator, CREATOR_ALLOCATION);
        emit CreatorAllocation(token, creator, CREATOR_ALLOCATION);

        uint256 liquidity = _seedPoolAndBurn(token, tokensToLp, shdToLp);
        _unlock(token);

        emit Graduated(token, creator, shdToLp, tokensToLp, liquidity, CREATOR_REWARD);
    }

    /*//////////////////////////////////////////////////////////////
                           LIQUIDITY SEEDING
    //////////////////////////////////////////////////////////////*/

    /// @dev Sends tokens + SHD directly to the pair, mints LP to this contract and burns it.
    ///      While the token is locked nobody but this contract can move it, so the pair can never
    ///      hold any token reserve before us; any SHD someone donated to the pair is simply
    ///      absorbed into the pool (a gift to the burned LP).
    function _seedPoolAndBurn(address token, uint256 tokenAmount, uint256 shdAmount)
        internal
        returns (uint256 liquidity)
    {
        address pair = FACTORY.getPair(token, address(SHD));
        if (pair == address(0)) pair = FACTORY.createPair(token, address(SHD));

        (uint112 r0, uint112 r1,) = IPulseXPair(pair).getReserves();
        if ((token < address(SHD) ? r0 : r1) != 0) revert PoolNotEmpty();

        _pushToken(token, pair, tokenAmount);
        _pushSHD(pair, shdAmount);

        liquidity = IPulseXPair(pair).mint(address(this), msg.sender);
        if (liquidity == 0) revert NoLiquidityMinted();

        if (!IPulseXPair(pair).transfer(DEAD, liquidity)) revert TransferFailed();
    }

    function _unlock(address token) internal {
        LaunchToken t = LaunchToken(token);
        if (!t.isLaunched()) t.launch();
    }

    /*//////////////////////////////////////////////////////////////
                         BONDING CURVE MATH
    //////////////////////////////////////////////////////////////*/

    /// @dev Constant-product curve with virtual reserves chosen so that the marginal price at
    ///      graduation equals the LP seed price (no price cliff when the pool opens). The curve
    ///      runs over CURVE_SUPPLY (19.95 M = 95 % of supply); the token-side reserve is the
    ///      original 23.42 M scaled by 0.95, the SHD side is unchanged:
    ///        5 M SHD collected  ->  ~15.17 M tokens sold, ~4.78 M tokens + 4.95 M SHD go to the pool
    ///        curve price ~0.1048 -> ~1.036 SHD/token; pool opens at ~1.036 SHD/token.
    ///      Derivation: with G = target, R = reward, L = supply - sold,
    ///        P = (G-R)/L,  u = G*sold/(P*sold - G),  VIRTUAL_SHD = P*u - G,  VIRTUAL_TOKEN = u + sold.
    uint256 private constant VIRTUAL_TOKEN_RESERVES = 22_249_000 ether;
    uint256 private constant VIRTUAL_SHD_RESERVES   =  2_332_000 ether;

    function _buyAmounts(CurveState storage c, uint256 shdIn)
        internal
        view
        returns (uint256 shdUsed, uint256 tokensOut)
    {
        uint256 collected = c.shdCollected;
        uint256 room = collected >= GRADUATION_TARGET ? 0 : GRADUATION_TARGET - collected;
        shdUsed = shdIn > room ? room : shdIn;

        uint256 tokenReserves = VIRTUAL_TOKEN_RESERVES - c.tokensSold;
        uint256 shdReserves = VIRTUAL_SHD_RESERVES + collected;

        // (tokenReserves - out) * (shdReserves + in) >= tokenReserves * shdReserves  (rounds in favour of the curve)
        tokensOut = (shdUsed * tokenReserves) / (shdReserves + shdUsed);

        uint256 realLeft = CURVE_SUPPLY - c.tokensSold;
        if (tokensOut > realLeft) tokensOut = realLeft;
    }

    function _quoteSell(CurveState storage c, uint256 tokensIn) internal view returns (uint256 shdOut) {
        uint256 tokenReserves = VIRTUAL_TOKEN_RESERVES - c.tokensSold;
        uint256 shdReserves = VIRTUAL_SHD_RESERVES + c.shdCollected;

        shdOut = (tokensIn * shdReserves) / (tokenReserves + tokensIn);
        if (shdOut > c.shdCollected) shdOut = c.shdCollected;
    }

    /// @notice Tokens received for `shdIn` (already accounts for the graduation cap)
    function quoteBuy(address token, uint256 shdIn) external view returns (uint256 tokensOut) {
        (, tokensOut) = _buyAmounts(curves[token], shdIn);
    }

    /// @notice SHD the curve would pay for `tokensIn`
    function quoteSell(address token, uint256 tokensIn) external view returns (uint256) {
        return _quoteSell(curves[token], tokensIn);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }

    function getCurve(address token)
        external
        view
        returns (uint256 shdCollected, uint256 tokensSold, bool graduated, address creator)
    {
        CurveState storage c = curves[token];
        return (c.shdCollected, c.tokensSold, c.graduated, c.creator);
    }

    /*//////////////////////////////////////////////////////////////
                          TOKEN / SHD HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Verifies the amount actually received, so a fee-on-transfer SHD can never unbalance curve accounting.
    function _pullSHD(address from, uint256 amount) internal {
        uint256 balBefore = SHD.balanceOf(address(this));
        if (!SHD.transferFrom(from, address(this), amount)) revert TransferFailed();
        if (SHD.balanceOf(address(this)) - balBefore != amount) revert TransferFailed();
    }

    function _pushSHD(address to, uint256 amount) internal {
        if (!SHD.transfer(to, amount)) revert TransferFailed();
    }

    function _pullToken(address token, address from, uint256 amount) internal {
        if (!IERC20(token).transferFrom(from, address(this), amount)) revert TransferFailed();
    }

    function _pushToken(address token, address to, uint256 amount) internal {
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
    }
}
