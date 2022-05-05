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

# DAO token  address
@storage_var
func vote_token_storage()->(token_address):
end

@storage_var
func proposal_storage(proposal_no:felt)->(proposal:proposal_core)
end

@storage_var
func last_proposal_no_storage()->(proposal_no:felt)
end

struct proposal_core:
    member vote_start:felt
    member vote_end:felt
    member executed:felt
    member canceled:felt
end

@view
func get_proposal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proposal_no:felt)->(proposal:proposal_core)
    let (proposal:proposal_core)= proposal_storage.read(proposal_no)
    return(proposal)
end

@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(token_address:felt,governance: felt)
    vote_token_storage.write(token_address)
    
end


func only_governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller) = get_caller_address()
    let (governance_address) = governance_storage.read()

    with_attr error_message("Only governance can perform this action"):
        assert caller = governance_address
    end
    return ()
end



@external
func create_new_proposal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    vote_end:felt):

    let (vote_start)=get_block_timestamp()

    local new_proposal:proposal_core=proposal_core(
        vote_start,
        vote_end,
        0,
        0,
        )
    let (last_proposal_no)=last_proposal_no_storage.read()
    proposal_storage.write(last_proposal_no+1,new_proposal)
    last_proposal_no_storage.write(last_proposal_no+1)

end


