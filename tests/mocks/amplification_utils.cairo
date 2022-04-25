%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
    uint256_neg,
    uint256_signed_nn,
    uint256_unsigned_div_rem,
)

from openzeppelin.security.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_checked_div_rem,
)

from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_le, unsigned_div_rem

from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

from contracts.swap_utils import (
    AMPLIFICATION_UTIL_A_PRECISION,
    AMPLIFICATION_UTIL_MAX_A,
    AMPLIFICATION_UTIL_MAX_A_CHANGE,
    AMPLIFICATION_UTIL_MIN_RAMP_TIME,
    AMPLIFICATION_UTIL_get_a,
    AMPLIFICATION_UTIL_get_a_precise,
    AMPLIFICATION_UTIL_ramp_a,
    AMPLIFICATION_UTIL_stop_ramp_a,
    SWAP_UTIL_swap
)


func define_swap_struct{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    initial_a:felt, 
    future_a:felt,
    initial_a_time:felt,
    future_a_time:felt,
    )->(swap:SWAP_UTIL_swap):
    alloc_locals


    let  new_swap:SWAP_UTIL_swap=SWAP_UTIL_swap(initial_a,future_a,initial_a_time,future_a_time,
                0,0,0,0,0,0,0,0,0,0,Uint256(0, 0),Uint256(0, 0), Uint256(0, 0) )

    return (new_swap)

end

@storage_var
func a_precise_storage()->(a_precise:felt):
end

@storage_var
func ramp_a_storage()->(ramp_a:felt):
end
@view
func get_a_precise{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (a_precise : felt):
    let (a_precise) = a_precise_storage.read()
    return (a_precise)
end

@view
func get_timestamp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (timestamp : felt):
    let (timestamp) = get_block_timestamp()
    return (timestamp)
end

@view
func get_ramp_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (ramp_a : felt):
    let (ramp_a) = ramp_a_storage.read()
    return (ramp_a)
end

@external
func call_get_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    initial_a_diff:felt, 
    future_a_diff:felt,
    initial_a_time_diff:felt,
    future_a_time_diff:felt,
    )->(a_precise:felt):
    alloc_locals
    let (local swap)=define_swap_struct(initial_a_diff, future_a_diff, initial_a_time_diff, future_a_time_diff)

    let (local a_precise)=AMPLIFICATION_UTIL_get_a_precise(swap)
    a_precise_storage.write(a_precise)

    return(a_precise)
end

@external
func call_stop_ramp_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    initial_a_diff:felt, 
    future_a_diff:felt,
    initial_a_time_diff:felt,
    future_a_time_diff:felt,
    )->(out_init_a:felt, out_future_a:felt,out_init_a_time:felt, out_future_a_time:felt ):
    alloc_locals
    let (local swap)=define_swap_struct(initial_a_diff, future_a_diff, initial_a_time_diff, future_a_time_diff)

    let (local new_swap)=AMPLIFICATION_UTIL_stop_ramp_a(swap)
    
    let out_init_a=new_swap.initial_a
    let out_future_a=new_swap.future_a
    let out_init_a_time=new_swap.initial_a_time
    let out_future_a_time=new_swap.future_a_time
    
    return(out_init_a,out_future_a,out_init_a_time,out_future_a_time)
end

@external
func call_ramp_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    initial_a:felt, 
    future_a:felt,
    initial_a_time:felt,
    future_a_time:felt,
    new_future_a:felt,
    new_future_time:felt,
    )->(out_init_a:felt, out_future_a:felt,out_init_a_time:felt, out_future_a_time:felt ):
    alloc_locals
 
    let (local swap)=define_swap_struct(initial_a, future_a, initial_a_time, future_a_time)

    let (local new_swap)=AMPLIFICATION_UTIL_ramp_a(swap,new_future_a,new_future_time )
    
    let out_init_a=new_swap.initial_a
    let out_future_a=new_swap.future_a
    let out_init_a_time=new_swap.initial_a_time
    let out_future_a_time=new_swap.future_a_time
    
    return(out_init_a,out_future_a,out_init_a_time,out_future_a_time)
end