from copyreg import constructor
import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer,
    to_uint,
    add_uint,
    sub_uint,
    str_to_felt,
    MAX_UINT256,
    ZERO_ADDRESS,
    INVALID_UINT256,
    TRUE,
    get_contract_def,
    cached_contract,
    assert_revert,
    assert_event_emitted,
    contract_path,
)

signer = Signer(123456789987654321)
RECIPIENT = 123
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(200)
UINT_ONE = to_uint(1)
UINT_ZERO = to_uint(0)
NAME = str_to_felt("Token")
SYMBOL = str_to_felt("TKN")
DECIMALS = 18


@pytest.fixture(scope="module")
async def vesting_factory():
    starknet = await Starknet.empty()

    account1 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )
    account2 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )
    token = await starknet.deploy(
        source="openzeppelin/token/erc20/ERC20.cairo",
        constructor_calldata=[
            NAME,
            SYMBOL,
            DECIMALS,
            *INIT_SUPPLY,
            account1.contract_address,  # recipient
        ],
    )
    simple_governance = await starknet.deploy(
        source="tests/mocks/simple_governance.cairo",
        constructor_calldata=[account1.contract_address],
    )

    vesting = await starknet.deploy(
        source="tests/mocks/vesting.cairo",
        constructor_calldata=[
            account1.contract_address,
            simple_governance.contract_address,
        ],
    )

    return account1, account2, vesting, simple_governance, token


@pytest.mark.asyncio
async def test_vesting_constructor(vesting_factory):
    account1, account2, vesting, simple_governance, token = vesting_factory

    tx = await vesting.get_beneficiary_address().call()
    assert tx.result.beneficiary == account1.contract_address
    tx2 = await vesting.get_simple_governance_address().call()
    assert tx2.result.simple_governance == simple_governance.contract_address


@pytest.mark.asyncio
async def test_initialize_vesting(vesting_factory):
    account1, account2, vesting, simple_governance, token = vesting_factory

    await assert_revert(
        signer.send_transaction(
            account1,
            vesting.contract_address,
            "initialize_vesting",
            [0, account1.contract_adress, 100000, 100, 10],
        ),
        reverted_with="token address can not be 0",
    )

    tx1 = await vesting.get_beneficiary_address().invoke()
    assert tx1.result.beneficiary == 0

    await assert_revert(
        signer.send_transaction(
            account1,
            vesting.contract_address,
            "initialize_vesting",
            [token.contract_address, 0, 100000, 100, 10],
        ),
        reverted_with="beneficiary address can not be 0",
    )
    await assert_revert(
        signer.send_transaction(
            account1,
            vesting.contract_address,
            "initialize_vesting",
            [token.contract_address, account1.contract_address, 0, 100, 10],
        ),
        reverted_with="start_timestamp cannot be 0",
    )
    tx2 = await vesting.get_timestamp().invoke()
    timestamp = tx1.result.timestamp

    await assert_revert(
        signer.send_transaction(
            account1,
            vesting.contract_address,
            "initialize_vesting",
            [
                token.contract_address,
                account1.contract_address,
                timestamp + 100,
                100,
                10,
            ],
        ),
        reverted_with="startTimestamp cannot be from the future",
    )
