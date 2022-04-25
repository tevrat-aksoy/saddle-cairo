%lang starknet
%builtins pedersen range_check


from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_mul, uint256_le, uint256_lt, uint256_check,
     uint256_eq, uint256_neg,uint256_signed_nn,uint256_unsigned_div_rem
)


struct struct1:
    member initial_a:felt
    member future_a:felt
    member a_len:felt
    member a:felt
end
struct struct2:
    member a:felt
    member b:felt
    member c:felt
end

@external
func try{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self:struct1)->(a_len:felt, a:felt):


    let x=ap
    [x]=Uint256(1,0); ap++
    [x]=Uint256(1,0); ap++

    return(2, x)


end
    
