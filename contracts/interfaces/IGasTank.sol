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


pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IGasTank {
    event DepositGas(address indexed user, uint256 amount);
    event WithdrawGas(address indexed user, uint256 amount);
    event Pay(address indexed payer, address indexed payee, uint256 amount);
    event Approved(address indexed payer, address indexed payee, bool approved);

    // View
    function userGasAmounts(address _user) external view returns (uint256);
    function approvedPayees(uint256 _index) external view returns (address);
    function _approvedPayees(address _payee) external view returns (bool);
    function userPayeeApprovals(address _payer, address _payee) external view returns (bool);
    function txFee() external view returns (uint256);
    function feeAddress() external view returns (address);

    // Only owner
    function addPayee(address _payee) external;
    function removePayee(address _payee) external;
    function emergencyWithdraw(IERC20 _token, address _to, uint256 _amount) external;
    
    // Users
    function depositGas(address _receiver) external payable;
    function withdrawGas(uint256 _amount) external;
    function approve(address _payee, bool _approve) external;
    
    // Approved payees
    function pay(address _payer, address _payee, uint256 _amount) external;
}