// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./UUPSUpgradeableMock.sol";

// This contract implements the pre-4.5 UUPS upgrade function with a rollback test.
// It's used to test that newer UUPS contracts are considered valid upgrades by older UUPS contracts.
contract UUPSUpgradeableLegacyMock is UUPSUpgradeableMock {
    // Inlined from ERC1967Utils
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    // ERC1967Utils._setImplementation is private so we reproduce it here.
    // An extra underscore prevents a name clash error.
    function __setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(ERC1967Utils.IMPLEMENTATION_SLOT).value = newImplementation;
    }

    function _upgradeToAndCallSecureLegacyV1(address newImplementation, bytes memory data, bool forceCall) internal {
        address oldImplementation = ERC1967Utils.getImplementation();

        // Initial upgrade and setup call
        __setImplementation(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }

        // Perform rollback test if not already in progress
        StorageSlot.BooleanSlot storage rollbackTesting = StorageSlot.getBooleanSlot(_ROLLBACK_SLOT);
        if (!rollbackTesting.value) {
            // Trigger rollback using upgradeTo from the new implementation
            rollbackTesting.value = true;
            Address.functionDelegateCall(newImplementation, abi.encodeCall(this.upgradeTo, (oldImplementation)));
            rollbackTesting.value = false;
            // Check rollback was effective
            require(
                oldImplementation == ERC1967Utils.getImplementation(),
                "ERC1967Utils: upgrade breaks further upgrades"
            );
            // Finally reset to the new implementation and log the upgrade
            ERC1967Utils.upgradeTo(newImplementation);
        }
    }

    // hooking into the old mechanism
    function upgradeTo(address newImplementation) public override {
        _upgradeToAndCallSecureLegacyV1(newImplementation, bytes(""), false);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) public payable override {
        _upgradeToAndCallSecureLegacyV1(newImplementation, data, false);
    }
}