// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Bank {
    address public owner;

    uint256 public constant LIQUIDATION_THRESHOLD = 80; // 清算門檻 80%
    uint256 public constant COLLATERAL_FACTOR = 70; // 最高借貸率 70%

    uint256 public ethUsdt = 3000 * 10**8;

    struct UserAccount{
        uint256 ethCollateral; // 用戶存入當抵押品的 ETH 數量 (單位: wei, 10^18)
        uint256 usdtBorrowed; // 用戶借出去的 USDT 數量 (單位: 10^6 或 10^18，此處簡化為 10^18 對齊)
    }

    mapping(address => UserAccount) public userAccounts;

    //Event
    event Deposited(address indexed _user, uint256 _ethAmount);
    event Borrowed(address indexed  _user, uint256 _ethAmount);
    event Liquidated(address indexed _user, address indexed _liquidator, uint256 debtRepaid);

    //Error
    error NotOwner(); //檢查Owner用
    error invalidDepositAmount(); //檢查存入金額
    error invalidBorrowedAmount(); //檢察借出金額
    error canNotbeLiquidated(address user); //確認借款人是否能夠被清算
    error invalidRepayAmount();
    error ExceedsBorrowLimit(uint256 maxAllowed, uint256 attempted); //根據借貸率70%確認借款人允許的借款金額

    constructor(){
        owner = msg.sender;
    }

    modifier isOwner() {
        if(msg.sender != owner){revert NotOwner();}
        _;
    }

    modifier canBeliquidated(address _liquidatedUser){
        if (getHealthFactor(_liquidatedUser) >= 1 * 10**18) {revert canNotbeLiquidated(_liquidatedUser);}
        _;
    }

    function depositCollateral() public payable {
        if (msg.value == 0){revert invalidDepositAmount();}
        userAccounts[msg.sender].ethCollateral += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function getHealthFactor (address _user) public view returns(uint256) {
        UserAccount memory account = userAccounts[_user];
        
        // 如果這個人根本沒借錢，健康係數無限大，回傳最大值防止除以零錯誤 (Division by Zero)
        if (account.usdtBorrowed == 0) {
            return type(uint256).max;
        }

        // 數學推導公式 (先乘後除鐵律)：
        // 抵押品總價值 = ethCollateral * ethPriceInUsdt / 10^8
        // 可承受之最高債務額度 = 抵押品總價值 * LIQUIDATION_THRESHOLD / 100
        // 健康係數 (再放大 10^18 倍，方便前端顯示小數點) = 可承受額度 * 10^18 / usdtBorrowed
        uint256 ethValueInUsdt = (account.ethCollateral * ethUsdt) / 10**8;
        uint256 liquidationValue = (ethValueInUsdt * LIQUIDATION_THRESHOLD) / 100;

        return (liquidationValue * 10**18) / account.usdtBorrowed;
    }

    function borrowUSDT(uint256 _amount) public {
        // 如果借款金額為 0，直接攔截並拋出錯誤
        if (_amount == 0) { 
            revert invalidBorrowedAmount(); 
        }
        uint256 futureDebt = userAccounts[msg.sender].usdtBorrowed + _amount;

        uint256 ethValueInUsdt = (userAccounts[msg.sender].ethCollateral * ethUsdt) / 10**8;
        uint256 maxBorrowAllowed = (ethValueInUsdt * COLLATERAL_FACTOR) / 100;

        // 風控安全檢查：新債務總額絕對不能超過最高可借額度
        if (futureDebt > maxBorrowAllowed){revert ExceedsBorrowLimit(maxBorrowAllowed,futureDebt);}

        userAccounts[msg.sender].usdtBorrowed = futureDebt;

        emit Borrowed(msg.sender, _amount);
    }
    function liquidate(address _borrower, _debtToRepay) public canBeliquidated(_borrower) {
        if (_debtToRepay <= 0) {revert invalidRepayAmount();}
        
    }

    //functions only for owner
    function setEthPrice(uint256 _newPrice) public isOwner{
        ethUsdt = _newPrice * 10**8;
    }
}
