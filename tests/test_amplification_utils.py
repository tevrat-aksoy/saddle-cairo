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
MIN_RAMP_TIME = 14 * 24 * 60 * 60
MAX_A = 10 ** 6
A_PRECISION = 100
MAX_A_CHANGE = 2


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
async def test_ramp_a(autil_factory):
    account1, account2, amplification_util, starknet = autil_factory

    initial_a_time = 200
    timestamp = 100
    set_block_timestamp(starknet.state, timestamp, 11)

    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_ramp_a",
            [10, 20, initial_a_time, 20, 30, 40],
        ),
        reverted_with="wait 1 day before starting ramp",
    )

    initial_a_time = 100
    timestamp = (24 * 60 * 60) + 200
    set_block_timestamp(starknet.state, timestamp, 11)
    new_future_time = 100

    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_ramp_a",
            [10, 20, initial_a_time, 20, 30, new_future_time],
        ),
        reverted_with="insufficient ramp time",
    )

    new_future_time = 10 + timestamp + MIN_RAMP_TIME
    new_future = 0
    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_ramp_a",
            [10, 20, initial_a_time, 20, new_future, new_future_time],
        ),
        reverted_with="future_a must be > 0 and < MAX_A",
    )

    new_future = MAX_A + 10
    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_ramp_a",
            [10, 20, initial_a_time, 20, new_future, new_future_time],
        ),
        reverted_with="future_a must be > 0 and < MAX_A",
    )

    new_future = 10
    future_time = timestamp - 100
    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_ramp_a",
            [2000, 11000, initial_a_time, future_time, new_future, new_future_time],
        ),
        reverted_with="future_a is too small",
    )

    new_future = 1200
    future_time = timestamp - 100
    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_ramp_a",
            [2000, 11000, initial_a_time, future_time, new_future, new_future_time],
        ),
        reverted_with="future_a is too large",
    )

    new_future = 120
    future_a_precise = new_future * A_PRECISION

    tx4 = await signer.send_transaction(
        account1,
        amplification_util.contract_address,
        "call_ramp_a",
        [2000, 11000, initial_a_time, future_time, new_future, new_future_time],
    )

    tx5 = await amplification_util.get_a_precise().call()

    # assert tx4.result.response[0] == tx5.result.a_precise

    future_a_precise = new_future * A_PRECISION

    assert tx4.result.response[1] == future_a_precise

    assert tx4.result.response[2] == timestamp

    assert tx4.result.response[3] == new_future_time


@pytest.mark.asyncio
async def test_stop_ramp_a(autil_factory):
    account1, account2, amplification_util, starknet = autil_factory

    initial_a_time = 200
    timestamp = 100
    future_a_time = 20
    set_block_timestamp(starknet.state, timestamp, 11)

    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_stop_ramp_a",
            [2000, 11000, initial_a_time, future_a_time],
        ),
        reverted_with="ramp is already stopped",
    )

    await assert_revert(
        signer.send_transaction(
            account1,
            amplification_util.contract_address,
            "call_stop_ramp_a",
            [2000, 11000, initial_a_time, future_a_time],
        ),
        reverted_with="ramp is already stopped",
    )

    await signer.send_transaction(
        account1, amplification_util.contract_address, "call_get_a", [10, 20, 10, 250]
    )

    tx2 = await signer.send_transaction(
        account1,
        amplification_util.contract_address,
        "call_stop_ramp_a",
        [10, 20, 10, 250],
    )
    tx4 = await amplification_util.get_a_precise().call()

    assert tx2.result.response[0] == tx4.result.a_precise

    assert tx2.result.response[1] == tx4.result.a_precise

    assert tx2.result.response[2] == timestamp

    assert tx2.result.response[3] == timestamp
