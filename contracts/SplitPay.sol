// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SplitPay — native BOT revenue splits. Create once with payees and
/// shares, fund any time, each payee pulls their exact entitlement. Prize
/// splits, band shares, DAO distributions.
contract SplitPay is ReentrancyGuard {
    struct Split {
        address[] payees;
        uint256[] shares;
        uint256 totalShares;
        uint256 totalFunded;
    }

    Split[] private _splits;
    mapping(uint256 => mapping(address => uint256)) public released;

    event SplitCreated(uint256 indexed id, uint256 payees, uint256 totalShares);
    event Funded(uint256 indexed id, address indexed from, uint256 amount);
    event Released(uint256 indexed id, address indexed payee, uint256 amount);

    function create(address[] calldata payees, uint256[] calldata shares) external returns (uint256) {
        require(payees.length == shares.length && payees.length > 0, "Bad input");
        uint256 total;
        for (uint256 i = 0; i < payees.length; i++) {
            require(payees[i] != address(0), "Zero payee");
            require(shares[i] > 0, "Zero share");
            for (uint256 j = 0; j < i; j++) require(payees[j] != payees[i], "Duplicate payee");
            total += shares[i];
        }
        _splits.push();
        Split storage s = _splits[_splits.length - 1];
        for (uint256 i = 0; i < payees.length; i++) {
            s.payees.push(payees[i]);
            s.shares.push(shares[i]);
        }
        s.totalShares = total;
        uint256 id = _splits.length - 1;
        emit SplitCreated(id, payees.length, total);
        return id;
    }

    function fund(uint256 id) external payable nonReentrant {
        require(msg.value > 0, "Bad amount");
        _splits[id].totalFunded += msg.value;
        emit Funded(id, msg.sender, msg.value);
    }

    function shareOf(uint256 id, address payee) public view returns (uint256) {
        Split storage s = _splits[id];
        for (uint256 i = 0; i < s.payees.length; i++) {
            if (s.payees[i] == payee) return s.shares[i];
        }
        return 0;
    }

    function owed(uint256 id, address payee) public view returns (uint256) {
        Split storage s = _splits[id];
        uint256 sh = shareOf(id, payee);
        if (sh == 0) return 0;
        return (s.totalFunded * sh) / s.totalShares - released[id][payee];
    }

    function release(uint256 id, address payee) external nonReentrant {
        uint256 pay = owed(id, payee);
        require(pay > 0, "Nothing owed");
        released[id][payee] += pay;
        (bool ok, ) = payee.call{value: pay}("");
        require(ok, "Pay failed");
        emit Released(id, payee, pay);
    }

    function totalSplits() external view returns (uint256) {
        return _splits.length;
    }

    function getSplit(uint256 id)
        external
        view
        returns (address[] memory payees, uint256[] memory shares, uint256 totalShares, uint256 totalFunded)
    {
        Split storage s = _splits[id];
        return (s.payees, s.shares, s.totalShares, s.totalFunded);
    }
}
