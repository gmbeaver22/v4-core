// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Exttload} from "../src/Exttload.sol"; // Assuming Exttload is in the src folder
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

contract Loadable is Exttload {}

/// @author gmbeaver22 <https://github.com/gmbeaver22>
contract ExttloadTest is Test, GasSnapshot {
    Loadable loadable = new Loadable();

    function test_load10_transient() public {
        bytes32[] memory keys = new bytes32[](10);
        for (uint256 i = 0; i < keys.length; i++) {
            keys[i] = keccak256(abi.encode(i));
            // Since Exttload uses transient storage, we store directly in memory
            assembly {
                mstore(slot(loadable, i), bytes32(i))
            }
        }

        bytes32[] memory values = loadable.exttload(keys);
        snapLastCall("transient external tload"); // Adjust the label based on your naming convention
        assertEq(values.length, keys.length);
        for (uint256 i = 0; i < values.length; i++) {
            assertEq(values[i], bytes32(i));
        }
    }

    function test_fuzz_exttload(uint256 length, uint256 seed, bytes memory dirtyBits) public {
        length = bound(length, 0, 1000);
        bytes32[] memory slots = new bytes32[](length);
        bytes32[] memory expected = new bytes32[](length);
        for (uint256 i; i < length; ++i) {
            slots[i] = keccak256(abi.encode(i, seed));
            expected[i] = bytes32(i);
            // Store directly in memory for transient storage access
            assembly {
                mstore(slot(loadable, i), expected[i])
            }
        }
        bytes32[] memory values = loadable.exttload(slots);
        assertEq(values, expected);

        // Test with dirty bits (similar logic as in the Extsload test)
        bytes memory data = abi.encodeWithSignature("exttload(bytes32[])", (slots));
        bytes memory malformedData = bytes.concat(data, dirtyBits);
        (bool success, bytes memory returnData) = address(loadable).staticcall(malformedData);
        assertTrue(success, "exttload failed");
        assertEq(returnData.length % 0x20, 0, "return data length is not a multiple of 32");
        assertEq(abi.decode(returnData, (bytes32[])), expected);
    }
}
