"""contract.cairo test file."""
import os

import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, contract_path

signer = Signer(123456789987654321)
# The path to the contract source code.
@pytest.mark.asyncio
async def test_increase_balance():
    """Test increase_balance method."""
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )

    # Deploy the contract.
    contract = await starknet.deploy(
        source="tests/mocks/contract.cairo",
        constructor_calldata=[account1.contract_address],
    )

    # Invoke increase_balance() twice.
    await contract.increase_balance(amount=10).invoke()
    await contract.increase_balance(amount=20).invoke()

    # Check the result of get_balance().
    execution_info = await contract.get_balance().call()
    assert execution_info.result == (30,)
