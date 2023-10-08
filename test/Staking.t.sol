// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdJson} from "forge-std/Test.sol";
import {StakingContract} from "../src/Staking.sol";

contract StakingContract is Test {
    StakingContract public stakingContract;
    address wethAddr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        airdrop = new stakingContract(wethAddr);
    }
}
