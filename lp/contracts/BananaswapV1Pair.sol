// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./BananaswapV1ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/BananaswapV1Library.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

// TODO remove
import "hardhat/console.sol";

contract BananaswapV1Pair is BananaswapV1ERC20 {
    uint256 public constant MIN_LIQUIDITY = 10**3;

    address token;
    uint256 tokenReserve;
    uint256 ethReserve;
    uint256 ethBalance; // TODO just use native balance?

    constructor(address token_) {
        token = token_;
    }

    function getReserves() public view returns (uint256, uint256) {
        return (tokenReserve, ethReserve);
    }

    function mint(address to_) external returns (uint256 liquidity) {
        // get qty of deposits
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        uint256 _ethBal = ethBalance;
        uint256 _tokenReserve = tokenReserve;
        uint256 _ethReserve = ethReserve;
        uint256 _totalSupply = totalSupply;

        uint256 tokenAmt = tokenBal - _tokenReserve;
        uint256 ethAmt = _ethBal - _ethReserve;

        // console.log("TOTAL SUPPLY: ", _totalSupply);
        // console.log("TOKEN RESERVE: ", _tokenReserve);
        // console.log("TOKENS CONTRIBUTED: ", tokenAmt);
        // console.log("ETH RESERVE: ", _ethReserve);
        // console.log("ETH CONTRIBUTED: ", ethAmt);

        // calculate liquidity to grant to LP
        // handle initial liquidity deposit
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(tokenAmt * ethAmt) - MIN_LIQUIDITY;
            _mint(address(0), MIN_LIQUIDITY);
        } else {
            liquidity = Math.min((tokenAmt * _totalSupply) / _tokenReserve, (ethAmt * _totalSupply) / _ethReserve);
        }

        _mint(to_, liquidity);

        _update(tokenBal, _ethBal);
        // TODO emit Mint event
    }

    // TODO lock
    function burn(address to_) external returns (uint256 tokenAmt, uint256 ethAmt) {
        // get liquidity burned
        uint256 liquidityToBurn = balanceOf[address(this)];
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        uint256 ethBal = address(this).balance;
        uint256 _totalSupply = totalSupply;

        // get token and eth amounts to distribute to LP
        tokenAmt = (tokenBal * liquidityToBurn) / _totalSupply;
        ethAmt = (ethBal * liquidityToBurn) / _totalSupply;

        BananaswapV1Library.transfer(token, to_, tokenAmt);
        _transferEth(to_, ethAmt);

        tokenBal = IERC20(token).balanceOf(address(this));
        ethBal = address(this).balance;

        _update(tokenBal, ethBal);

        _burn(address(this), liquidityToBurn);
    }

    // TODO lock
    function swap(
        uint256 tokensOut_,
        uint256 ethOut_,
        address to_
    ) external {
        require(tokensOut_ > 0 || ethOut_ > 0, "Bananaswap::swap: INSUFFICIENT_AMOUNT_IN");
        require(tokenReserve >= tokensOut_ && ethReserve >= ethOut_, "Bananaswap::swap: INSUFFICIENT_LIQUIDITY");

        if (tokensOut_ > 0) {
            BananaswapV1Library.transfer(token, to_, tokensOut_);
        }

        if (ethOut_ > 0) {
            BananaswapV1Library.transferEth(to_, ethOut_);
        }

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        uint256 ethBal = address(this).balanace;

        uint256 tokensIn = tokenBal > tokenReserve - tokensOut_ ? tokenBal - tokenReserve - tokensOut_ : 0;
        uint256 ethIn = ethBal > ethReserve - ethOut_ ? ethBal - ethReserve - ethOut_ : 0;

        require(tokensIn > 0 || ethIn > 0, "Bananaswap::swap: INSUFFICIENT_AMOUNT_IN");

        // compare balances less fees to K
        uint256 tokenBalLessFee = (tokenBal * 1000) - (tokensIn * 3);
        uint256 ethBalLessFee = (ethBal * 1000) - (ethIn * 3);
        require(tokenBalLessFee * ethBalLessFee >= tokenReserve * ethReserve * 1000**2, "Bananaswap::swap: INVALID_K");

        _update(tokenBal, ethBal);

        // TODO emit Swap event
    }

    // receives ETH payments
    function _receiveEth(uint256 amount_) internal {
        ethBalance += amount_;
    }

    function transferEth() external payable {
        _receiveEth(msg.value);
    }

    function _update(uint256 tokenBalance_, uint256 ethBalance_) private {
        tokenReserve = tokenBalance_;
        ethReserve = ethBalance_;

        // TODO emit Sync event
    }

    // TODO use library fxn
    function _transferEth(address to_, uint256 amount_) internal {
        (bool success, bytes memory data) = to_.call{ value: amount_ }("");
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "BananaswapV1Pair::_transferEth: transfer failed"
        );
    }

    receive() external payable {
        _receiveEth(msg.value);
    }
}
