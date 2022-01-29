// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./L2DAOTokenLock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @dev An ERC20 token for Layer2DAO. Based on the excellent work done by GasDao.
 *       - Airdrop claim functionality via `claimTokens`. At creation time the tokens that
 *         should be available for the airdrop are transferred to the token contract address;
 *         airdrop claims are made from this balance.
 */
contract L2DAOToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    bytes32 public merkleRoot;

    mapping(address=>bool) private claimed;

    event MerkleRootChanged(bytes32 merkleRoot);
    event Claim(address indexed claimant, uint256 amount);

    // total supply 1 billion, 30% airdrop, 10% devs vested, remainder to DAO Treasury
    uint256 constant airdropSupply = 300_000_000e18;
    uint256 constant teamSupply = 100_000_000e18;
    uint256 constant DAOTreasurySupply = 1_000_000_000e18 - airdropSupply - teamSupply;

    bool public vestStarted = false;

    uint256 public constant claimPeriodEnds = 1646092800;// feb 28, 2022

    /**
     * @dev Constructor.
     * @param DAOTreasuryAddress The address of the DAO Treasury.
     */
    constructor(
        address DAOTreasuryAddress
    )
        ERC20("Layer2DAO", "L2DAO")
        ERC20Permit("Layer2DAO")
    {
        _mint(address(this), airdropSupply);
        _mint(address(this), teamSupply);
        _mint(DAOTreasuryAddress, DAOTreasurySupply);
    }

    function startVest(address tokenLockAddress) public onlyOwner {
        require(!vestStarted, "Layer2DAO: Vest has already started.");
        vestStarted = true;
        _approve(address(this), tokenLockAddress, teamSupply);
        L2DAOTokenLock(tokenLockAddress).lock(0x062a07cBf4848fdA67292A96a5E02C97E402233F, 25_000_000e18);
        L2DAOTokenLock(tokenLockAddress).lock(0x1CabC3e62e0527cBe09917F5Ca8e6D9999502d82, 25_000_000e18);
        L2DAOTokenLock(tokenLockAddress).lock(0x357990585a6BB953DCBA126de48585ed27E22319, 50_000_000e18);
    }

    /**
     * @dev Claims airdropped tokens.
     * @param amount The amount of the claim being made.
     * @param merkleProof A merkle proof proving the claim is valid.
     */
    function claimTokens(uint256 amount, bytes32[] calldata merkleProof) public {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bool valid = MerkleProof.verify(merkleProof, merkleRoot, leaf);
        require(valid, "Layer2DAO: Valid proof required.");
        require(!claimed[msg.sender], "Layer2DAO: Tokens already claimed.");
        claimed[msg.sender] = true;
    
        emit Claim(msg.sender, amount);

        _transfer(address(this), msg.sender, amount);
    }

    /**
     * @dev Allows the owner to sweep unclaimed tokens after the claim period ends.
     * @param dest The address to sweep the tokens to.
     */
    function sweep(address dest) public onlyOwner {
        require(block.timestamp > claimPeriodEnds, "Layer2DAO: Claim period not yet ended");
        _transfer(address(this), dest, balanceOf(address(this)));
    }

    /**
     * @dev Returns true if the claim at the given index in the merkle tree has already been made.
     * @param account The address to check if claimed.
     */
    function hasClaimed(address account) public view returns (bool) {
        return claimed[account];
    }

    /**
     * @dev Sets the merkle root. Only callable if the root is not yet set.
     * @param _merkleRoot The merkle root to set.
     */
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        require(merkleRoot == bytes32(0), "Layer2DAO: Merkle root already set");
        merkleRoot = _merkleRoot;
        emit MerkleRootChanged(_merkleRoot);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
