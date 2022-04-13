
# SPDX-License-Identifier: MIT
%lang starknet


from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address,get_contract_address
from starkware.starknet.common.syscalls import (
    get_block_number,
    get_block_timestamp,
)
from starkware.cairo.common.math import assert_lt, assert_not_zero,assert_le
from starkware.cairo.common.math_cmp  import  (is_le)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_mul, uint256_le, uint256_lt, uint256_check,
     uint256_eq, uint256_neg,uint256_signed_nn,uint256_unsigned_div_rem
)

from contracts.lib.UTILS import (UTILS_assert_uint256_eq,UTILS_assert_uint256_le, UTILS_assert_uint256_lt)
from contracts.interfaces.IERC20 import IERC20
from contracts.interfaces.ISimpleGovernance import ISimpleGovernance

@event
func released_event(amount:Uint256):
end

@event
func vesting_initialized(beneficiary:felt, start_timestamp:felt, cliff: felt, duration: felt):
end

@event 
func set_beneficiary(beneficiary:felt):
end

@storage_var
func beneficiary_storage()->(beneficiary_address:felt):
end

@storage_var
func token_storage()->(token_address:felt):
end

@storage_var
func cliff_in_seconds_storage()->(cliff_in_seconds:felt):
end

@storage_var
func duration_in_seconds_storage()->(duration_in_seconds:felt):
end
@storage_var
func start_timestamp_storage()->(start_timestamp:felt):
end
@storage_var
func released_storage()->(released:Uint256):
end
@storage_var
func simple_governance_storage()->(governance_address):
end


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    governance_address:felt):
    let (sender)= get_caller_address()
    beneficiary_storage.write(sender)
    simple_governance_storage.write(governance_address)

    return()

end

#TODO INITIALIZE FUNCTION
@external
func initialize_vesting{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,range_check_ptr}(  
        token_address:felt,
        beneficiary_address:felt,
        start_timestamp:felt,
        cliff_in_seconds:felt,
        duration_in_seconds:felt,
        ):

    let(beneficiary)=beneficiary_storage.read()
    let (block_timestamp) = get_block_timestamp()
    with_attr error_message("token address can not be 0"):
        assert_not_zero(token_address)
    end
     with_attr error_message("cannot initialize logic contract"):
        assert beneficiary=0
    end

    with_attr error_message("beneficiary address can not be 0"):
        assert_not_zero( beneficiary_address)
    end
    with_attr error_message("start_timestamp cannot be 0"):
        assert_not_zero(start_timestamp)
    end
    with_attr error_message(" startTimestamp cannot be from the future"):
        assert_le(start_timestamp,block_timestamp)
    end
    with_attr error_message("start_timestamp cannot be 0"):
        assert_not_zero(start_timestamp)
    end
    with_attr error_message("cliff is greater than duration"):
        assert_le(cliff_in_seconds,duration_in_seconds)
    end

    token_storage.write(token_address)
    start_timestamp_storage.write(start_timestamp)
    duration_in_seconds_storage.write(duration_in_seconds)
    cliff_in_seconds_storage.write(cliff_in_seconds)

    vesting_initialized.emit(beneficiary_address,start_timestamp,cliff_in_seconds,duration_in_seconds)

    return()
end


@external
func release{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,range_check_ptr}():
    alloc_locals
    let (local vested)=vested_amount()
    with_attr error_message("no tokens to release"):
        UTILS_assert_uint256_lt(Uint256(0,0),vested)
    end
    let (released_old)= released_storage.read()
    let (released_new,carry)= uint256_add(released_old,vested)

    released_storage.write(released_new)

    released_event.emit(vested)
    let (token_address)=token_storage.read()
    let (beneficiary)=beneficiary_storage.read()
    let (token_address)= token_storage.read()
    IERC20.transfer(token_address,beneficiary,vested)
    return()
end

@view
func vested_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    )->(unreleased:Uint256):
    alloc_locals
    let (block_timestamp)= get_block_timestamp()
    let (start_timestamp)= start_timestamp_storage.read()
    let (cliff_in_seconds)= cliff_in_seconds_storage.read()
    let (contract_address)=get_contract_address()
    let(token_address)=token_storage.read()

    let (duration_in_seconds) = duration_in_seconds_storage.read()
    let elapsed_time = block_timestamp-start_timestamp
    let cliff_elapsed_dif =Uint256(cliff_in_seconds-elapsed_time,0)
    let (condition_clif_elapsed)=uint256_signed_nn(cliff_elapsed_dif)
    local zero_uint : Uint256 = Uint256(0, 0)
    
    if condition_clif_elapsed == 1:
        return(zero_uint)
    end
    let elapsed_duration_dif =Uint256(elapsed_time-duration_in_seconds,0) 
    let (condition_elapsed_duration)=uint256_signed_nn(elapsed_duration_dif)

    if condition_elapsed_duration==1:
        let (balance)=IERC20.balanceOf(token_address,contract_address)
        return (balance)
    else:
        let (current_balance)= IERC20.balanceOf(token_address,contract_address)
        let (balance_condition)= uint256_eq( current_balance, Uint256(0,0))
        if balance_condition==0:
            return (zero_uint)
        end
        let (released)= released_storage.read()
        let (total_balance,carry)= uint256_add(current_balance,released)
        let (total_elapsed_mul,total_elapsed_mul_high)=uint256_mul(total_balance,Uint256(elapsed_time,0))
        let (vested,remainder)= uint256_unsigned_div_rem( total_elapsed_mul,Uint256(duration_in_seconds,0))

        let (unreleased)=uint256_sub(vested, released)

        return(unreleased)
    end
        
end


@external
func change_beneficiary{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_beneficiary: felt):

    let (sender) = get_caller_address()
    let (governance_contract_address)=simple_governance_storage.read()
    let (old_beneficiary)=beneficiary_storage.read()

    let (governance)=ISimpleGovernance.get_governance_address(governance_contract_address)
    with_attr error_message("only governance can change beneficiary"): 
        assert sender = governance
    end
    with_attr error_message("beneficiary must be different from current one"): 
        assert_not_zero (new_beneficiary-old_beneficiary)
    end
    
    with_attr error_message("beneficiary can not be zero address"):
        assert_not_zero(new_beneficiary)
    end
    beneficiary_storage.write(new_beneficiary)
    set_beneficiary.emit(new_beneficiary)
    return()
end 