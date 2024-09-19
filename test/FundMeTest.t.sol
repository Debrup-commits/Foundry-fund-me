//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    uint256 constant SENT_VAL = 0.1 ether;
    uint256 constant STARTING_BALANCE = 100 ether;

    address USER = makeAddr("user");

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testPriceVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund(); // Pass 0 ETH
    }

    function testFundUpdatesFundersDataStructure() public {
        vm.prank(USER); // Next TX gonnabe called by USER
        fundMe.fund{value: SENT_VAL}(); 
        assertEq(fundMe.getAddressToAmtFunded(USER), SENT_VAL);
    }

    modifier funded {
        vm.prank(USER);
        fundMe.fund{value: SENT_VAL}();
        _;
    }

    function testFundAddsFunderToArrayOfFunders() public funded{
        address funder = fundMe.getFunderAddress(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithSingleFunder() public funded {
        // Arrange
        address ownerAddress = fundMe.getOwnerAddress();
        uint256 startingOwnerBalance = ownerAddress.balance;
        uint256 startingFundAmt = address(fundMe).balance;

        // Act
        vm.prank(ownerAddress);
        fundMe.withdraw();

        uint256 finalOwnerBalance = ownerAddress.balance;
        uint256 finalFundAmt = address(fundMe).balance;

        // Assert
        assertEq(finalFundAmt, 0); // Final balance in fundMe should be 0
        assertEq(finalOwnerBalance, startingOwnerBalance+startingFundAmt); // Final balance of owner should have been increased by the amt in fundMe
    }

    function testWithdrawFromMultipleFunders() public {
        // Arrange
        
        //fund fundMe by 10 addresses
        uint160 numberOfFunders = 10;

        for(uint160 i = 1; i <= numberOfFunders; i++) {
            hoax(address(i), STARTING_BALANCE);
            fundMe.fund{value: SENT_VAL}();
        }

        address ownerAddress = fundMe.getOwnerAddress();
        uint256 startingOwnerBalance = ownerAddress.balance;
        uint256 startingFundAmt = address(fundMe).balance;

        // Act
        vm.startPrank(ownerAddress);
        fundMe.withdraw();
        vm.stopPrank();

        uint256 finalOwnerBalance = ownerAddress.balance;
        uint256 finalFundAmt = address(fundMe).balance;

        // Assert
        assertEq(finalFundAmt, 0); // Final balance in fundMe should be 0
        assertEq(finalOwnerBalance, startingOwnerBalance+startingFundAmt); // Final balance of owner should have been increased by the amt in fundMe

    }

}