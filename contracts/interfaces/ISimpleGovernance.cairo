
%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ISimpleGovernance:

    func get_contract_address()->(contract_address:felt):
    end

    func get_governance_address()->(governance_address:felt) :

    end

end