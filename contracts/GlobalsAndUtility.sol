pragma solidity ^0.5.7;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";


contract GlobalsAndUtility is ERC20 {
    /* Define events */
    event Claim(
        uint40 timestamp,
        address indexed claimToAddr,
        bytes20 indexed btcAddr,
        uint256 rawSatoshis,
        uint256 adjSatoshis,
        uint256 claimedHearts
    );

    event ClaimReferredBySelf(
        uint40 timestamp,
        address indexed claimToAddr,
        bytes20 indexed btcAddr,
        uint256 rawSatoshis,
        uint256 adjSatoshis,
        uint256 claimedHearts
    );

    event ClaimReferredByOther(
        uint40 timestamp,
        address indexed claimToAddr,
        bytes20 indexed btcAddr,
        uint256 rawSatoshis,
        uint256 adjSatoshis,
        uint256 claimedHearts,
        address indexed referrerAddr
    );

    event StartStake(
        uint40 timestamp,
        address indexed stakerAddr,
        uint48 indexed stakeId,
        uint256 stakedHearts,
        uint16 stakedDays
    );

    event GoodAccountingBySelf(
        uint40 timestamp,
        address indexed stakerAddr,
        uint48 indexed stakeId,
        uint256 payout,
        uint256 penalty
    );

    event GoodAccountingByOther(
        uint40 timestamp,
        address indexed stakerAddr,
        uint48 indexed stakeId,
        uint256 payout,
        uint256 penalty,
        address indexed otherAddr
    );

    event EndStake(
        uint40 timestamp,
        address indexed stakerAddr,
        uint48 indexed stakeId,
        uint256 payout,
        uint256 penalty,
        uint16 servedDays
    );

    /* Origin address */
    address internal constant ORIGIN_ADDR = 0x20C39E8862cB26Ac16eD0AFB37DCeE7F1BD8F153;

    /* Trapped ETH flush address */
    address payable internal constant TRAPPED_ETH_FLUSH_ADDR = 0x20C39E8862cB26Ac16eD0AFB37DCeE7F1BD8F153;

    /* ERC20 constants */
    string public constant name = "HEX";
    string public constant symbol = "HEX";
    uint8 public constant decimals = 8;

    /* Hearts per Satoshi = 10,000 * 1e8 / 1e8 = 1e4 */
    uint256 private constant HEARTS_PER_HEX = 10 ** uint256(decimals); // 1e8
    uint256 private constant HEX_PER_BTC = 1e4;
    uint256 private constant SATOSHIS_PER_BTC = 1e8;
    uint256 internal constant HEARTS_PER_SATOSHI = HEARTS_PER_HEX / SATOSHIS_PER_BTC * HEX_PER_BTC;

    /* Time of contract launch (2019-03-04T00:00:00Z) */
    uint256 internal constant LAUNCH_TIME = 1551657600;

    /* Time of end of claim phase */
    uint256 private constant CLAIM_REWARD_WEEKS = 50;
    uint256 internal constant CLAIM_REWARD_DAYS = CLAIM_REWARD_WEEKS * 7;
    uint256 internal constant CLAIM_PHASE_DAYS = CLAIM_REWARD_DAYS + 1; // Skip launch day

    /* Root hash of the UTXO Merkle tree */
    bytes32 internal constant MERKLE_TREE_ROOT = 0x6c78104d5710f8ba6e080ada5997c3d95a3aff00041f78bbfae0816d6beaced8;

    /* Total Satoshis from all BTC addresses in UTXO snapshot */
    uint256 internal constant FULL_SATOSHIS_TOTAL = 53183860816766;

    /* Total Satoshis from supported BTC addresses in UTXO snapshot after applying Silly Whale */
    uint256 internal constant CLAIMABLE_SATOSHIS_TOTAL = 21281768913380;

    /* Number of claimable BTC addresses in UTXO snapshot */
    uint256 internal constant CLAIMABLE_BTC_ADDR_COUNT = 1000;

    /* Largest BTC address Satoshis balance in UTXO snapshot (sanity check) */
    uint256 internal constant MAX_BTC_ADDR_BALANCE_SATOSHIS = 988025376134;

    /* Stake timing parameters */
    uint256 internal constant MIN_STAKE_DAYS = 1;

    uint256 private constant MAX_STAKE_WEEKS = 50 * 52; // Approx 50 years
    uint256 internal constant MAX_STAKE_DAYS = MAX_STAKE_WEEKS * 7;

    uint256 internal constant EARLY_PENALTY_MIN_DAYS = 90;

    uint256 private constant LATE_PENALTY_GRACE_WEEKS = 2;
    uint256 internal constant LATE_PENALTY_GRACE_DAYS = LATE_PENALTY_GRACE_WEEKS * 7;

    uint256 private constant LATE_PENALTY_SCALE_WEEKS = 100;
    uint256 internal constant LATE_PENALTY_SCALE_DAYS = LATE_PENALTY_SCALE_WEEKS * 7;

    /* Hex digits used by createHexStringFromAddress() */
    bytes16 internal constant HEX_DIGITS = "0123456789abcdef";
    uint256 internal constant ETH_ADDRESS_BYTE_LEN = 20;
    uint256 internal constant ETH_ADDRESS_HEX_LEN = ETH_ADDRESS_BYTE_LEN * 2;

    /* BTC address types supported for claiming. Enums do not allow revert reasons */
    uint8 internal constant BTC_ADDR_TYPE_P2PKH_UNCOMPRESSED = 0;
    uint8 internal constant BTC_ADDR_TYPE_P2PKH_COMPRESSED = 1;
    uint8 internal constant BTC_ADDR_TYPE_P2WPKH_IN_P2SH = 2;
    uint8 internal constant BTC_ADDR_TYPE_COUNT = 3;

    /* Globals expanded for memory (except _latestStakeId) and compact for storage */
    struct GlobalsCache {
        // 1
        uint256 _daysStored;
        uint256 _stakeSharesTotal;
        uint256 _nextStakeSharesTotal;
        uint48 _latestStakeId;
        // 2
        uint256 _stakePenaltyPool;
        uint256 _unclaimedSatoshisTotal;
        uint256 _claimedSatoshisTotal;
        uint256 _claimedBtcAddrCount;
        //
        uint256 _currentDay;
    }

    struct GlobalsStore {
        // 1
        uint16 daysStored;
        uint80 stakeSharesTotal;
        uint80 nextStakeSharesTotal;
        uint48 latestStakeId;
        // 2
        uint80 stakePenaltyPool;
        uint64 unclaimedSatoshisTotal;
        uint64 claimedSatoshisTotal;
        uint32 claimedBtcAddrCount;
    }

    GlobalsStore public globals;

    /* Claimed BTC addresses. */
    mapping(bytes20 => bool) public claimedBtcAddresses;

    /* Period data */
    struct DailyDataStore {
        uint80 dayPayoutTotal;
        uint80 dayStakeSharesTotal;
    }

    mapping(uint256 => DailyDataStore) public dailyData;

    /* Stake expanded for memory (except _stakeId) and compact for storage */
    struct StakeCache {
        uint48 _stakeId;
        uint256 _stakedHearts;
        uint256 _stakeShares;
        uint256 _pooledDay;
        uint256 _stakedDays;
        uint256 _unpooledDay;
    }

    struct StakeStore {
        uint48 stakeId;
        uint80 stakedHearts;
        uint80 stakeShares;
        uint16 pooledDay;
        uint16 stakedDays;
        uint16 unpooledDay;
    }

    mapping(address => StakeStore[]) public staked;

    /* Temporary state for calculating daily rounds */
    struct RoundState {
        uint256 _totalSupplyCached;
        uint256 _mintContractBatch;
        uint256 _mintOriginBatch;
        uint256 _payoutTotal;
    }

    /**
     * @dev PUBLIC FACING: Optionally update daily data for a smaller
     * range to reduce gas cost for a subsequent operation
     * @param beforeDay Only update days before this day number (optional; 0 for current day)
     */
    function storeDailyDataBefore(uint256 beforeDay)
        external
    {
        GlobalsCache memory g;
        GlobalsCache memory gSnapshot;
        _loadGlobals(g);
        _snapshotGlobalsCache(g, gSnapshot);

        /* Skip launch day */
        require(g._currentDay != 0, "HEX: Not needed on launch day");

        if (beforeDay != 0) {
            require(beforeDay <= g._currentDay, "HEX: beforeDay cannot be in the future");

            _storeDailyDataBefore(g, beforeDay);
        } else {
            /* Default to current day */
            _storeDailyDataBefore(g, g._currentDay);
        }

        _syncGlobals1(g, gSnapshot);
        _syncGlobals2(g, gSnapshot);
    }

    /**
     * @dev PUBLIC FACING: Return the total supply excluding staked and holding pools (true supply)
     * @return True Supply
     */
    function circulatingSupply()
        external
        view
        returns (uint256)
    {
        /* totalSupply() will always be >= balanceOf(...) */
        return totalSupply() - balanceOf(address(this));
    }

    /**
     * @dev PUBLIC FACING: External helper to return most global info with a single call.
     * Ugly implementation due to limitations of the standard ABI encoder.
     * @return Fixed array of values
     */
    function getGlobalInfo()
        external
        view
        returns (uint256[11] memory)
    {
        return [
            globals.daysStored,
            globals.stakeSharesTotal,
            globals.nextStakeSharesTotal,
            globals.latestStakeId,
            globals.stakePenaltyPool,
            globals.unclaimedSatoshisTotal,
            globals.claimedSatoshisTotal,
            globals.claimedBtcAddrCount,
            _getCurrentDay(),
            totalSupply(),
            balanceOf(address(this))
        ];
    }

    /**
     * @dev PUBLIC FACING: External helper to return multiple entries of daily data with
     * a single call. Ugly implementation due to limitations of the standard ABI encoder.
     * @return Fixed array of values
     */
    function getDailyDataRange(uint256 offset, uint256 count)
        external
        view
        returns (uint256[] memory list)
    {
        uint256 max = offset + count;

        require(offset < max, "HEX: count invalid");
        require(max <= globals.daysStored, "HEX: offset or count invalid");

        list = new uint256[](count);

        uint256 src = offset;
        uint256 dst = 0;
        do {
            uint256 lo = uint256(dailyData[src].dayPayoutTotal);
            uint256 hi = uint256(dailyData[src].dayStakeSharesTotal) << 128;
            ++src;

            list[dst] = hi | lo;
        } while (++dst < count);

        return list;
    }

    /**
     * @dev PUBLIC FACING: External helper for the current day number since launch time
     * @return Current day number (zero-based)
     */
    function getCurrentDay()
        external
        view
        returns (uint256)
    {
        return _getCurrentDay();
    }

    function _getCurrentDay()
        internal
        view
        returns (uint256)
    {
        return (block.timestamp - LAUNCH_TIME) / 1 days;
    }

    function _loadGlobals(GlobalsCache memory g)
        internal
        view
    {
        // 1
        g._daysStored = globals.daysStored;
        g._stakeSharesTotal = globals.stakeSharesTotal;
        g._nextStakeSharesTotal = globals.nextStakeSharesTotal;
        g._latestStakeId = globals.latestStakeId;
        // 2
        g._stakePenaltyPool = globals.stakePenaltyPool;
        g._unclaimedSatoshisTotal = globals.unclaimedSatoshisTotal;
        g._claimedSatoshisTotal = globals.claimedSatoshisTotal;
        g._claimedBtcAddrCount = uint256(globals.claimedBtcAddrCount);
        //
        g._currentDay = _getCurrentDay();
    }

    function _snapshotGlobalsCache(GlobalsCache memory g, GlobalsCache memory gSnapshot)
        internal
        pure
    {
        // 1
        gSnapshot._daysStored = g._daysStored;
        gSnapshot._stakeSharesTotal = g._stakeSharesTotal;
        gSnapshot._nextStakeSharesTotal = g._nextStakeSharesTotal;
        gSnapshot._latestStakeId = g._latestStakeId;
        // 2
        gSnapshot._stakePenaltyPool = g._stakePenaltyPool;
        gSnapshot._unclaimedSatoshisTotal = g._unclaimedSatoshisTotal;
        gSnapshot._claimedSatoshisTotal = g._claimedSatoshisTotal;
        gSnapshot._claimedBtcAddrCount = g._claimedBtcAddrCount;
    }

    function _saveGlobals1(GlobalsCache memory g)
        internal
    {
        globals.daysStored = uint16(g._daysStored);
        globals.stakeSharesTotal = uint80(g._stakeSharesTotal);
        globals.nextStakeSharesTotal = uint80(g._nextStakeSharesTotal);
        globals.latestStakeId = g._latestStakeId;
    }

    function _syncGlobals1(GlobalsCache memory g, GlobalsCache memory gSnapshot)
        internal
    {
        if (g._daysStored == gSnapshot._daysStored
            && g._stakeSharesTotal == gSnapshot._stakeSharesTotal
            && g._nextStakeSharesTotal == gSnapshot._nextStakeSharesTotal
            && g._latestStakeId == gSnapshot._latestStakeId) {
            return;
        }
        _saveGlobals1(g);
    }

    function _saveGlobals2(GlobalsCache memory g)
        internal
    {
        globals.stakePenaltyPool = uint80(g._stakePenaltyPool);
        globals.unclaimedSatoshisTotal = uint64(g._unclaimedSatoshisTotal);
        globals.claimedSatoshisTotal = uint64(g._claimedSatoshisTotal);
        globals.claimedBtcAddrCount = uint32(g._claimedBtcAddrCount);
    }

    function _syncGlobals2(GlobalsCache memory g, GlobalsCache memory gSnapshot)
        internal
    {
        if (g._stakePenaltyPool == gSnapshot._stakePenaltyPool
            && g._unclaimedSatoshisTotal == gSnapshot._unclaimedSatoshisTotal
            && g._claimedSatoshisTotal == gSnapshot._claimedSatoshisTotal
            && g._claimedBtcAddrCount == gSnapshot._claimedBtcAddrCount) {
            return;
        }
        _saveGlobals2(g);
    }

    function _loadStake(StakeStore storage stRef, uint48 stakeIdParam, StakeCache memory st)
        internal
        view
    {
        /* Ensure caller's stakeIndex is still current */
        require(stakeIdParam == stRef.stakeId, "HEX: stakeIdParam not in stake");

        st._stakeId = stRef.stakeId;
        st._stakedHearts = stRef.stakedHearts;
        st._stakeShares = stRef.stakeShares;
        st._pooledDay = stRef.pooledDay;
        st._stakedDays = stRef.stakedDays;
        st._unpooledDay = stRef.unpooledDay;
    }

    function _updateStake(StakeStore storage stRef, StakeCache memory st)
        internal
    {
        stRef.stakeId = st._stakeId;
        stRef.stakedHearts = uint80(st._stakedHearts);
        stRef.stakeShares = uint80(st._stakeShares);
        stRef.pooledDay = uint16(st._pooledDay);
        stRef.stakedDays = uint16(st._stakedDays);
        stRef.unpooledDay = uint16(st._unpooledDay);
    }

    function _addStake(
        StakeStore[] storage stakeListRef,
        uint48 newStakeId,
        uint256 newStakedHearts,
        uint256 newStakeShares,
        uint256 newPooledDay,
        uint256 newStakedDays
    )
        internal
    {
        stakeListRef.push(
            StakeStore(
                newStakeId,
                uint80(newStakedHearts),
                uint80(newStakeShares),
                uint16(newPooledDay),
                uint16(newStakedDays),
                uint16(0) // unpooledDay
            )
        );
    }

    /**
     * @dev Efficiently delete from an unordered array by moving the last element
     * to the "hole" and reducing the array length. Can change the order of the list
     * and invalidate previously held indexes.
     * @notice stakeListRef length and stakeIndex are already ensured valid in endStake()
     * @param stakeListRef reference to staked[stakerAddr] array in storage
     * @param stakeIndex index of the element to delete
     */
    function _removeStakeFromList(StakeStore[] storage stakeListRef, uint256 stakeIndex)
        internal
    {
        uint256 lastIndex = stakeListRef.length - 1;

        /* Skip the copy if element to be removed is already the last element */
        if (stakeIndex != lastIndex) {
            /* Copy last element to the requested element's "hole" */
            stakeListRef[stakeIndex] = stakeListRef[lastIndex];
        }

        /*
            Reduce the array length now that the array is contiguous.
            Surprisingly, 'pop()' uses less gas than 'stakeListRef.length = lastIndex'
        */
        stakeListRef.pop();
    }

    /**
     * @dev Split a penalty 50:50 between origin and stakePenaltyPool
     */
    function _splitPenaltyProceeds(GlobalsCache memory g, uint256 penalty)
        internal
    {
        uint256 splitPenalty = penalty / 2;

        if (splitPenalty != 0) {
            _transfer(address(this), ORIGIN_ADDR, splitPenalty);
        }

        /* Use the other half of the penalty to account for an odd-numbered penalty */
        splitPenalty = penalty - splitPenalty;
        g._stakePenaltyPool += splitPenalty;
    }

    function _storeDailyDataBefore(GlobalsCache memory g, uint256 beforeDay)
        internal
    {
        if (g._daysStored >= beforeDay) {
            /* Already up-to-date */
            return;
        }

        RoundState memory rs;
        rs._totalSupplyCached = totalSupply();

        uint256 day = g._daysStored;
        do {
            if (g._stakeSharesTotal != 0) {
                _calcDailyRound(g, rs, day);
                dailyData[day].dayPayoutTotal = uint80(rs._payoutTotal);
                dailyData[day].dayStakeSharesTotal = uint80(g._stakeSharesTotal);
            } else {
                if (day == CLAIM_REWARD_DAYS && g._unclaimedSatoshisTotal != 0) {
                    /*
                        WEAREALLSATOSHI REWARDS: Edge case for final day

                        If a day has no open stakes (g._stakeSharesTotal == 0), then that day is skipped, and
                        the distribution that day would have received is carried forward. If the final day of
                        the claim phase has no open stakes then there is nowhere to carry this forward, thus the
                        final remainder of the unclaimed Satoshis cannot be paid out.
                    */
                    _splitPenaltyProceeds(g, g._unclaimedSatoshisTotal * HEARTS_PER_SATOSHI);
                    g._unclaimedSatoshisTotal = 0;
                }
            }

            /* Stakes started during this day are added to the pool next day */
            if (g._nextStakeSharesTotal != 0) {
                g._stakeSharesTotal += g._nextStakeSharesTotal;
                g._nextStakeSharesTotal = 0;
            }
        } while (++day < beforeDay);

        g._daysStored = day;

        if (rs._mintContractBatch != 0) {
            _mint(address(this), rs._mintContractBatch);
        }
        if (rs._mintOriginBatch != 0) {
            _mint(ORIGIN_ADDR, rs._mintOriginBatch);
        }
    }

    /**
     * @dev Estimate the stake payout for a incomplete day
     * @param g pre-loaded globals cache
     * @param stakeSharesParam param from stake to calculate bonuses for
     * @param day day to calculate bonuses for
     * @return payout Hearts
     */
    function _estimatePayoutRewardsDay(GlobalsCache memory g, uint256 stakeSharesParam, uint256 day)
        internal
        view
        returns (uint256)
    {
        /* Prevent updating state for this estimation */
        GlobalsCache memory gTmp;
        _snapshotGlobalsCache(g, gTmp);

        RoundState memory rs;
        rs._totalSupplyCached = totalSupply();

        _calcDailyRound(gTmp, rs, day);

        /* Stake is not in pool so it must be added to total as if it were */
        gTmp._stakeSharesTotal += stakeSharesParam;

        return rs._payoutTotal * stakeSharesParam / gTmp._stakeSharesTotal;
    }

    function _calcAdoptionBonus(
        uint256 payout,
        uint256 claimedBtcAddrCountParam,
        uint256 claimedSatoshisTotalParam
    )
        private
        pure
        returns (uint256)
    {
        /*
            VIRAL REWARDS: Add adoption percentage bonus to payout

            viral = payout * (claimedBtcAddrCount / CLAIMABLE_BTC_ADDR_COUNT)
        */
        uint256 viral = payout * claimedBtcAddrCountParam / CLAIMABLE_BTC_ADDR_COUNT;

        /*
            CRIT MASS REWARDS: Add adoption percentage bonus to payout

            crit  = payout * (claimedSatoshisTotal / CLAIMABLE_SATOSHIS_TOTAL)
        */
        uint256 crit = payout * claimedSatoshisTotalParam / CLAIMABLE_SATOSHIS_TOTAL;

        return viral + crit;
    }

    function _batchMintContract(RoundState memory rs, uint256 amount)
        private
        pure
    {
        rs._mintContractBatch += amount;
        rs._totalSupplyCached += amount;
    }

    function _batchMintOrigin(RoundState memory rs, uint256 amount)
        private
        pure
    {
        rs._mintOriginBatch += amount;
        rs._totalSupplyCached += amount;
    }

    function _calcDailyRound(GlobalsCache memory g, RoundState memory rs, uint256 day)
        private
        pure
    {
        /*
            Calculate payout round

            Inflation of 3.69% inflation per 364 days             (approx 1 year)
            dailyInterestRate   = exp(log(1 + 3.69%)  / 364) - 1
                                = exp(log(1 + 0.0369) / 364) - 1
                                = exp(log(1.0369) / 364) - 1
                                = 0.000099553011616349            (approx)

            payout  = totalSupply * dailyInterestRate
                    = totalSupply / (1 / dailyInterestRate)
                    = totalSupply / (1 / 0.000099553011616349)
                    = totalSupply / 10044.899534066692            (approx)
                    = totalSupply * 10000 / 100448995             (approx)
        */
        rs._payoutTotal = rs._totalSupplyCached * 10000 / 100448995;

        if (day < CLAIM_PHASE_DAYS) {
            /*
                WEAREALLSATOSHI REWARDS: Distribute all unclaimed Satoshis evenly across remaining days
            */
            uint256 daysRemaining = CLAIM_PHASE_DAYS - day; // 1 <= daysRemaining <= CLAIM_REWARD_DAYS
            uint256 reward = g._unclaimedSatoshisTotal / daysRemaining;
            g._unclaimedSatoshisTotal -= reward;

            reward *= HEARTS_PER_SATOSHI;

            uint256 bonus = _calcAdoptionBonus(
                rs._payoutTotal + reward,
                g._claimedBtcAddrCount,
                g._claimedSatoshisTotal
            );

            /*
                Contract:       inflation +          bonus
                payoutTotal:    inflation + reward + bonus
                Origin:                     reward + bonus

                (Contract already has WeAreAllSatoshi reward pre-minted)
            */
            rs._payoutTotal += bonus;
            _batchMintContract(rs, rs._payoutTotal);
            rs._payoutTotal += reward;
            _batchMintOrigin(rs, reward + bonus);
        } else {
            /*
                Contract:       inflation
                payoutTotal:    inflation
                Origin:         nothing
            */
            _batchMintContract(rs, rs._payoutTotal);
        }

        /* Contract already has stakePenaltyPool from _splitPenaltyProceeds() */
        if (g._stakePenaltyPool != 0) {
            rs._payoutTotal += g._stakePenaltyPool;
            g._stakePenaltyPool = 0;
        }
    }
}
