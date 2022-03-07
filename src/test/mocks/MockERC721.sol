// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "../../ERC721/ERC721.sol";

contract MockERC721 is ERC721 {

    bytes public constant DATA = "DOPE";

    constructor(string memory name_, string memory symbol_, uint256 maxSupply_)
        ERC721(name_, symbol_, maxSupply_) {}

    function mint(address to, uint256 id) public virtual {
            _mint(to, id);
        }

    function burn(uint256 id) public virtual {
            _burn(id);
        }

    function mockSafeTransferFromWithoutData(
            address from,
            address to,
            uint256 id
        ) external {
                safeTransferFrom(from, to, id);
            }

    function mockSafeTransferFromWithData(
            address from,
            address to,
            uint256 id
        ) external {
                safeTransferFrom(from, to, id, DATA);
            }

}
