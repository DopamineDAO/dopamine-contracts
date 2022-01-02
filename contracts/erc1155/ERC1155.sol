pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

abstract contract ERC1155 is IERC1155, IERC1155MetadataURI {

    error ArrayMismatch();

    // Receiving contract does not implement onERC1155Received
    error InvalidReceiver();

    // Sender is not owner nor operator
    error InvalidOperator();

    error InsufficientBalance();

    error ZeroAddressReceiver();

    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 private constant _ERC1155_METADATA_INTERFACE_ID = 0x0e89341c;

    mapping(uint256 => mapping(address  => uint256)) private _balances;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == _ERC165_INTERFACE_ID ||
            interfaceId == _ERC1155_INTERFACE_ID ||
            interfaceId == _ERC1155_METADATA_INTERFACE_ID;
    }

    function uri(uint256 id) public view virtual returns (string memory);

    function balanceOf(address owner, uint256 id) public view virtual returns (uint256) {
        return _balances[id][owner];
    }

    function balanceOfBatch(address[] memory owners, uint256[] memory ids) public view virtual returns (uint256[] memory) {
        if (owners.length != ids.length) {
            revert ArrayMismatch();
        }

        uint256[] memory batchBalances = new uint256[](owners.length);
        unchecked {
            for (uint256 i = 0; i < owners.length; i++) {
                batchBalances[i] = balanceOf(owners[i], ids[i]);
            }
        }
        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) {
            revert InvalidOperator();
        }
        

        if (to == address(0)) {
            revert ZeroAddressReceiver();
        }

        _beforeTokenTransfer(from, to, _asSingletonArray(id), _asSingletonArray(amount));

        uint256 balance = _balances[id][from];
        if (balance < amount) {
            revert InsufficientBalance();
        }

        unchecked {
            _balances[id][from] = balance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        if (to.code.length != 0 && IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, amount, data) != IERC1155Receiver.onERC1155Received.selector) {
            revert InvalidReceiver();
        }

    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) {
            revert InvalidOperator();
        }

        if (ids.length != amounts.length) {
            revert ArrayMismatch();
        }

        if (to == address(0)) {
            revert ZeroAddressReceiver();
        }

        _beforeTokenTransfer(from, to, ids, amounts);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 balance = _balances[id][from];
            if (balance < amount) {
                revert InsufficientBalance();
            }

            unchecked {
                i++;
                _balances[id][from] = balance - amount;
            }
            _balances[id][to] += amount; // Max supply = 10k so no overflow
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        if (to.code.length != 0 && IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) != IERC1155Receiver.onERC1155BatchReceived.selector) {
            revert InvalidReceiver();
        }

    }

    function _mint(
        address creator,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        _beforeTokenTransfer(address(0), to, _asSingletonArray(id), _asSingletonArray(amount));

        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, address(0), creator, id, amount);
        emit TransferSingle(msg.sender, creator, to, id, amount);

        if (to.code.length != 0 && IERC1155Receiver(to).onERC1155Received(msg.sender, creator, id, amount, data) != IERC1155Receiver.onERC1155Received.selector) {
            revert InvalidReceiver();
        }
    }

    function _batchMint(
        address creator,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (ids.length != amounts.length) {
            revert ArrayMismatch();
        }
        
        _beforeTokenTransfer(address(0), to, ids, amounts);

        for (uint256 i = 0; i < ids.length; ) {
            _balances[ids[i]][to] += amounts[i]; 
            unchecked {
                i++;
            }
        }

        emit TransferBatch(msg.sender, address(0), creator, ids, amounts);
        emit TransferBatch(msg.sender, creator, to, ids, amounts);

        if (to.code.length != 0 && IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, creator, ids, amounts, data) != IERC1155Receiver.onERC1155BatchReceived.selector) {
            revert InvalidReceiver();
        }
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        _beforeTokenTransfer(from, address(0), _asSingletonArray(id), _asSingletonArray(amount));

        uint256 balance = _balances[id][from];
        if (balance < amount) {
            revert InsufficientBalance();
        }
        unchecked {
            _balances[id][from] = balance - amount;
        }

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        if (ids.length != amounts.length) {
            revert ArrayMismatch();
        }

        _beforeTokenTransfer(from, address(0), ids, amounts);

        for (uint256 i = 0; i < ids.length; ) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 balance = _balances[id][from];
            if (balance < amount) {
                revert InsufficientBalance();
            }
            unchecked {
                _balances[id][from] = balance - amount;
                i++;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {}

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }

}
