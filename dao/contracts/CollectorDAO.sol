//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./CollectorBase.sol";

// TODO remove
import "hardhat/console.sol";

contract CollectorDAO is CollectorBase {
    address public guardian;
    mapping(uint256 => Proposal) public proposals;
    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;
    mapping(address => bool) public members;

    constructor() {
        // TODO send guardian_ in as a param
        guardian = msg.sender;
    }

    function _hashProposal(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, signatures, calldatas, descriptionHash)));
    }

    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        string[] memory signatures_,
        bytes[] memory calldatas_,
        string memory description_
    ) external returns (uint256) {
        require(members[msg.sender], "Only members can vote.");
        require(targets_.length == values_.length, "Proposal function information arity mismatch; values");
        require(targets_.length == signatures_.length, "Proposal function information arity mismatch; signatures");
        require(targets_.length == calldatas_.length, "Proposal function information arity mismatch; calldatas");

        uint256 proposalId = _hashProposal(targets_, values_, signatures_, calldatas_, keccak256(bytes(description_)));

        Proposal storage proposal = proposals[proposalId]; // creates proposal
        require(proposal.startBlock == 0, "This proposal already exists.");
        latestProposalIds[msg.sender] = proposalId;

        uint256 endBlock = block.number + _votingPeriod();

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        // eta = 0; // TODO ??
        proposal.targets = targets_;
        proposal.values = values_;
        proposal.signatures = signatures_;
        proposal.calldatas = calldatas_;
        proposal.startBlock = block.number;
        proposal.endBlock = endBlock;
        // forVotes: 0;
        // againstVotes: 0;
        // abstainVotes: 0;
        // canceled: false;
        // executed: false

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets_,
            values_,
            signatures_,
            calldatas_,
            block.number,
            endBlock,
            description_
        );

        return proposalId;
    }

    function buyMembership() external payable {
        require(!members[msg.sender], "Already a member.");
        require(msg.value == 1 ether, "Membership costs exactly 1 ETH.");

        members[msg.sender] = true;
    }
}
