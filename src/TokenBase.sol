// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity >=0.8.19;

import "openzeppelin/access/AccessControlEnumerable.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract TokenBase is AccessControlEnumerable, ERC20PresetMinterPauser {
    using SafeERC20 for IERC20;
    mapping(address => bool) public isExempt;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 private constant _BASIS = 10000;

    uint256 public tax = 0;
    uint256 public burn = 0;
    uint256 public maxTax = 0;

    address public taxReceiver;

    bool public isMintable;

    constructor(
        string memory name,
        string memory ticker,
        uint256 initialSupply,
        bool _isMintable,
        bool _isTaxable
    ) ERC20PresetMinterPauser(name, ticker) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _mint(msg.sender, initialSupply);
        taxReceiver = msg.sender;
        isMintable = _isMintable;
        if (_isTaxable) {
            maxTax = 3000;
        } else {
            maxTax = 0;
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        //Handle burn & tax
        if (
            //No tax for exempt
            isExempt[sender] ||
            isExempt[recipient] ||
            //No tax if burn and tax is zero
            (tax + burn) == 0
        ) {
            super._transfer(sender, recipient, amount);
        } else {
            uint256 taxWad = (amount * tax) / _BASIS;
            uint256 burnWad = (amount * burn) / _BASIS;

            if (taxWad > 0) super._transfer(sender, taxReceiver, taxWad);
            if (burnWad > 0) super._burn(sender, burnWad);
            super._transfer(sender, recipient, amount - burnWad - taxWad);
        }
    }

    function setIsExempt(
        address _for,
        bool _to
    ) external onlyRole(MANAGER_ROLE) {
        isExempt[_for] = _to;
    }

    function setIsExemptMulti(
        address[] calldata _fors,
        bool _to
    ) external onlyRole(MANAGER_ROLE) {
        for (uint i; i < _fors.length; i++) {
            isExempt[_fors[i]] = _to;
        }
    }

    function setTaxes(
        uint256 _tax,
        uint256 _burn
    ) external onlyRole(MANAGER_ROLE) {
        require(_tax + _burn <= maxTax, "Cannot set taxes higher than maxTax");
        tax = _tax;
        burn = _burn;
    }

    function setTaxReceiver(address to) external onlyRole(MANAGER_ROLE) {
        taxReceiver = to;
    }

    function recoverERC20(
        address tokenAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(tokenAddress).safeTransfer(
            _msgSender(),
            IERC20(tokenAddress).balanceOf(address(this))
        );
    }
}
