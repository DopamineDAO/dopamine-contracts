// SPDX-License-Identifier: GPL-3.0

/// @title The Rarity Society ERC-721 token

pragma solidity ^0.8.9;

import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC721CheckpointableUpgradeable } from '../erc721/ERC721CheckpointableUpgradeable.sol';
import { ERC721Upgradeable } from '../erc721/ERC721Upgradeable.sol';

contract MockERC721TokenUpgradeable is Initializable, ERC721CheckpointableUpgradeable, OwnableUpgradeable {

    uint256 public maxSupply;

    address public minter;

    uint256 private _currentId;

    string private constant name_ = 'Rarity Society';
    string private constant symbol_ = 'RARITY';

    function initialize(
        address _minter,
        uint256 _maxSupply
    ) external initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC721_init_unchained(name_, symbol_);
        __ERC721Enumerable_init_unchained(name_, symbol_);
        __EIP712_init_unchained(name_, "1");
        __ERC721Checkpointable_init_unchained(name_);
        __Ownable_init_unchained();

        minter = _minter;
        maxSupply = _maxSupply;
    }

    /**
     * @notice Mint a rarity society.
     */
    function mint() public returns (uint256) {
        require(totalSupply() < maxSupply, "max supply reached");
        return mintToken(_currentId++);
    }

    function mintToken(uint256 tokenId) public returns (uint256) {
        _mint(owner(), minter, tokenId);
        return tokenId;
    }

    function mintTokenTo(uint256 tokenId, address to) public returns (uint256) {
        _mint(owner(), to, tokenId);
        return tokenId;
    }

    function burn(uint256 _tokenId) public {
        _burn(_tokenId);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function testSafe32(uint256 n) public pure returns (uint32) {
        return _safe32(n);
    }

}

