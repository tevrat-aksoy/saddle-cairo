%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.alloc import alloc
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
from starkware.cairo.common.math import assert_le,assert_lt, unsigned_div_rem

from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp


@storage_var
func vote_token_storage()->(token_address):
end


@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_address:felt)
    vote_token_storage.write(token_address)
    
end

