

%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt, assert_not_zero

from starkware.starknet.common.syscalls import (get_contract_address, get_caller_address)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_mul, uint256_le, uint256_lt, uint256_check, uint256_eq, uint256_neg
)

from openzeppelin.security.reentrancy_guard  import(
    ReentrancyGuard_start,
    ReentrancyGuard_end
    )


@storage_var
func token_indexes(token_address:felt)->(index:felt):
end

@event
func token_swap(
        buyer_address:felt,
        tokenSold:Uint256,
        tokensBought:Uint256,
        soldId:Uint256,
        boughtId:Uint256, ):
end