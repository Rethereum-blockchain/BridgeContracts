// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {XERC20} from '../contracts/XERC20.sol';
import {IXERC20Factory} from '../interfaces/IXERC20Factory.sol';
import {XERC20Lockbox} from '../contracts/XERC20Lockbox.sol';
import {CREATE3} from 'isolmate/utils/CREATE3.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

contract XERC20Factory is IXERC20Factory {
  using EnumerableSet for EnumerableSet.AddressSet;

  /**
   * @notice Address of the xerc20 maps to the address of its lockbox if it has one
   */
  mapping(address => address) public lockboxRegistry;

  /**
   * @notice The set of registered lockboxes
   */
  EnumerableSet.AddressSet internal _lockboxRegistryArray;

  /**
   * @notice The set of registered XERC20 tokens
   */
  EnumerableSet.AddressSet internal _xerc20RegistryArray;

  /**
   * @notice Deploys an XERC20 contract using CREATE3
   * @dev _limits and _minters must be the same length
   * @param _name The name of the token
   * @param _symbol The symbol of the token
   * @param _minterLimits The array of limits that you are adding (optional, can be an empty array)
   * @param _burnerLimits The array of limits that you are adding (optional, can be an empty array)
   * @param _bridges The array of bridges that you are adding (optional, can be an empty array)
   */

  function deployXERC20(
    string memory _name,
    string memory _symbol,
    uint8 decimals,
    uint256[] memory _minterLimits,
    uint256[] memory _burnerLimits,
    address[] memory _bridges
  ) external returns (address _xerc20) {
    _xerc20 = _deployXERC20(_name, _symbol, decimals, _minterLimits, _burnerLimits, _bridges);

    emit XERC20Deployed(_xerc20);
  }

  /**
   * @notice Deploys an XERC20Lockbox contract using CREATE3
   *
   * @param _xerc20 The address of the xerc20 that you want to deploy a lockbox for
   * @param _baseToken The address of the base token that you want to lock
   * @param _isNative Whether or not the base token is native
   */

  function deployLockbox(
    address _xerc20,
    address _baseToken,
    bool _isNative
  ) external returns (address payable _lockbox) {
    if (_baseToken == address(0) && !_isNative) revert IXERC20Factory_BadTokenAddress();

    if (XERC20(_xerc20).owner() != msg.sender) revert IXERC20Factory_NotOwner();
    if (lockboxRegistry[_xerc20] != address(0)) revert IXERC20Factory_LockboxAlreadyDeployed();

    _lockbox = _deployLockbox(_xerc20, _baseToken, _isNative);

    emit LockboxDeployed(_lockbox);
  }

  /**
   * @notice Loops through the xerc20RegistryArray
   *
   * @param _start The start of the loop
   * @param _amount The end of the loop
   * @return _lockboxes The array of xerc20s from the start to start + amount
   */

  function getRegisteredLockboxes(uint256 _start, uint256 _amount) public view returns (address[] memory _lockboxes) {
    uint256 _length = EnumerableSet.length(_lockboxRegistryArray);
    if (_amount > _length - _start) {
      _amount = _length - _start;
    }

    _lockboxes = new address[](_amount);
    uint256 _index;
    while (_index < _amount) {
      _lockboxes[_index] = EnumerableSet.at(_lockboxRegistryArray, _start + _index);

      unchecked {
        ++_index;
      }
    }
  }

  /**
   * @notice Loops through the xerc20RegistryArray
   *
   * @param _start The start of the loop
   * @param _amount The amount of xerc20s to loop through
   * @return _xerc20s The array of xerc20s from the start to start + amount
   */

  function getRegisteredXERC20(uint256 _start, uint256 _amount) public view returns (address[] memory _xerc20s) {
    uint256 _length = EnumerableSet.length(_xerc20RegistryArray);
    if (_amount > _length - _start) {
      _amount = _length - _start;
    }

    _xerc20s = new address[](_amount);
    uint256 _index;
    while (_index < _amount) {
      _xerc20s[_index] = EnumerableSet.at(_xerc20RegistryArray, _start + _index);

      unchecked {
        ++_index;
      }
    }
  }

  /**
   * @notice Returns if an XERC20 is registered
   *
   * @param _xerc20 The address of the XERC20
   * @return _result If the XERC20 is registered
   */

  function isRegisteredXERC20(address _xerc20) external view returns (bool _result) {
    _result = EnumerableSet.contains(_xerc20RegistryArray, _xerc20);
  }

  /**
   * @notice Deploys an XERC20 contract using CREATE3
   * @dev _limits and _minters must be the same length
   * @param _name The name of the token
   * @param _symbol The symbol of the token
   * @param _minterLimits The array of limits that you are adding (optional, can be an empty array)
   * @param _burnerLimits The array of limits that you are adding (optional, can be an empty array)
   * @param _bridges The array of burners that you are adding (optional, can be an empty array)
   */

  function _deployXERC20(
    string memory _name,
    string memory _symbol,
    uint8 decimals,
    uint256[] memory _minterLimits,
    uint256[] memory _burnerLimits,
    address[] memory _bridges
  ) internal returns (address _xerc20) {
    uint256 _bridgesLength = _bridges.length;
    if (_minterLimits.length != _bridgesLength || _burnerLimits.length != _bridgesLength) {
      revert IXERC20Factory_InvalidLength();
    }

    bytes32 _salt = keccak256(abi.encodePacked(_name, _symbol, msg.sender));
    _xerc20 = address(new XERC20{salt: _salt}(_name, _symbol, decimals, address(this)));

    EnumerableSet.add(_xerc20RegistryArray, _xerc20);

    for (uint256 _i; _i < _bridgesLength; ++_i) {
      XERC20(_xerc20).setLimits(_bridges[_i], _minterLimits[_i], _burnerLimits[_i]);
    }

    XERC20(_xerc20).transferOwnership(msg.sender);
  }

  function _deployLockbox(
    address _xerc20,
    address _baseToken,
    bool _isNative
  ) internal returns (address payable _lockbox) {
    bytes32 _salt = keccak256(abi.encodePacked(_xerc20, _baseToken, msg.sender));
    _lockbox = payable(new XERC20Lockbox{salt: _salt}(_xerc20, _baseToken, _isNative));

    XERC20(_xerc20).setLockbox(address(_lockbox));
    EnumerableSet.add(_lockboxRegistryArray, _lockbox);
    lockboxRegistry[_xerc20] = _lockbox;
  }
}
