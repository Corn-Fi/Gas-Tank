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
// ---------------------------------- We need a bigger ship where we're going ----------------------------------
// ---------------------------------------------------- C F ----------------------------------------------------

pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
* @title Corn Finance Gas Tank v1.0 (May 2022)
* @author C.W.B.
* @notice Users need to deposit native tokens into this contract in order to use 
* automated Corn Finance contracts. A user will interact with the Gas Tank by 
* depositing and withdrawing native tokens. When approved automated contract tasks 
* are executed, the transaction executor is paid from the user deposited funds in the 
* Gas Tank.
*
* NOTE: Automated tasks are only executed when the task creator has sufficient native 
* tokens desposited in the Gas Tank. INSUFFICIENT FUNDS WILL RESULT IN TASK EXECUTION 
* FAILURE.
*
* A 0.01 MATIC fee is applied to all executed tasks.
*
* This contract has security features included that require the user to approve individual
* payees for pulling payment. Unlike ERC20 approvals, the user will only be able to 
* set an approval flag as true or false for a given Payer --> Payee, instead of being able
* to approve an amount. Use of this security feature prevents the contract owner from 
* calling addPayee() and adding a malicious payee that could then call pay() without
* restriction.
*/
contract GasTank is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Amount of gas a user has deposited
    // userGasAmounts[user] = amount of ETH the user deposited into this contract 
    mapping(address => uint256) public userGasAmounts;

    // List of all active & inactive approved payees
    address[] public approvedPayees;

    // Active approved payees
    // _approvedPayees[payee] = true | false
    mapping(address => bool) public _approvedPayees;

    // Payer --> Payee approvals
    // userPayeeApprovals[payer][payee] = true | false
    mapping(address => mapping(address => bool)) public userPayeeApprovals;

    // Protocol fee
    uint256 public constant txFee = 1e16; // 0.01 MATIC
    address payable public constant feeAddress = payable(0x93F835b9a2eec7D2E289c1E0D50Ad4dEd88b253f);

    // --------------------------------------------------------------------------------
    // //////////////////////////////////// Events ////////////////////////////////////
    // --------------------------------------------------------------------------------
    event DepositGas(address indexed user, uint256 amount);
    event WithdrawGas(address indexed user, uint256 amount);
    event Pay(address indexed payer, address indexed payee, uint256 amount);
    event Approved(address indexed payer, address indexed payee, bool approved);


    // --------------------------------------------------------------------------------
    // ////////////////////////////////// Modifiers ///////////////////////////////////
    // --------------------------------------------------------------------------------
    modifier onlyApprovedPayee() {
        require(_approvedPayees[msg.sender], "CornFi Gas Tank: Unapproved payee");
        _;
    }


    // --------------------------------------------------------------------------------
    // /////////////////////////// State Changing Functions ///////////////////////////
    // --------------------------------------------------------------------------------

    /**
    * @dev Approve an address for pulling gas payment from user deposited ETH within 
    * this contract.
    * @notice Only the contract owner (dev) can call this function and add approved
    * payees. Be aware that each user still needs to approve added payees in order
    * for the payee to pull payment from the user's deposited funds in the Gas Tank.
    * @param _payee Payee to grant pulling payment permissions to
    */
    function addPayee(address _payee) external onlyOwner {
        require(!_approvedPayees[_payee], "CornFi Gas Tank: Payee Already Added");
        _approvedPayees[_payee] = true;
        approvedPayees.push(_payee);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Revoke permissions from a payee.
    * @notice Payee will no longer be able to pull payment after removal. Payee can be
    * approved again after removal by the owner calling addPayee(). Be aware that removal
    * of a payee does not remove the address from the 'approvedPayees' array, only the 
    * '_approvedPayees' mapping is updated. The 'approvedPayees' array is strictly for
    * informational purposes to view all approved payees, active or not.
    *
    * Always verify the approval state of a payee by calling _approvedPayees(address).
    * @param _payee Payee to remove pulling payment permissions from
    */
    function removePayee(address _payee) external onlyOwner {
        require(_approvedPayees[_payee], "CornFi Gas Tank: Invalid payee");
        _approvedPayees[_payee] = false;
    }
    
    // --------------------------------------------------------------------------------

    /**
    * @dev Deposit ETH into this contract to pay for automated tasks requiring payment. 
    * @notice ETH deposited is automatically taken when an automated task is executed. 
    * User is able to withdraw their available balance of ETH at any point in time. This 
    * function is not callable when 'isPaused()' == true.
    * @param _receiver: Address that is credited with the deposited ETH
    */
    function depositGas(address _receiver) external payable nonReentrant whenNotPaused {
        // User can only deposit ETH. Amount to deposit is msg.value.
        uint256 depositAmount = msg.value;

        // Add the deposited ETH to the '_receiver' balance
        userGasAmounts[_receiver] = userGasAmounts[_receiver].add(depositAmount);

        emit DepositGas(_receiver, depositAmount);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Remove deposited ETH of a user. 
    * @notice Withdrawing ETH while having active automated tasks requiring payment will 
    * result in execution FAILURE. A user must maintain a certian amount of ETH deposited 
    * to cover gas costs.  
    * @param _amount Amount of ETH to withdraw from this contract
    */
    function withdrawGas(uint256 _amount) external nonReentrant {
        // Revert if the user does not have any deposited ETH
        if(_amount > userGasAmounts[msg.sender]) {
            _amount = userGasAmounts[msg.sender];
        }

        require(_amount > 0, "CornFi Gas Tank: Nothing to withdraw");

        userGasAmounts[msg.sender] = userGasAmounts[msg.sender].sub(_amount);

        // Transfer ETH balance to the user
        (bool success, ) = msg.sender.call{value: _amount}("");

        // Revert if the transfer fails
        require(success, "CornFi Gas Tank: ETH transfer failed");

        emit WithdrawGas(msg.sender, _amount);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Approved payee contracts will call this function to receive gas payment from 
    * task creator. Caller must be an approved payee. Transaction will revert if the
    * payer has insufficient funds for payment. Payer is charged a transaction fee on
    * every payment.
    * @param _payer Payment payer
    * @param _payee Payment receiver
    * @param _amount Payment amount
    */
    function pay(
        address _payer, 
        address _payee, 
        uint256 _amount
    ) external onlyApprovedPayee whenNotPaused nonReentrant {
        uint256 amount = _amount.add(txFee);

        require(userGasAmounts[_payer] >= amount, "CornFi Gas Tank: Insufficient user funds");
        require(userPayeeApprovals[_payer][msg.sender], "CornFi Gas Tank: Payment not approved");
        
        userGasAmounts[_payer] = userGasAmounts[_payer].sub(amount);

        // Transfer ETH
        (bool success, ) = _payee.call{value: _amount}("");
        (bool success1, ) = feeAddress.call{value: txFee}("");

        // Revert if the transfer fails
        require(success && success1, "CornFi Gas Tank: ETH transfer failed");

        emit Pay(_payer, _payee, _amount);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Claim ERC20 tokens in this contract. 
    * @notice All user funds stored in this contract are the native token. This function 
    * cannot withdraw native tokens, only ERC20 tokens. This function is only used for
    * claiming ERC20 tokens that were sent to this contract in error. Only the contract
    * owner (dev) can call this function.
    * @param _token ERC20 token to withdraw
    * @param _amount Amount of ERC20 token to withdraw
    */
    function emergencyWithdraw(IERC20 _token, uint256 _amount) external onlyOwner {
        _token.safeTransfer(owner(), _amount);
    }

    // --------------------------------------------------------------------------------

    /**
    * @dev Set payee approval state at the payer level 
    * @notice Approving a payee will allow the payee to pull payment from the payer
    * deposited funds. Payee approval can be granted or revoked at any time by the user.
    * Caller can only change their own approval states of payees. Payees remain approved 
    * until approval is revoked.
    * @param _payee Payment receiver
    * @param _approve true: Payee can pull payment from user deposited funds 
    * false: Payee cannot pull payment from user deposited funds
    */
    function approve(address _payee, bool _approve) external {
        userPayeeApprovals[msg.sender][_payee] = _approve;
        emit Approved(msg.sender, _payee, _approve);
    }
}