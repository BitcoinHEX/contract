pragma solidity ^0.5.7;

import "./UTXOClaimValidation.sol";


contract UTXORedeemableToken is UTXOClaimValidation {
    /**
     * @dev PUBLIC FACING: Claim a BTC address and its Satoshi balance in Hearts
     * crediting the appropriate amount to a specified Eth address. Bitcoin ECDSA
     * signature must be from that BTC address and must match the claim message
     * for the Eth address.
     * @param rawSatoshis Raw BTC address balance in Satoshis
     * @param proof Merkle tree proof
     * @param claimToAddr Destination Eth address to credit Hearts to
     * @param pubKeyX First  half of uncompressed ECDSA public key for the BTC address
     * @param pubKeyY Second half of uncompressed ECDSA public key for the BTC address
     * @param addrType Type of BTC address derived from the public key
     * @param v v parameter of ECDSA signature
     * @param r r parameter of ECDSA signature
     * @param s s parameter of ECDSA signature
     * @param referrerAddr Eth address of referring user (optional; 0x0 for no referrer)
     * @return Total number of Hearts credited, if successful
     */
    function claimBtcAddress(
        uint256 rawSatoshis,
        bytes32[] calldata proof,
        address claimToAddr,
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        uint8 addrType,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address referrerAddr
    )
        external
        returns (uint256)
    {
        /* Sanity check */
        require(rawSatoshis <= MAX_BTC_ADDR_BALANCE_SATOSHIS, "HEX: CHK: rawSatoshis");

        /* Ensure signature matches the claim message containing the destination Eth address */
        require(
            signatureMatchesClaim(claimToAddr, pubKeyX, pubKeyY, v, r, s),
            "HEX: Signature mismatch"
        );

        /* Derive BTC address from public key */
        bytes20 btcAddr = pubKeyToBtcAddress(pubKeyX, pubKeyY, addrType);

        /* Ensure BTC address has not yet been claimed */
        require(!claimedBtcAddresses[btcAddr], "HEX: BTC address balance already claimed");

        /* Ensure BTC address is part of the Merkle tree */
        require(
            _btcAddressIsValid(btcAddr, rawSatoshis, proof),
            "HEX: BTC address or balance unknown"
        );

        /* Mark BTC address as claimed */
        claimedBtcAddresses[btcAddr] = true;

        return _claimSatoshisSync(rawSatoshis, claimToAddr, btcAddr, referrerAddr);
    }

    function _claimSatoshisSync(
        uint256 rawSatoshis,
        address claimToAddr,
        bytes20 btcAddr,
        address referrerAddr
    )
        private
        returns (uint256 totalClaimedHearts)
    {
        GlobalsCache memory g;
        GlobalsCache memory gSnapshot;
        _loadGlobals(g);
        _snapshotGlobalsCache(g, gSnapshot);

        totalClaimedHearts = _claimSatoshis(g, rawSatoshis, claimToAddr, btcAddr, referrerAddr);

        _syncGlobals1(g, gSnapshot);
        _saveGlobals2(g);

        return totalClaimedHearts;
    }

    /**
     * @dev Credit an Eth address with the Hearts value of a raw Satoshis balance
     * @param rawSatoshis Raw BTC address balance in Satoshis
     * @param claimToAddr Destination Eth address for the claimed Hearts to be sent
     * @param btcAddr Bitcoin address (binary; no base58-check encoding)
     * @param referrerAddr (optional, send 0x0 for no referrer) Eth address of referring user
     * @return Total number of Hearts credited, if successful
     */
    function _claimSatoshis(
        GlobalsCache memory g,
        uint256 rawSatoshis,
        address claimToAddr,
        bytes20 btcAddr,
        address referrerAddr
    )
        private
        returns (uint256 totalClaimedHearts)
    {
        /* Disable claims after the claim phase is over */
        require(g._currentDay < CLAIM_PHASE_DAYS, "HEX: Claim phase has ended");

        /* Check if log data needs to be updated */
        _storeDailyDataBefore(g, g._currentDay);

        /* Sanity check */
        require(
            g._claimedBtcAddrCount < CLAIMABLE_BTC_ADDR_COUNT,
            "HEX: CHK: _claimedBtcAddrCount"
        );

        (uint256 adjSatoshis, uint256 claimedHearts, uint256 claimBonusHearts) = _calcClaimValues(
            g,
            rawSatoshis
        );

        totalClaimedHearts = claimedHearts + claimBonusHearts;

        /* Increment claim count to track viral rewards */
        g._claimedBtcAddrCount++;

        uint256 originBonusHearts = claimBonusHearts;

        if (referrerAddr == address(0)) {
            /* No referrer */
            emit Claim(
                uint40(block.timestamp),
                claimToAddr,
                btcAddr,
                rawSatoshis,
                adjSatoshis,
                totalClaimedHearts
            );
        } else {
            /* Referral bonus of 20% of total claimed Hearts */
            uint256 referBonusHearts = totalClaimedHearts / 5;

            originBonusHearts += referBonusHearts;

            if (referrerAddr == claimToAddr) {
                /* Self-referred */
                claimBonusHearts += referBonusHearts;
                totalClaimedHearts += referBonusHearts;

                emit ClaimReferredBySelf(
                    uint40(block.timestamp),
                    claimToAddr,
                    btcAddr,
                    rawSatoshis,
                    adjSatoshis,
                    totalClaimedHearts
                );
            } else {
                /* Referred by different address */
                emit ClaimReferredByOther(
                    uint40(block.timestamp),
                    claimToAddr,
                    btcAddr,
                    rawSatoshis,
                    adjSatoshis,
                    totalClaimedHearts,
                    referrerAddr
                );

                _mint(referrerAddr, referBonusHearts);
            }
        }

        _mint(ORIGIN_ADDR, originBonusHearts);
        _mint(claimToAddr, claimBonusHearts);


        /* Claim pre-minted Hearts from contract balance */
        _transfer(address(this), claimToAddr, claimedHearts);

        return totalClaimedHearts;
    }

    function _calcClaimValues(GlobalsCache memory g, uint256 rawSatoshis)
        private
        pure
        returns (uint256 adjSatoshis, uint256 claimedHearts, uint256 claimBonusHearts)
    {
        /* Apply Silly Whale reduction */
        adjSatoshis = _adjustSillyWhale(rawSatoshis);
        require(
            g._claimedSatoshisTotal + adjSatoshis <= CLAIMABLE_SATOSHIS_TOTAL,
            "HEX: CHK: _claimedSatoshisTotal"
        );
        g._claimedSatoshisTotal += adjSatoshis;

        uint256 phaseDaysRemaining = CLAIM_REWARD_DAYS - g._currentDay;
        uint256 rewardDaysRemaining = phaseDaysRemaining < CLAIM_REWARD_DAYS
            ? phaseDaysRemaining + 1
            : CLAIM_REWARD_DAYS;

        /* Apply late-claim reduction */
        adjSatoshis = _adjustLateClaim(adjSatoshis, rewardDaysRemaining);
        g._unclaimedSatoshisTotal -= adjSatoshis;

        /* Convert to Hearts and calculate speed bonus */
        claimedHearts = adjSatoshis * HEARTS_PER_SATOSHI;
        claimBonusHearts = _calcSpeedBonus(claimedHearts, phaseDaysRemaining);

        return (adjSatoshis, claimedHearts, claimBonusHearts);
    }

    /**
     * @dev Apply Silly Whale adjustment
     * @param rawSatoshis Raw BTC address balance in Satoshis
     * @return Adjusted BTC address balance in Satoshis
     */
    function _adjustSillyWhale(uint256 rawSatoshis)
        private
        pure
        returns (uint256)
    {
        if (rawSatoshis < 1000e8) {
            /* For < 1,000 BTC: no penalty */
            return rawSatoshis;
        }
        if (rawSatoshis >= 10000e8) {
            /* For >= 10,000 BTC: penalty is 75%, leaving 25% */
            return rawSatoshis / 4;
        }
        /*
            For 1,000 <= BTC < 10,000: penalty scales linearly from 50% to 75%

            penaltyPercent  = (btc - 1000) / (10000 - 1000) * (75 - 50) + 50
                            = (btc - 1000) / 9000 * 25 + 50
                            = (btc - 1000) / 360 + 50

            appliedPercent  = 100 - penaltyPercent
                            = 100 - ((btc - 1000) / 360 + 50)
                            = 100 - (btc - 1000) / 360 - 50
                            = 50 - (btc - 1000) / 360
                            = (18000 - (btc - 1000)) / 360
                            = (18000 - btc + 1000) / 360
                            = (19000 - btc) / 360

            adjustedBtc     = btc * appliedPercent / 100
                            = btc * ((19000 - btc) / 360) / 100
                            = btc * (19000 - btc) / 36000

            adjustedSat     = 1e8 * adjustedBtc
                            = 1e8 * (btc * (19000 - btc) / 36000)
                            = 1e8 * ((sat / 1e8) * (19000 - (sat / 1e8)) / 36000)
                            = 1e8 * (sat / 1e8) * (19000 - (sat / 1e8)) / 36000
                            = (sat / 1e8) * 1e8 * (19000 - (sat / 1e8)) / 36000
                            = (sat / 1e8) * (19000e8 - sat) / 36000
                            = sat * (19000e8 - sat) / 36000e8
        */
        return rawSatoshis * (19000e8 - rawSatoshis) / 36000e8;
    }

    /**
     * @dev Apply late-claim adjustment to scale claim to zero by end of claim phase
     * @param adjSatoshis Adjusted BTC address balance in Satoshis (after Silly Whale)
     * @param daysRemaining Number of days remaining in claim phase
     * @return Adjusted BTC address balance in Satoshis (after Silly Whale and Late-Claim)
     */
    function _adjustLateClaim(uint256 adjSatoshis, uint256 daysRemaining)
        private
        pure
        returns (uint256)
    {
        /*
            Only valid from 0 to CLAIM_REWARD_DAYS, and only used during that time.

            adjustedSat = sat * (daysRemaining / CLAIM_REWARD_DAYS) * 100%
                        = sat *  daysRemaining / CLAIM_REWARD_DAYS
        */
        return adjSatoshis * daysRemaining / CLAIM_REWARD_DAYS;
    }

    /**
     * @dev Calculates speed bonus for claiming earlier in the claim phase
     * @param claimedHearts Hearts claimed from adjusted BTC address balance Satoshis
     * @param daysRemaining Number of days remaining in claim phase
     * @return Speed bonus in Hearts
     */
    function _calcSpeedBonus(uint256 claimedHearts, uint256 daysRemaining)
        private
        pure
        returns (uint256)
    {
        /*
            Only valid from 0 to CLAIM_REWARD_DAYS days, and only used during that time.
            Speed bonus is 20% ... 0% inclusive.

            bonusHearts = claimedHearts * (daysRemaining  /  CLAIM_REWARD_DAYS) * 20%
                        = claimedHearts * (daysRemaining  /  CLAIM_REWARD_DAYS) * 20/100
                        = claimedHearts * (daysRemaining  /  CLAIM_REWARD_DAYS) / 5
                        = claimedHearts *  daysRemaining  / (CLAIM_REWARD_DAYS  * 5)
        */
        return claimedHearts * daysRemaining / (CLAIM_REWARD_DAYS * 5);
    }
}
