pragma solidity ^0.4.18;

contract ERC20 {
    function totalSupply() public constant returns (uint supply);
    function balanceOf( address who ) public constant returns (uint value);
    function allowance( address owner, address spender ) public constant returns (uint _allowance);

    function transfer( address to, uint256 value) external;
    function transferFrom( address from, address to, uint value) public returns (bool ok);
    function approve( address spender, uint value ) public returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}

contract IBContract {
    ERC20 public Token;
    address _borrower;          //借款人地址
    address _tollAddress;       //抽成地址
    address _lender;
    address _tokenAddress;      
    uint256 _lenderAmount;
    uint256 _borrowerAmount;
    uint256 _borrowerPayable;    //还款
    uint256 _timeLimit;
    uint256 _expireDate;
    uint    _contractState;
    uint    _commissionRate;     //平台抽成 
    
    address qunTokenAddress = 0x6e67331c2Bcd199bff33ff97a26102e6DD5517A6;

    // event receivedEther(address sender, uint amount);
    // event receivedTokens(address _from, uint256 _value, address _token, bytes _extraData);

// function IBContract() public {
    function IBContract(uint256 borrowerAmount,uint256 lenderAmount,int tokenId,uint limitdays,uint interestRate) public {
        _borrower = msg.sender;
        require(limitdays > 0);
        
        // _borrowerAmount = borrowerAmount * 10 ** 18;
        _borrowerAmount = mul(borrowerAmount,10 ** 18);
        assert(_borrowerAmount > 0);
        
        _contractState = 0;
        _lenderAmount = lenderAmount * 10 ** 18 * (1 wei);
        
        //set token address
        setTokenAddress(tokenId);
    
        _timeLimit = limitdays * (1 minutes);
        // _timeLimit = limitdays * (1 days);
        
        // _borrowerPayable = _lenderAmount + _lenderAmount * interestRate / 100;
        _borrowerPayable = add(div(mul(_lenderAmount,interestRate),100),_lenderAmount);
        assert(_borrowerPayable > 0);
        
        _commissionRate = 3;
        
        _tollAddress = 0xa6061154fD4d3f002B22676DCF9F70f60D4A3Fdc;
    }
    
    function setTokenAddress(int tokenId) private{
        if(tokenId == 0){
            _tokenAddress = qunTokenAddress;
        }
    }

    modifier onlyBorrower(){
        require(msg.sender == _borrower);
        _;
    }

    modifier onlyLender(){
        require(msg.sender == _lender);
        _;
    }
    
    function mul(uint256 a, uint256 b) private pure returns (uint256 c) {
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        c = a * b;
        assert(c / a == b);
        return c;
    }
    
    function div(uint256 a, uint256 b) private pure returns (uint256) {
        assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }
    
    function sub(uint256 a, uint256 b) private pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    
    function add(uint256 a, uint256 b) private pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }

    function showExpireDate() public view returns(uint256) {
        return _expireDate;
    }

    function showBorrowerAmount() public view returns(uint256) {
        return _borrowerAmount;
    }

    function showLenderAmount() public view returns(uint256) {
        return _lenderAmount;
    }


    // function showRate() public view returns(uint) {
    //     return _interestRate;
    // }

    // function showBorrowerAssetAddress() public view returns(address){
    //     return DasToken;
    // }

    //show balanceOf Token
    function showBorrowerAssets() public view returns(uint256) {
        return Token.balanceOf(this);
    }

    //show check balanceOf etherum
    function showLenderAssets()public view returns (uint256) {
        address myAddress = this;
        return myAddress.balance;
    }

    function showBorrowerAddress() public view returns(address) {
        return _borrower;
    }

    function showLenderAddress() public view returns(address) {
        return _lender;
    }

    //edit
    function showContractState() public view returns(uint) {
        // return _contractState;
        if(_contractState == 0 && isBorrowerAssetEnough()) {
            return 1;
        }else{
            return _contractState;
        }
    }

    function showPayableAsset() public view returns(uint256) {
        return _borrowerPayable;
    }

    //check token is enough
    function isBorrowerAssetEnough() public view returns(bool) {
        return Token.balanceOf(this) >= _borrowerAmount ? true : false;
    }

    // function isRepaymentEnough() public view returns(bool) {
    //     return showLenderAssets() >= _borrowerPayable ? true : false;
    // }

    function isNotExpire() public view returns(bool){
        return now < _expireDate ? true : false;
    }


    //CancelContract
    function cancelContract()public onlyBorrower returns(bool){
        require(_contractState == 0);
        if(Token.balanceOf(this) > 0) {
            repayToken(_borrower, Token.balanceOf(this));
        }
        _contractState = 5;
        kill();
        return true;
    }


    function sendLendAsset()public payable returns (uint256 amount) {
        require(_contractState == 0);
        require(isBorrowerAssetEnough());
        require(showLenderAssets() <= _lenderAmount);
        if(_lender == 0x0) {
            _lender = msg.sender;
        }

        if (showLenderAssets() == _lenderAmount) {
            checkLenderAsset();
            _contractState = 2;
        }
        //  Transfer(this, msg.sender, amount);               // execute an event reflecting the change
        return _lenderAmount;                                    // ends function and returns
    }

    //execute contract
    function checkLenderAsset() internal returns(bool) {
        _expireDate = now + _timeLimit;
        //frozn
        //pay to borrower
        address myAddress = this;
        
        // uint256 _ibasset = myAddress.balance * _commissionRate /100;
        uint256 _ibasset = div(mul(myAddress.balance,_commissionRate),100);
        assert(_ibasset > 0);
        
        // uint256 _lenderasset = myAddress.balance - _ibasset;
        uint256 _lenderasset = sub(myAddress.balance,_ibasset);
        assert(_lenderasset > 0);
        
        repayEth(_tollAddress,_ibasset);
        repayEth(_borrower,_lenderasset);

        return true;
    }

    //repayment
    function sendRepayment() public payable onlyBorrower {
        require(isNotExpire());
        require(_contractState == 2);
        require(showLenderAssets() <= _borrowerPayable);

        if (showLenderAssets() == _borrowerPayable) {
            checkRepayment();
            _contractState = 3;
        }
        
        kill();
    }

    function checkRepayment() internal {
        //calculate ibasset
        address myAddress = this;
        if(myAddress.balance > 0){
            repayEth(_lender,myAddress.balance);
            repayToken(_borrower, Token.balanceOf(this));
        }
    }

    function repayEth(address accountAddress, uint256 asset) internal {
        accountAddress.transfer(asset);
    }

    function repayToken(address accountAddress, uint256 asset) internal {
        Token.transfer(accountAddress, asset);
    }

    //apply for get assets
    function applyForAssets() public onlyLender {
        require(_contractState == 2);
        require(!isNotExpire());
        
        address myAddress = this;
        repayToken(_lender,Token.balanceOf(this));
        repayEth(_tollAddress,myAddress.balance);
        _contractState = 4;
        kill();
    }

    function kill() private {
        selfdestruct(_borrower); // 销毁合约

    }
}
