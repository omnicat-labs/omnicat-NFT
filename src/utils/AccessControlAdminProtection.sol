// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title AccessControlAdminProtection
 * @author Relative Finance
 * @notice AccessControl with additional protections to mitigate the chance of having no admin.
 */
abstract contract AccessControlAdminProtection is AccessControlEnumerable {
    function revokeRole(
        bytes32 role,
        address account
    ) public virtual override(AccessControl, IAccessControl) {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(
                getRoleMemberCount(DEFAULT_ADMIN_ROLE) > 1,
                "cannot revoke last admin"
            );
        }
        super.revokeRole(role, account);
    }

    function renounceRole(
        bytes32 role,
        address account
    ) public virtual override(AccessControl, IAccessControl) {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(
                getRoleMemberCount(DEFAULT_ADMIN_ROLE) > 1,
                "last admin cannot renounce"
            );
        }
        super.renounceRole(role, account);
    }
}
