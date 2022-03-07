// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "../../interfaces/IDopamineAuctionHouseToken.sol";
import { ERC721 } from '../../erc721/ERC721.sol';

/// @notice Error purposely thrown for testing minting failure.
error ThrowingMint();

contract MockDopamineAuctionHouseToken is ERC721, IDopamineAuctionHouseToken {

    string private constant NAME = 'Dopamine';
    string private constant SYMBOL = 'DOPE';

    bool public mintDisabled;
    address public minter;

    constructor(address minter_, uint256 maxSupply_) ERC721(NAME, SYMBOL, maxSupply_) {
        minter = minter_;
    }

    function disableMinting() public {
        mintDisabled = true;
    }

    function enableMinting() public {
        mintDisabled = false;
    }

    function mint() public override returns (uint256) {
        if (mintDisabled) {
            revert ThrowingMint();
        }
        uint256 id = totalSupply;
        _mint(minter, id);
        return id;
    }

}

