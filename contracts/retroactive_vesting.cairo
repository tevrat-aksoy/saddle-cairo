# SPDX-License-Identifier: MIT
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt, assert_not_zero, assert_not_equal
from contracts.interfaces.IERC20 import IERC20
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import (
    get_block_number,
    get_block_timestamp,
)
struct vesting_data:
    member is_verified : felt
    member total_amount : felt
    member released : felt
end

@event
func claimed(account : felt, amount : Uint256):
end

@storage_var
func token_address_storage() -> (token_address : felt):
end
@storage_var
func merkle_root_storage() -> (merkle_root : felt):
end
@storage_var
func start_timestamp_storage() -> (start_timestamp : felt):
end

@storage_var
func duration_storage() -> (duration_felt):
end

@storage_var
func vestings_storage(adress : felt) -> (vestings : vesting_data):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_address : felt, merkle_root : felt, start_timestamp : felt
):
    with_attr error_message("token address cannot be 0"):
        assert_not_zero(token_address)
    end
    with_attr error_message("merkle root  cannot  be 0"):
        assert_not_zero(merkle_root)
    end
    with_attr error_message("start timestamp cannot be 0"):
        assert_not_zero(start_timestamp)
    end

    token_address_storage.write(token_address)
    merkle_root_storage.write(merkle_root)
    start_timestamp_storage.write(start_timestamp)
    return ()
end

@external
func verify_and_claim{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt, total_amount : felt, merkle_proof : felt
):
    with_attr error_message("total   amount cannot be 0"):
        assert_not_zero(total_amount)
    end
    let (vesting) = vestings_storage.read(account)

    # TODO: implemnent merkle proof
    if vesting.is_verified == 0:
        vesting.is_verified = 1
        vesting.total_amount = total_amount
    end
    claim_reward_internal(account)
    return ()
end

@external
func claim_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
):
    let (vesting) = vestings_storage.read(account)
    let (caller) = get_caller_address()

    if account == 0:
        with_attr error_message("must verify first"):
            assert_not_zero(vesting.is_verified)
        end
        claim_reward_internal(caller)
    else:
        with_attr error_message("must verify first"):
            assert_not_zero(vesting.is_verified)
        end
        claim_reward_internal(account)
    end
    return ()
end

func claim_reward_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
):
    let (vestings) = vestings_storage.read(account)
    let released = vestings.released
    let amount = vested_amount(account)
    return ()
end

@view
func vested_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (not_released_amount : felt):
    let (vestings) = vestings_storage.read(account)
    with_attr error_message("must verify first"):
        assert vestings.is_verified = 1
    end
    let (start_timestamp) = start_timestamp_storage.read()
    let (duration) = duration_storage.read()
    let (not_released_amount) = vested_amount_internal(
        vestings.total_amount, vestings.released, start_timestamp, duration
    )

    return (not_released_amount)
end

@view
func vested_amount_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    total : felt, released : felt, start_timestamp : felt, duration_in_seconds : felt
) -> (not_released_amount : felt):
    let block_timestamp = get_block_timestamp()
    let (time_check) = is_le(block_timestamp, start_timestamp)
    if timecheck == 1:
        return (0)
    end

    let (elapsed_time) = block_timestamp - start_timestamp

    let (elapsed_time_check) = is_le(duration_in_seconds, elapsed_time)
    if elapsed_time == 1:
        return (total - released)
    else:
        let (total_elapsed_mul) = total * elapsed_time
        let (vested) = total_elapsed_mul / duration_in_seconds
        let not_released_amount = vested - released
        return (not_released_amount)
    end
end
