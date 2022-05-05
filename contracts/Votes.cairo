%lang starknet
%builtins pedersen range_check

@storage_var
func Votes_check_point_storage(account:felt,block_number:felt)->(value:Uint256):
end

@storage_var
func Votes_latest_storage()->(block_number:felt):
end

func Votes_get_votes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt)->(value:Uint256):

    let (latest_block)=Votes_latest_storage.read()
    let (value)=Votes_check_point_storage.read(account, latest_block)

    return (value)
end

func Votes_get_past_votes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt,block_number:felt)->(value:Uint256):

    let (value)=Votes_check_point_storage.read(account, block_number)
    return (value)

end

func Votes_get_at_block{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account:felt, block_number:felt)->(value:Uint256):

    let (current_block)=get_block_number()

    with_attr error_message("timestamp cannot be in the future"):
        assert_le(block_number,current_block)
    end

    let (value)=Votes_check_point_storage.read(account, block_number)
    return(value)
end


func Votes_new_checkpoint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}()->(timestamp:felt)



