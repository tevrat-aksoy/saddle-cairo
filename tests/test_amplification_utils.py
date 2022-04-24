from copyreg import constructor
import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.business_logic.state.state import BlockInfo
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


def set_block_timestamp(starknet_state, timestamp, gasprice):
    starknet_state.state.block_info = BlockInfo(
        starknet_state.state.block_info.block_number, timestamp, gasprice
    )


@pytest.fixture(scope="module")
async def autil_factory():
    starknet = await Starknet.empty()

    account1 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )
    account2 = await starknet.deploy(
        source="openzeppelin/account/Account.cairo",
        constructor_calldata=[signer.public_key],
    )
    amplification_util = await starknet.deploy(
        source="tests/mocks/amplification_utils.cairo", constructor_calldata=[]
    )

    return account1, account2, amplification_util, starknet


@pytest.mark.asyncio
async def test_get_a_precise(autil_factory):
    account1, account2, amplification_util, starknet = autil_factory
    set_block_timestamp(starknet.state, 100, 11)

    tx1 = await amplification_util.get_timestamp().call()
    assert tx1.result.timestamp == 100

    await signer.send_transaction(
        account1, amplification_util.contract_address, "call_get_a", [10, 20, 10, 50]
    )

    tx2 = await amplification_util.get_a_precise().call()
    assert tx2.result.a_precise == 20

    a0 = 10
    a1 = 20
    t0 = 10
    t1 = 110

    await signer.send_transaction(
        account1, amplification_util.contract_address, "call_get_a", [a0, a1, t0, t1]
    )
    tx3 = await amplification_util.get_a_precise().call()

    expected1 = a0 + (a1 - a0) * (tx1.result.timestamp - t0) / (t1 - t0)
    assert tx3.result.a_precise == int(expected1)

    a0 = 20
    a1 = 10
    await signer.send_transaction(
        account1, amplification_util.contract_address, "call_get_a", [a0, a1, t0, t1]
    )
    tx4 = await amplification_util.get_a_precise().call()

    expected2 = a0 - ((a0 - a1) * (tx1.result.timestamp - t0) / (t1 - t0))
    assert tx4.result.a_precise == int(expected2)


@pytest.mark.asyncio
async def test_get_a_precise(autil_factory):
    account1, account2, amplification_util, starknet = autil_factory
    set_block_timestamp(starknet.state, 100, 11)