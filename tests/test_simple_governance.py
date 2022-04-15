from copyreg import constructor
import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, contract_path, assert_revert

signer = Signer(123456789987654321)


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


@pytest.mark.asyncio
async def test_get_governance_address(simple_governance_factory):

    account1, account2, simple_governance = simple_governance_factory

    tx = await simple_governance.get_governance_address().call()
    assert tx.result.governance_address == account1.contract_address


@pytest.mark.asyncio
async def test_change_governance(simple_governance_factory):

    account1, account2, simple_governance = simple_governance_factory

    await assert_revert(
        signer.send_transaction(
            account2,
            simple_governance.contract_address,
            "change_governance",
            [account2.contract_address],
        ),
        reverted_with="Only governance can perform this action",
    )

    await assert_revert(
        signer.send_transaction(
            account1,
            simple_governance.contract_address,
            "change_governance",
            [account1.contract_address],
        ),
        reverted_with="Governance must be different from current one",
    )

    await signer.send_transaction(
        account1,
        simple_governance.contract_address,
        "change_governance",
        [account2.contract_address],
    )

    tx2 = await simple_governance.get_pending_governance().call()
    assert tx2.result.pending_governance == account2.contract_address


@pytest.mark.asyncio
async def test_accept_governance(simple_governance_factory):

    account1, account2, simple_governance = simple_governance_factory

    await signer.send_transaction(
        account1,
        simple_governance.contract_address,
        "change_governance",
        [account2.contract_address],
    )
    await assert_revert(
        signer.send_transaction(
            account1,
            simple_governance.contract_address,
            "accept_governance",
            [],
        ),
        reverted_with="Only pending governance can accept this role",
    )

    await signer.send_transaction(
        account2,
        simple_governance.contract_address,
        "accept_governance",
        [],
    )
    tx = await simple_governance.get_pending_governance().call()
    assert tx.result.pending_governance == 0
    tx2 = await simple_governance.get_governance_address().call()
    assert tx2.result.governance_address == account2.contract_address
