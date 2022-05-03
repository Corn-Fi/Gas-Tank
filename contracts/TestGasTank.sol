// SPDX-License-Identifier: MIT

//                                                 ______   __                                                   
//                                                /      \ /  |                                                  
//   _______   ______    ______   _______        /$$$$$$  |$$/  _______    ______   _______    _______   ______  
//  /       | /      \  /      \ /       \       $$ |_ $$/ /  |/       \  /      \ /       \  /       | /      \ 
// /$$$$$$$/ /$$$$$$  |/$$$$$$  |$$$$$$$  |      $$   |    $$ |$$$$$$$  | $$$$$$  |$$$$$$$  |/$$$$$$$/ /$$$$$$  |
// $$ |      $$ |  $$ |$$ |  $$/ $$ |  $$ |      $$$$/     $$ |$$ |  $$ | /    $$ |$$ |  $$ |$$ |      $$    $$ |
// $$ \_____ $$ \__$$ |$$ |      $$ |  $$ |      $$ |      $$ |$$ |  $$ |/$$$$$$$ |$$ |  $$ |$$ \_____ $$$$$$$$/ 
// $$       |$$    $$/ $$ |      $$ |  $$ |      $$ |      $$ |$$ |  $$ |$$    $$ |$$ |  $$ |$$       |$$       |
//  $$$$$$$/  $$$$$$/  $$/       $$/   $$/       $$/       $$/ $$/   $$/  $$$$$$$/ $$/   $$/  $$$$$$$/  $$$$$$$/
//                         .-.
//         .-""`""-.    |(@ @)
//      _/`oOoOoOoOo`\_ \ \-/
//     '.-=-=-=-=-=-=-.' \/ \
//       `-=.=-.-=.=-'    \ /\
//          ^  ^  ^       _H_ \
//
// ----- Corn Finance is a midwest grown decentralized finance protocol with the aim of making life easier -----
// ------------------------ When you're tired of living in the past, live in the future ------------------------
// ----------------------------------------------------- N -----------------------------------------------------

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IGasTank.sol";
import "./GasTank.sol";

// ------------------------------------------------------------------------------------
// ////////////////////////////////// TestToken.sol ///////////////////////////////////
// ------------------------------------------------------------------------------------

contract TestToken is ERC20 {
    constructor(address _to) ERC20("test token", "TEST") {
        // Mint 100,000 TEST tokens
        _mint(_to, 100000 ether);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

// ------------------------------------------------------------------------------------
// ///////////////////////////////// TestGasTank.sol //////////////////////////////////
// ------------------------------------------------------------------------------------

contract TestGasTank {
    using SafeMath for uint256;

    GasTank public gasTank;
    TestToken public testToken;

    // --------------------------------------------------------------------------------
    // --------------------------------------------------------------------------------

    constructor() {
        // Create new Gas Tank with this contract as owner
        gasTank = new GasTank();

        // Create new test token and mint 100,000 to the Gas Tank
        testToken = new TestToken(address(gasTank));
    }

    // --------------------------------------------------------------------------------

    function verifyDeposit() external payable returns (bool[] memory success) {
        success = new bool[](3);

        uint256 callerBefore = msg.sender.balance;
        uint256 gasTankBefore = address(gasTank).balance;

        uint256 amountBefore = gasTank.userGasAmounts(address(this));
        uint256 depositAmount = msg.value;

        (bool succ, ) = address(gasTank).call{value: depositAmount}("");
        require(succ, "TestGasTank: verifyDeposit(): ETH transfer error");

        gasTank.depositGas(address(this));

        uint256 amountAfter = gasTank.userGasAmounts(address(this));
        uint256 calcDepositAmount = amountAfter.sub(amountBefore);

        uint256 callerAfter = msg.sender.balance;
        uint256 gasTankAfter = address(gasTank).balance;
        
        success[0] = callerBefore.sub(callerAfter) == depositAmount;
        success[1] = gasTankAfter.sub(gasTankBefore) == depositAmount;
        success[2] = calcDepositAmount == depositAmount;
    }

    // --------------------------------------------------------------------------------

    function verifyWithdraw(uint256 _amount) external returns (bool[] memory success) {
        success = new bool[](3);

        uint256 callerBefore = msg.sender.balance;
        uint256 gasTankBefore = address(gasTank).balance;

        uint256 amountBefore = gasTank.userGasAmounts(address(this));

        gasTank.withdrawGas(_amount);

        uint256 callerAfter = msg.sender.balance;
        uint256 gasTankAfter = address(gasTank).balance;

        uint256 amountAfter = gasTank.userGasAmounts(address(this));
        
        uint256 calcWithdrawAmount = amountBefore.sub(amountAfter);
        
        success[0] = callerAfter.sub(callerBefore) == _amount;
        success[1] = gasTankBefore.sub(gasTankAfter) == _amount;
        success[2] = calcWithdrawAmount == _amount;
    }

    // --------------------------------------------------------------------------------

    function payeeApprovalNonOwner(address _payee) external returns (bool[] memory success) {
        success = new bool[](2);

        // Test with a non-approved payee
        require(!gasTank._approvedPayees(_payee), "TestGasTank: payeeApprovalNonOwner(): payee already approved");
        
        // Test non-owner adding a payee to Gas Tank
        (success[0], ) = address(gasTank).delegatecall(abi.encodeWithSelector(gasTank.addPayee.selector, address(this)));
        
        // Test non-owner removing a payee from Gas Tank
        (success[2], ) = address(gasTank).delegatecall(abi.encodeWithSelector(gasTank.removePayee.selector, address(this)));
    }

    // --------------------------------------------------------------------------------

    function payeeApprovalOwner(address _payee) external returns (bool[] memory success) {
        success = new bool[](2);

        // Test with a non-approved payee
        require(!gasTank._approvedPayees(_payee), "TestGasTank: payeeApprovalNonOwner(): payee already approved");

        gasTank.addPayee(_payee);
       
        // Test if payee is successfully approved
        success[0] = gasTank._approvedPayees(_payee);

        gasTank.removePayee(_payee);

        // Test if payee is successfully removed
        success[1] = !gasTank._approvedPayees(_payee);
    }

    // --------------------------------------------------------------------------------

    function emergencyWithdrawOwner() external returns (bool[] memory success) {
        success = new bool[](2);

        uint256 withdrawAmount = 1 ether;

        uint256 gasTankBefore = testToken.balanceOf(address(gasTank));
        require(gasTankBefore >= withdrawAmount, "TestGasTank: emergencyWithdrawOwner(): insufficient tokens in gas tank");

        uint256 ownerBefore = testToken.balanceOf(gasTank.owner());

        gasTank.emergencyWithdraw(IERC20(testToken), withdrawAmount);

        uint256 gasTankAfter = testToken.balanceOf(address(gasTank));
        uint256 ownerAfter = testToken.balanceOf(gasTank.owner());

        success[0] = gasTankBefore.sub(gasTankAfter) == withdrawAmount;
        success[1] = ownerAfter.sub(ownerBefore) == withdrawAmount;
    }

    // --------------------------------------------------------------------------------

    function emergencyWithdrawNonOwner() external returns (bool success) {
        (success, ) = address(gasTank).delegatecall(
            abi.encodeWithSelector(gasTank.emergencyWithdraw.selector, IERC20(testToken), 1 ether)
        );
    }

    // --------------------------------------------------------------------------------

    function approvedPayeeApprovedPayment(uint256 _payAmount) external returns (bool[] memory success) {
        success = new bool[](4);

        gasTank.addPayee(address(this));

        (bool succ, ) = address(gasTank).delegatecall(abi.encodeWithSelector(gasTank.approve.selector, address(this), true));
        require(succ, "TestGasTank: approvedPayeeApprovedPayment(): payee approve error");

        uint256 payeeBefore = address(this).balance;
        uint256 gasTankBefore = address(gasTank).balance;
        uint256 userBefore = gasTank.userGasAmounts(msg.sender);

        require(userBefore > _payAmount, "TestGasTank: approvedPayeeApprovedPayment(): user balance error");

        try gasTank.pay(msg.sender, address(this), _payAmount) {
            success[0] = true;
        }
        catch {
            success[0] = false;
        }

        uint256 payeeAfter = address(this).balance;
        uint256 gasTankAfter = address(gasTank).balance;
        uint256 userAfter = gasTank.userGasAmounts(msg.sender);

        success[1] = payeeAfter.sub(payeeBefore) == _payAmount;
        success[2] = gasTankBefore.sub(gasTankAfter) == _payAmount;
        success[3] = userBefore.sub(userAfter) == _payAmount;
        
        gasTank.removePayee(address(this));

        (bool succ1, ) = address(gasTank).delegatecall(abi.encodeWithSelector(gasTank.approve.selector, address(this), false));
        require(succ1, "TestGasTank: approvedPayeeApprovedPayment(): payee approve error - 1");
    }

    // --------------------------------------------------------------------------------

    function approvedPayeeUnapprovedPayment(uint256 _payAmount) external returns (bool success) {
        gasTank.addPayee(address(this));

        require(gasTank.userGasAmounts(msg.sender) > _payAmount, "TestGasTank: approvedPayeeUnapprovedPayment(): user balance error");

        try gasTank.pay(msg.sender, address(this), _payAmount) {
            success = false;
        }
        catch {
            success = true;
        }
        
        gasTank.removePayee(address(this));
    }

    // --------------------------------------------------------------------------------

    function unapprovedPayeeApprovedPayment(uint256 _payAmount) external returns (bool success) {
        require(!gasTank._approvedPayees(address(this)), "TestGasTank: unapprovedPayeeApprovedPayment(): payee is approved");

        (bool succ, ) = address(gasTank).delegatecall(abi.encodeWithSelector(gasTank.approve.selector, address(this), true));
        require(succ, "TestGasTank: unapprovedPayeeApprovedPayment(): payee approve error");

        require(gasTank.userGasAmounts(msg.sender) > _payAmount, "TestGasTank: unapprovedPayeeApprovedPayment(): user balance error");

        // The following line should revert
        try gasTank.pay(msg.sender, address(this), _payAmount) {
            success = false;
        }
        catch {
            success = true;
        }
        
        (bool succ1, ) = address(gasTank).delegatecall(abi.encodeWithSelector(gasTank.approve.selector, address(this), false));
        require(succ1, "TestGasTank: unapprovedPayeeApprovedPayment(): payee approve error - 1");
    }

    // --------------------------------------------------------------------------------

    function unapprovedPayeeUnapprovedPayment(uint256 _payAmount) external returns (bool success) {
        require(!gasTank._approvedPayees(address(this)), "TestGasTank: unapprovedPayeeUnapprovedPayment(): payee is approved");
        (bool succ, ) = address(gasTank).delegatecall(abi.encodeWithSelector(gasTank.approve.selector, address(this), false));
        require(succ, "TestGasTank: unapprovedPayeeApprovedPayment(): payee approve error");
        require(gasTank.userGasAmounts(msg.sender) > _payAmount, "TestGasTank: unapprovedPayeeUnapprovedPayment(): user balance error");

        // The following line should revert
        try gasTank.pay(msg.sender, address(this), _payAmount) {
            success = false;
        }
        catch {
            success = true;
        }
    }
}