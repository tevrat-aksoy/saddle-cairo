from copyreg import constructor
import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, contract_path, str_to_felt, assert_revert
import asyncio


signer = Signer(123456789987654321)
NAME = str_to_felt("Token")


@pytest.fixture(scope="module")
async def simple_governance_factory():
    starknet = await Starknet.empty()

    account1 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )
    account2 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )
    simple_governance = await starknet.deploy(
        source="tests/mocks/simple_governance.cairo",
        constructor_calldata=[account1.contract_address],
    )

    return account1, account2, simple_governance


async def main():
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )
    account2 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )

    simple_governance = await starknet.deploy(
        source="tests/mocks/simple_governance.cairo",
        constructor_calldata=[account1.contract_address],
    )

    print(account1.contract_address)
    print(account2.contract_address)
    tx = await simple_governance.get_pending_governance().call()
    print(tx.result.pending_governance)
    await assert_revert(
        signer.send_transaction(
            account1,
            simple_governance.contract_address,
            "accept_governance",
            [],
        ),
        reverted_with="change_governance must be called first",
    )


loop = asyncio.get_event_loop()
task = loop.create_task(main())

loop.run_until_complete(task)
