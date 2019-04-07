pragma solidity ^0.5.7;

import "./UTXORedeemableToken.sol";


contract StakeableToken is UTXORedeemableToken {
    /**
     * @dev PUBLIC FACING: Open a stake. The order of the stake list can change when
     * a stake is removed, so the stake cookie allows the contract to reject invalidated
     * indexes to protect callers from themselves.
     * @param newStakeCookie Random or unique value to reference this stake (caller-provided)
     * @param newStakedHearts Number of Hearts to stake
     * @param newStakedDays Number of days to stake
     */
    function startStake(uint48 newStakeCookie, uint256 newStakedHearts, uint256 newStakedDays)
        external
    {
        GlobalsCache memory g;
        GlobalsCache memory gSnapshot;
        _loadGlobals(g);
        _snapshotGlobalsCache(g, gSnapshot);

        /* Make sure cookie is non-zero */
        require(newStakeCookie != 0, "HEX: newStakeCookie must be non-zero");

        /* Make sure staked amount is non-zero */
        require(newStakedHearts != 0, "HEX: newStakedHearts must be non-zero");

        /* enforce the minimum stake time */
        require(newStakedDays >= MIN_STAKE_DAYS, "HEX: newStakedDays lower than minimum");

        /* enforce the maximum stake time */
        require(newStakedDays <= MAX_STAKE_DAYS, "HEX: newStakedDays higher than maximum");

        /* Check if log data needs to be updated */
        _storeDailyDataBefore(g, g._currentDay);

        uint256 newStakeShares = calcStakeShares(newStakedHearts, newStakedDays);

        /*
            The startStake timestamp will always be part-way through the current
            day, so it needs to be rounded-up to the next day to ensure all
            stakes align with the same fixed calendar days. The current day is
            already rounded-down, so rounded-up is current day + 1.
        */
        uint256 newPooledDay = g._currentDay + 1;

        /* Create Stake */
        _addStake(
            staked[msg.sender],
            newStakeCookie,
            newStakedHearts,
            newStakeShares,
            newPooledDay,
            newStakedDays
        );

        emit StartStake(
            msg.sender,
            newStakeCookie,
            newStakedHearts,
            newStakedDays
        );

        /* Stake is added to pool in next round, not current round */
        g._nextStakeSharesTotal += newStakeShares;

        /* Transfer staked Hearts to contract */
        _transfer(msg.sender, address(this), newStakedHearts);

        _saveStakeGlobals(g);
        _syncClaimGlobals(g, gSnapshot);
    }

    /**
     * @dev PUBLIC FACING: Removes a completed stake from the global pool,
     * distributing the proceeds of any penalty immediately. The staker must
     * still call endStake() to retrieve their stake return (if any).
     * @param stakerAddr Address of staker
     * @param stakeIndex Index of stake within stake list
     * @param stakeCookieParam The stake's cookie value
     */
    function goodAccounting(address stakerAddr, uint256 stakeIndex, uint48 stakeCookieParam)
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
        _loadStake(stRef, stakeCookieParam, st);

        /* Stake must have served full term */
        require(g._currentDay >= st._pooledDay + st._stakedDays, "HEX: Stake not fully served");

        /* Stake must be in still in global pool */
        require(st._unpooledDay == 0, "HEX: Stake already unpooled");

        /* Check if log data needs to be updated */
        _storeDailyDataBefore(g, g._currentDay);

        /* Remove stake from global pool */
        _unpoolStake(g, st);

        /* Return values are unused here */
        _applyPayoutAndPenalty(g, st, st._stakedDays, false);

        if (msg.sender == stakerAddr) {
            emit GoodAccountingBySelf(
                stakerAddr,
                stakeIndex,
                stakeCookieParam
            );
        } else {
            emit GoodAccountingByOther(
                stakerAddr,
                stakeIndex,
                stakeCookieParam,
                msg.sender
            );
        }

        /* st._unpooledDay has changed */
        _updateStake(stRef, st);

        _saveStakeGlobals(g);
        _syncClaimGlobals(g, gSnapshot);
    }

    /**
     * @dev PUBLIC FACING: Closes a stake. The order of the stake list can change so
     * a stake cookie is used to reject stale indexes.
     * @param stakeIndex Index of stake within stake list
     * @param stakeCookieParam The stake's cookie value
     */
    function endStake(uint256 stakeIndex, uint48 stakeCookieParam)
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
        _loadStake(stakeListRef[stakeIndex], stakeCookieParam, st);

        /* Check if log data needs to be updated */
        _storeDailyDataBefore(g, g._currentDay);

        uint256 servedDays = 0;

        uint256 stakeReturn;
        uint256 penalty = 0;

        if (g._currentDay >= st._pooledDay) {
            bool prevUnpooled = (st._unpooledDay != 0);

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

            (stakeReturn, penalty) = _applyPayoutAndPenalty(g, st, servedDays, prevUnpooled);
        } else {
            /* Stake hasn't been added to the global pool yet, so no penalties or rewards apply */
            g._nextStakeSharesTotal -= st._stakeShares;

            stakeReturn = st._stakedHearts;
        }

        emit EndStake(
            msg.sender,
            stakeIndex,
            stakeCookieParam,
            servedDays,
            stakeReturn,
            penalty
        );

        if (stakeReturn != 0) {
            /* Transfer stake return from contract back to staker */
            _transfer(address(this), msg.sender, stakeReturn);
        }

        _removeStakeFromList(stakeListRef, stakeIndex);

        _saveStakeGlobals(g);
        _syncClaimGlobals(g, gSnapshot);
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
     * @dev Calculate stakeShares for a new stake, including any bonus
     * @param newStakedHearts Number of Hearts to stake
     * @param newStakedDays Number of days to stake
     */
    function calcStakeShares(uint256 newStakedHearts, uint256 newStakedDays)
        private
        pure
        returns (uint256)
    {
        /*
            If longer than 1 day stake is committed to, each extra day
            gives bonus shares of approximately 0.0548%, which is approximately 20%
            extra per year of increased stakelength committed to, but capped to a
            maximum of 200% extra.

            extraDays       = stakedDays - 1

            bonusPercent    = (extraDays / 364) * 20%
            extraDays       = bonusPercent / 20% * 364

            maxExtraDays    = 200% / 20% * 364
                            = 10 * 364
                            = 3640
            maxStakedDays   = maxExtraDays + 1
                            = 3641

            stakeShares     = stakedHearts + stakedHearts * bonusPercent
                            = stakedHearts + stakedHearts * (extraDays / 364) * 20%
                            = stakedHearts + stakedHearts * (extraDays / 364) * 20/100
                            = stakedHearts + stakedHearts * extraDays / 364 * 20 / 100
                            = stakedHearts + stakedHearts * extraDays * 20 / 364 / 100
                            = stakedHearts + stakedHearts * extraDays * 20 / 36400
                            = stakedHearts + stakedHearts * extraDays / 1820
        */
        if (newStakedDays <= 1) {
            /* No bonus shares if there are no extra days */
            return newStakedHearts;
        }

        uint256 extraDays = newStakedDays < 3641
            ? newStakedDays - 1
            : 3640;

        return newStakedHearts + newStakedHearts * extraDays / 1820;
    }

    function _unpoolStake(GlobalsCache memory g, StakeCache memory st)
        private
        pure
    {
        g._stakeSharesTotal -= st._stakeShares;
        st._unpooledDay = g._currentDay;
    }

    function _applyPayoutAndPenalty(
        GlobalsCache memory g,
        StakeCache memory st,
        uint256 servedDays,
        bool prevUnpooled
    )
        private
        returns (uint256 stakeReturn, uint256 penalty)
    {
        (stakeReturn, penalty) = _calcStakeReturnAndPenalty(g, st, servedDays);

        if (penalty != 0) {
            if (penalty > stakeReturn) {
                /* Cannot have a negative stake return */
                penalty = stakeReturn;
                stakeReturn = 0;
            } else {
                /* Remove penalty from the stake return */
                stakeReturn -= penalty;
            }
            /* Split penalty proceeds only if not previously unpooled by goodAccounting() */
            if (!prevUnpooled) {
                _splitPenaltyProceeds(g, penalty);
            }
        }
        return (stakeReturn, penalty);
    }

    function _calcStakeReturnAndPenalty(
        GlobalsCache memory g,
        StakeCache memory st,
        uint256 servedDays
    )
        private
        view
        returns (uint256 stakeReturn, uint256 penalty)
    {
        uint256 payout;

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
        return (stakeReturn, penalty);
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
     * @param stakeReturn committed stakeHearts plus payout
     * @return penalty Hearts
     */
    function _calcLatePenalty(uint256 stakedDaysParam, uint256 unpooledDays, uint256 stakeReturn)
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
        return stakeReturn * (unpooledDays - stakedDaysParam) / LATE_PENALTY_SCALE_DAYS;
    }
}
