from copyreg import constructor
import pytest
import asyncio
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

    tx1 = await vesting.get_timestamp().invoke()
    timestamp = tx1.result.timestamp
    print(timestamp)
    await assert_revert(
        signer.send_transaction(
            account1,
            vesting.contract_address,
            "initialize_vesting",
            [
                token.contract_address,
                account1.contract_address,
                timestamp - 1,
                100,
                0,
            ],
        ),
        reverted_with="duration cannot be 0",
    )


""" 
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
"""

loop = asyncio.get_event_loop()
task = loop.create_task(main())

loop.run_until_complete(task)
