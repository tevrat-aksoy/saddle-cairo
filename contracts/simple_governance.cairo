%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt, assert_not_zero, assert_not_equal

from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

@storage_var
func governance_storage() -> (governance_address : felt):
end
@storage_var
func pending_governance_storage() -> (pending_governance : felt):
end
@event
func set_governance_event(governace_address : felt):
end

@view
func get_governance_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (governance_address : felt):
    let (governance_address) = governance_storage.read()
    return (governance_address)
end

func only_governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller) = get_caller_address()
    let (governance_address) = governance_storage.read()

    with_attr error_message("Only governance can perform this action"):
        assert caller = governance_address
    end
    return ()
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller) = get_caller_address()
    governance_storage.write(caller)
    set_governance_event.emit(caller)
    return ()
end

@external
func change_governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_governance : felt
):
    only_governance()
    let (governance_address) = governance_storage.read()
    with_attr error_message("Governance must be different from current one"):
        assert_not_equal(governance_address, new_governance)
    end
    with_attr error_message("Governance cannot be empty"):
        assert_not_zero(new_governance)
    end
    pending_governance_storage.write(new_governance)
    return ()
end

@external
func accept_governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (pending_governance_address) = pending_governance_storage.read()
    let (caller) = get_caller_address()
    with_attr error_message("change_governance must be called first"):
        assert_not_zero(pending_governance_address)
    end
    with_attr error_message("Only pending governance can accept this role"):
        assert caller = pending_governance_address
    end
    pending_governance_storage.write(0)
    governance_storage.write(caller)
    set_governance_event.emit(caller)
    return ()
end
