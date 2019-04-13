pragma solidity ^0.5.7;

import "./UTXORedeemableToken.sol";


contract StakeableToken is UTXORedeemableToken {
    /**
     * @dev PUBLIC FACING: Open a stake.
     * @param newStakedHearts Number of Hearts to stake
     * @param newStakedDays Number of days to stake
     */
    function startStake(uint256 newStakedHearts, uint256 newStakedDays)
        external
    {
        GlobalsCache memory g;
        GlobalsCache memory gSnapshot;
        _loadGlobals(g);
        _snapshotGlobalsCache(g, gSnapshot);

        /* Make sure staked amount is non-zero */
        require(newStakedHearts != 0, "HEX: newStakedHearts must be non-zero");

        /* enforce the minimum stake time */
        require(newStakedDays >= MIN_STAKE_DAYS, "HEX: newStakedDays lower than minimum");

        /* enforce the maximum stake time */
        require(newStakedDays <= MAX_STAKE_DAYS, "HEX: newStakedDays higher than maximum");

        /* Check if log data needs to be updated */
        _storeDailyDataBefore(g, g._currentDay);

        uint256 newStakeShares = calcStakeShares(newStakedHearts, newStakedDays, g._sharesPerHeart);

        /*
            The startStake timestamp will always be part-way through the current
            day, so it needs to be rounded-up to the next day to ensure all
            stakes align with the same fixed calendar days. The current day is
            already rounded-down, so rounded-up is current day + 1.
        */
        uint256 newPooledDay = g._currentDay + 1;

        /* Create Stake */
        uint48 newStakeId = ++g._latestStakeId;
        _addStake(
            staked[msg.sender],
            newStakeId,
            newStakedHearts,
            newStakeShares,
            newPooledDay,
            newStakedDays
        );

        emit StartStake(
            uint40(block.timestamp),
            msg.sender,
            newStakeId,
            newStakedHearts,
            uint16(newStakedDays)
        );

        /* Stake is added to pool in next round, not current round */
        g._nextStakeSharesTotal += newStakeShares;

        /* capture total hearts staked for share price */
        g._stakedHeartsTotal += newStakedHearts;

        /* Transfer staked Hearts to contract */
        _transfer(msg.sender, address(this), newStakedHearts);

        _saveGlobals1(g);
        _syncGlobals2(g, gSnapshot);
    }

    /**
     * @dev PUBLIC FACING: Removes a completed stake from the global pool,
     * distributing the proceeds of any penalty immediately. The staker must
     * still call endStake() to retrieve their stake return (if any).
     * @param stakerAddr Address of staker
     * @param stakeIndex Index of stake within stake list
     * @param stakeIdParam The stake's id
     */
    function goodAccounting(address stakerAddr, uint256 stakeIndex, uint48 stakeIdParam)
        external
    {
        GlobalsCache memory g;
        GlobalsCache memory gSnapshot;
        _loadGlobals(g);
        _snapshotGlobalsCache(g, gSnapshot);

        /* require() is more informative than the default assert() */
        require(staked[stakerAddr].length != 0, "HEX: Empty stake list");
        require(stakeIndex < staked[stakerAddr].length, "HEX: stakeIndex invalid");

        StakeStore storage stRef = staked[stakerAddr][stakeIndex];

        /* Get stake copy */
        StakeCache memory st;
        _loadStake(stRef, stakeIdParam, st);

        /* Stake must have served full term */
        require(g._currentDay >= st._pooledDay + st._stakedDays, "HEX: Stake not fully served");

        /* Stake must be in still in global pool */
        require(st._unpooledDay == 0, "HEX: Stake already unpooled");

        /* Check if log data needs to be updated */
        _storeDailyDataBefore(g, g._currentDay);

        /* Remove stake from global pool */
        _unpoolStake(g, st);

        /* stakeReturn value is unused here */
        (, uint256 payout, uint256 penalty, uint256 cappedPenalty) = _calcStakeReturn(
            g,
            st,
            st._stakedDays
        );

        /* remove hearts and pending payout from share price calculation */
        g._stakedHeartsTotal -= st._stakedHearts;
        g._pendingPayoutTotal -= payout;

        if (msg.sender == stakerAddr) {
            emit GoodAccountingBySelf(
                uint40(block.timestamp),
                stakerAddr,
                stakeIdParam,
                payout,
                penalty
            );
        } else {
            emit GoodAccountingByOther(
                uint40(block.timestamp),
                stakerAddr,
                stakeIdParam,
                payout,
                penalty,
                msg.sender
            );
        }

        if (cappedPenalty != 0) {
            _splitPenaltyProceeds(g, cappedPenalty);
        }

        /* st._unpooledDay has changed */
        _updateStake(stRef, st);

        _saveGlobals1(g);
        _syncGlobals2(g, gSnapshot);
    }

    /**
     * @dev PUBLIC FACING: Closes a stake. The order of the stake list can change so
     * a stake id is used to reject stale indexes.
     * @param stakeIndex Index of stake within stake list
     * @param stakeIdParam The stake's id
     */
    function endStake(uint256 stakeIndex, uint48 stakeIdParam)
        external
    {
        GlobalsCache memory g;
        GlobalsCache memory gSnapshot;
        _loadGlobals(g);
        _snapshotGlobalsCache(g, gSnapshot);

        StakeStore[] storage stakeListRef = staked[msg.sender];

        /* require() is more informative than the default assert() */
        require(stakeListRef.length != 0, "HEX: Empty stake list");
        require(stakeIndex < stakeListRef.length, "HEX: stakeIndex invalid");

        /* Get stake copy */
        StakeCache memory st;
        _loadStake(stakeListRef[stakeIndex], stakeIdParam, st);

        /* Check if log data needs to be updated */
        _storeDailyDataBefore(g, g._currentDay);

        uint256 servedDays = 0;

        bool prevUnpooled = (st._unpooledDay != 0);
        uint256 stakeReturn;
        uint256 payout = 0;
        uint256 penalty = 0;
        uint256 cappedPenalty = 0;
        uint256 pendingValueRemoved = 0;

        if (g._currentDay >= st._pooledDay) {
            if (prevUnpooled) {
                /* Previously unpooled in goodAccounting(), so must have served full term */
                servedDays = st._stakedDays;
            } else {
                _unpoolStake(g, st);

                servedDays = g._currentDay - st._pooledDay;
                if (servedDays > st._stakedDays) {
                    servedDays = st._stakedDays;
                }
            }

            (stakeReturn, payout, penalty, cappedPenalty) = _calcStakeReturn(g, st, servedDays);
            pendingValueRemoved = payout;
        } else {
            /* Stake hasn't been added to the global pool yet, so no penalties or rewards apply */
            g._nextStakeSharesTotal -= st._stakeShares;

            stakeReturn = st._stakedHearts;
            pendingValueRemoved = 0;
        }

        /* remove hearts from share price calculation */
        g._stakedHeartsTotal -= st._stakedHearts;
        /* remove pending value from share price calculation */
        g._pendingPayoutTotal -= pendingValueRemoved;

        emit EndStake(
            uint40(block.timestamp),
            msg.sender,
            stakeIdParam,
            payout,
            penalty,
            uint16(servedDays)
        );

        if (cappedPenalty != 0 && !prevUnpooled) {
            /* Split penalty proceeds only if not previously unpooled by goodAccounting() */
            _splitPenaltyProceeds(g, cappedPenalty);
        }

        if (stakeReturn != 0) {
            /* Transfer stake return from contract back to staker */
            _transfer(address(this), msg.sender, stakeReturn);
        }

        _removeStakeFromList(stakeListRef, stakeIndex);

        _saveGlobals1(g);
        _syncGlobals2(g, gSnapshot);
    }

    /**
     * @dev PUBLIC FACING: Return the current stake count for an Eth address
     * @param ethAddr Ethereum address
     */
    function getStakeCount(address ethAddr)
        external
        view
        returns (uint256)
    {
        return staked[ethAddr].length;
    }

    /**
     * @dev PUBLIC FACING: Calculates total stake payout including rewards for a multi-day range
     * @param stakeSharesParam param from stake to calculate bonuses for
     * @param beginDay first day to calculate bonuses for
     * @param endDay last day (non-inclusive) of range to calculate bonuses for
     * @return payout Hearts
     */
    function calcPayoutRewards(uint256 stakeSharesParam, uint256 beginDay, uint256 endDay)
        public
        view
        returns (uint256 payout)
    {
        for (uint256 day = beginDay; day < endDay; day++) {
            payout += dailyData[day].dayPayoutTotal * stakeSharesParam / dailyData[day].dayStakeSharesTotal;
        }
        return payout;
    }

    /**
     * @dev Apply LPB bonus for a new stake based on days
     * @param newStakedHearts Number of hearts to stake
     * @param newStakedDays Number of days to stake
     * @param sharesPerHeart Number of shares for each heart
     */
    function calcStakeShares(uint256 newStakedHearts, uint256 newStakedDays, uint80 sharesPerHeart)
        private
        pure
        returns (uint256)
    {
        /*
            LONGER PAYS BETTER:

            If longer than 1 day stake is committed to, each extra day
            gives bonus shares of approximately 0.0548%, which is approximately 20%
            extra per year of increased stakelength committed to, but capped to a
            maximum of 200% extra.

            extraDays       =  stakedDays - 1

            longerBonus%    = (extraDays / 364) * 20%
                            = (extraDays / 364) / 5
                            =  extraDays / 1820
                            =  extraDays / LPB_D

            extraDays       =  longerBonus% * 1820
            extraDaysCap    =  longerBonusCap% * 1820
                            =  200% * 1820
                            =  3640
                            =  LPB_D_CAP_DAYS

            longerAmount    =  hearts * longerBonus%

            LARGER PAYS BETTER:

            Bonus percentage scaled 0% to 10% for the first 150M HEX of stake.

            largerBonus%    = (hearts / 150e14) * 10%
                            = (hearts / 150e14) / 10
                            =  hearts / 150e15

            largerAmount    =  hearts * largerBonus%

            combinedBonus%  =         longerBonus%  +  largerBonus%

                                        extraWeeks     hearts
                            =           ----------  +  ------
                                            260        150e15

                                extraDays * 150e15     hearts * 1820
                            =   ------------------  +  -------------
                                   1820 * 150e15       1820 * 150e15

                                extraDays * 150e15     hearts * 1820
                            =   ------------------  +  -------------
                                  1820 * 150e15        1820 * 150e15

                                extraDays * 150e15  +  hearts * 1820
                            =   ------------------------------------
                                            1820 * 150e15

            combinedAmount  = hearts * combinedBonus%
                            = hearts * (extraDays * 150e15  +  hearts * 1820)  / (1820 * 150e15)
                            = hearts * (extraDays * LPB_H   +  hearts * LPB_D) / (LPB_D * LPB_H)

            stakeShares     = hearts + combinedAmount
        */
        require(sharesPerHeart > 0, "HEX: share price undecidable");

        uint256 cappedExtraDays = 0;

        /* Must be more than 1 day for Longer-Pays-Better */
        if (newStakedDays > 1) {
            cappedExtraDays = newStakedDays <= LPB_D_CAP_DAYS ? newStakedDays - 1 : LPB_D_CAP_DAYS;
        }

        uint256 cappedStakedHearts = newStakedHearts <= LPB_H_CAP_HEARTS
            ? newStakedHearts
            : LPB_H_CAP_HEARTS;

        uint256 combinedAmount = cappedExtraDays * LPB_H + cappedStakedHearts * LPB_D;
        combinedAmount = newStakedHearts * combinedAmount / (LPB_D * LPB_H);

        return sharesPerHeart * (newStakedHearts + combinedAmount);
    }

    function _unpoolStake(GlobalsCache memory g, StakeCache memory st)
        private
        pure
    {
        g._stakeSharesTotal -= st._stakeShares;
        st._unpooledDay = g._currentDay;
    }

    function _calcStakeReturn(GlobalsCache memory g, StakeCache memory st, uint256 servedDays)
        private
        view
        returns (uint256 stakeReturn, uint256 payout, uint256 penalty, uint256 cappedPenalty)
    {
        if (servedDays < st._stakedDays) {
            (payout, penalty) = _calcPayoutAndEarlyPenalty(
                g,
                st._pooledDay,
                st._stakedDays,
                servedDays,
                st._stakeShares
            );
            stakeReturn = st._stakedHearts + payout;
        } else {
            payout = calcPayoutRewards(st._stakeShares, st._pooledDay, st._pooledDay + servedDays);
            stakeReturn = st._stakedHearts + payout;

            penalty = _calcLatePenalty(
                st._stakedDays,
                st._unpooledDay - st._pooledDay,
                stakeReturn
            );
        }
        if (penalty != 0) {
            if (penalty > stakeReturn) {
                /* Cannot have a negative stake return */
                cappedPenalty = stakeReturn;
                stakeReturn = 0;
            } else {
                /* Remove penalty from the stake return */
                cappedPenalty = penalty;
                stakeReturn -= cappedPenalty;
            }
        }
        return (stakeReturn, payout, penalty, cappedPenalty);
    }

    /**
     * @dev Calculates served payout and early penalty for early unstake
     * @param g pre-loaded globals cache
     * @param pooledDayParam param from stake
     * @param stakedDaysParam param from stake
     * @param servedDays number of days actually served
     * @param stakeSharesParam param from stake
     * @return 1: payout Hearts; 2: penalty Hearts
     */
    function _calcPayoutAndEarlyPenalty(
        GlobalsCache memory g,
        uint256 pooledDayParam,
        uint256 stakedDaysParam,
        uint256 servedDays,
        uint256 stakeSharesParam
    )
        private
        view
        returns (uint256 payout, uint256 penalty)
    {
        uint256 servedEndDay = pooledDayParam + servedDays;

        /* 50% of stakedDays (rounded up) with a minimum applied */
        uint256 penaltyDays = stakedDaysParam / 2 + stakedDaysParam % 2;
        if (penaltyDays < EARLY_PENALTY_MIN_DAYS) {
            penaltyDays = EARLY_PENALTY_MIN_DAYS;
        }

        if (servedDays == 0) {
            /* Fill penalty days with the estimated average payout */
            uint256 expected = _estimatePayoutRewardsDay(g, stakeSharesParam, pooledDayParam);
            penalty = expected * penaltyDays;
            return (payout, penalty); // Actual payout was 0
        }

        if (penaltyDays < servedDays) {
            /*
                Simplified explanation of intervals where end-day is non-inclusive:

                penalty:    [pooledDay  ...  penaltyEndDay)
                delta:                      [penaltyEndDay  ...  servedEndDay)
                payout:     [pooledDay  .......................  servedEndDay)
            */
            uint256 penaltyEndDay = pooledDayParam + penaltyDays;
            penalty = calcPayoutRewards(stakeSharesParam, pooledDayParam, penaltyEndDay);

            uint256 delta = calcPayoutRewards(stakeSharesParam, penaltyEndDay, servedEndDay);
            payout = penalty + delta;
            return (payout, penalty);
        }

        /* penaltyDays >= servedDays  */
        payout = calcPayoutRewards(stakeSharesParam, pooledDayParam, servedEndDay);

        if (penaltyDays == servedDays) {
            penalty = payout;
        } else {
            /*
                (penaltyDays > servedDays) means not enough days served, so fill the
                penalty days with the average payout from only the days that were served.
            */
            penalty = payout * penaltyDays / servedDays;
        }
        return (payout, penalty);
    }

    /**
     * @dev Calculates penalty for ending stake late
     * and adds penalty to payout pool
     * @param stakedDaysParam param from stake
     * @param unpooledDays stake unpooledDay minus stake pooledDay
     * @param rawStakeReturn committed stakeHearts plus payout
     * @return penalty Hearts
     */
    function _calcLatePenalty(uint256 stakedDaysParam, uint256 unpooledDays, uint256 rawStakeReturn)
        private
        pure
        returns (uint256)
    {
        /* Allow grace time before penalties accrue */
        stakedDaysParam += LATE_PENALTY_GRACE_DAYS;
        if (unpooledDays <= stakedDaysParam) {
            return 0;
        }

        /* Calculate penalty as a percentage of stake return based on time */
        return rawStakeReturn * (unpooledDays - stakedDaysParam) / LATE_PENALTY_SCALE_DAYS;
    }
}
