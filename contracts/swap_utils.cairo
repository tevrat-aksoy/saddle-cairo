%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
    uint256_neg,
    uint256_signed_nn,
    uint256_unsigned_div_rem,
)

from openzeppelin.security.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_checked_div_rem,
)

from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_le,assert_lt, unsigned_div_rem

from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from contracts.interfaces.IERC20_lp_token import IERC20_lp_token

@event
func AMPLIFICATION_UTIL_ramp_a_event(
    old_a : felt, new_a : felt, initial_time : felt, future_time : felt
):
end
@event
func AMPLIFICATION_UTIL_stop_rump_a_event(current_a : felt, time : felt):
end

const AMPLIFICATION_UTIL_A_PRECISION = 100
const AMPLIFICATION_UTIL_MAX_A = 10 ** 6
const AMPLIFICATION_UTIL_MAX_A_CHANGE = 2


const AMPLIFICATION_UTIL_MIN_RAMP_TIME = 14 * 24 * 60 * 60

# TODO: check for felt-uint256values
@event
func SWAP_UTIL_token_swap(
    buyer : felt, tokens_sold : felt, tokens_bought : felt, sold_id : felt, bought_id : felt
):
end

# instead of array in struct define 3 tokens
@event
func SWAP_UTIL_add_liquidity(
    provider : felt,
    number_of_token : felt,
    token1_amount : felt,
    token2_amount : felt,
    token3_amount : felt,
    fee1 : felt,
    fee2 : felt,
    fee3 : felt,
    invariant : felt,
    lp_token_supply : felt,
):
end
@event
func SWAP_UTIL_remove_liquidity(
    provider : felt,
    number_of_token : felt,
    tokens1_amount : felt,
    tokens2_amount : felt,
    tokens3_amount : felt,
    lp_token_supply : felt,
):
end

@event
func SWAP_UTIL_remove_liquidity_one(
    provider_address : felt,
    lp_tokens_amount : felt,
    lp_token_supply : felt,
    bought_id : felt,
    tokens_bought : felt,
):
end

@event
func SWAP_UTIL_remove_liquidity_imbalance(
    provider : felt,
    number_of_token : felt,
    token1_amount : felt,
    token2_amount : felt,
    token3_amount : felt,
    fee1 : felt,
    fee2 : felt,
    fee3 : felt,
    invariant : felt,
    lp_token_supply : felt,
):
end
@event
func SWAP_UTIL_new_admin_fee(new_admin_fee : felt):
end

@event
func SWAP_UTIL_new_swap_fee(new_swap_fee : felt):
end

# TODO arrays in struct
struct SWAP_UTIL_swap:
    member initial_a : felt
    member future_a : felt
    member initial_a_time : felt
    member future_a_time : felt
    member swap_fee : felt
    member admin_fee : felt
    member lp_token_address : felt
    member number_of_token : felt
    member token1_address : felt
    member token2_address : felt
    member token3_address : felt
    member token1_precision_with_multiplier : felt
    member token2_precision_with_multiplier : felt
    member token3_precision_with_multiplier : felt
    member token1_balance : Uint256
    member token2_balance : Uint256
    member token3_balance : Uint256
end

struct SWAP_UTIL_calculate_withdraw_token_dy_info:
    member d0 : felt
    member d1 : felt
    member new_y : felt
    member fee_pert_token : felt
    member precise_a : felt
end
struct SWAP_UTIL_manage_liqudity_info:
    member d0 : felt
    member d1 : felt
    member d2 : felt
    member precise_a : felt
    member lp_token_address : felt
    member number_of_token : felt
    member total_supply : Uint256
    member token1_balance : Uint256
    member token2_balance : Uint256
    member token3_balance : Uint256
    member token1_multiplier : felt
    member token2_multiplier : felt
    member token3_multiplier : felt
end

const SWAP_UTIL_POOL_PRECISION_DECIMALS = 18
const SWAP_UTIL_FEE_DENOMINATOR = 10 ** 10
const SWAP_UTIL_MAX_SWAP_FEE = 10 ** 8
const SWAP_UTIL_MAX_ADMIN_FEE = 10 ** 10
const SWAP_UTIL_MAX_LOOP_LIMIT = 256

func AMPLIFICATION_UTIL_get_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self : SWAP_UTIL_swap
) -> (a_result : felt):
    alloc_locals

    let (a_precise) = AMPLIFICATION_UTIL_get_a_precise(self)
    let (a_result, _remeain) = unsigned_div_rem(a_precise, AMPLIFICATION_UTIL_A_PRECISION)
    return (a_result)
end

func AMPLIFICATION_UTIL_get_a_precise{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(self : SWAP_UTIL_swap) -> (division_result : felt):
    alloc_locals

    let t1 = self.future_a_time
    let a1 = self.future_a

    let (local timestamp) = get_block_timestamp()

    let (t1_condition) = is_le(timestamp, t1)

    if t1_condition == 1:
        let t0 = self.initial_a_time
        let a0 = self.initial_a

        let (a_condition) = is_le(a0, a1)
        if a_condition == 1:
            # TODO check
            let (result1,_) = unsigned_div_rem ( (a1 - a0) * (timestamp - t0) , (t1 - t0))
            return (a0+result1)
        else:
            # TODO check
            let (result2,_) =unsigned_div_rem( (a0 - a1) * (timestamp - t0) , (t1 - t0))
            return (a0-result2)
        end
    else:
        return (a1)
    end
end

func AMPLIFICATION_UTIL_ramp_a{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self : SWAP_UTIL_swap, future_a : felt, future_time : felt)->(new_swap:SWAP_UTIL_swap):
    alloc_locals

    let (timestamp) = get_block_timestamp()

    let init_time = self.initial_a_time + 24 * 60 * 60
    with_attr error_message("wait 1 day before starting ramp"):
        assert_le(init_time, timestamp)
    end

    let min_ramp_check = timestamp + AMPLIFICATION_UTIL_MIN_RAMP_TIME
    with_attr error_message("insufficient ramp time"):
        assert_le(min_ramp_check, future_time)
    end

    with_attr error_message("future_a must be > 0 and < MAX_A"):
        assert_lt(0, future_a)
    end

    with_attr error_message("future_a must be > 0 and < MAX_A"):
        assert_lt(future_a, AMPLIFICATION_UTIL_MAX_A)
    end
    let (initial_a_precise) = AMPLIFICATION_UTIL_get_a_precise(self)
    tempvar future_a_precise = future_a * AMPLIFICATION_UTIL_A_PRECISION

    tempvar future_a_mul_max_a = future_a_precise * AMPLIFICATION_UTIL_MAX_A_CHANGE
    tempvar init_a_mul_max_a = initial_a_precise * AMPLIFICATION_UTIL_MAX_A_CHANGE

    let (future_a_check) = is_le(future_a_precise, initial_a_precise)

    if future_a_check == 1:
        with_attr error_message("future_a is too small"):
            assert_le(initial_a_precise, future_a_mul_max_a)
        end
        tempvar range_check_ptr = range_check_ptr
    else:
        with_attr error_message("future_a is too large"):
            assert_le(future_a_precise, init_a_mul_max_a)
        end
        tempvar range_check_ptr = range_check_ptr
    end

    # TODO check assignments
  
    let swap_fee=self.swap_fee
    let admin_fee=self.admin_fee
    let lp_token_address=self.lp_token_address
    let number_of_token=self.number_of_token
    let token1_address=self.token1_address
    let token2_address=self.token2_address
    let token3_address=self.token3_address
    let token1_precision_with_multiplier=self.token1_precision_with_multiplier
    let token2_precision_with_multiplier=self.token2_precision_with_multiplier
    let token3_precision_with_multiplier=self.token3_precision_with_multiplier
    let token1_balance=self.token1_balance
    let token2_balance=self.token2_balance
    let token3_balance=self.token3_balance
    
    local new_swap:SWAP_UTIL_swap=SWAP_UTIL_swap(initial_a_precise,future_a_precise,timestamp,future_time,
                swap_fee,admin_fee, lp_token_address, number_of_token , token1_address, token2_address,token3_address,
                token1_precision_with_multiplier,token2_precision_with_multiplier, token3_precision_with_multiplier,
                token1_balance, token2_balance,token3_balance  )
                
    AMPLIFICATION_UTIL_ramp_a_event.emit(
        initial_a_precise, future_a_precise, timestamp, future_time
    )

    return (new_swap)
end

func AMPLIFICATION_UTIL_stop_ramp_a{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(self : SWAP_UTIL_swap)->(new_swap:SWAP_UTIL_swap):
    alloc_locals
    let (timestamp) = get_block_timestamp()
    with_attr error_message("ramp is already stopped"):
        assert_lt(timestamp, self.future_a_time)
    end

    let (current_a) = AMPLIFICATION_UTIL_get_a_precise(self)
    # TODO check storage assignments

    let swap_fee=self.swap_fee
    let admin_fee=self.admin_fee
    let lp_token_address=self.lp_token_address
    let number_of_token=self.number_of_token
    let token1_address=self.token1_address
    let token2_address=self.token2_address
    let token3_address=self.token3_address
    let token1_precision_with_multiplier=self.token1_precision_with_multiplier
    let token2_precision_with_multiplier=self.token2_precision_with_multiplier
    let token3_precision_with_multiplier=self.token3_precision_with_multiplier
    let token1_balance=self.token1_balance
    let token2_balance=self.token2_balance
    let token3_balance=self.token3_balance
    
    local new_swap:SWAP_UTIL_swap=SWAP_UTIL_swap(current_a,current_a,timestamp,timestamp,
                swap_fee,admin_fee, lp_token_address, number_of_token , token1_address, token2_address,token3_address,
                token1_precision_with_multiplier,token2_precision_with_multiplier, token3_precision_with_multiplier,
                token1_balance, token2_balance,token3_balance  )

    AMPLIFICATION_UTIL_stop_rump_a_event.emit(current_a, timestamp)
    return (new_swap)
    
    
end

func SWAP_UTIL_get_a_precise{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self : SWAP_UTIL_swap
) -> (a_precise : felt):
    let (a_precise) = AMPLIFICATION_UTIL_get_a_precise(self)

    return (a_precise)
end

func SWAP_UTIL_calculate_withdraw_one_token{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(self : SWAP_UTIL_swap, token_amount : Uint256, token_index : felt, number_of_tokens : felt) -> (
    dy : felt, dy_swap_fee : felt
):
    alloc_locals
    let lp_token_address = self.lp_token_address

    with_attr error_message("token index must be in range 0-2"):
        assert_le(token_index, 3)
    end

    let (total_supply) = IERC20_lp_token.totalSupply(lp_token_address)

    let (dy, new_y, current_y) = SWAP_UTIL_calculate_withdraw_one_token_dy(
        self, token_index, token_amount, total_supply, number_of_tokens
    )
    # TODO check for math
    if token_index == 0:
        local dy_swap_fee = ((current_y - new_y) / self.token1_precision_with_multiplier) - dy
        return (dy, dy_swap_fee)
    end
    if token_index == 1:
        local dy_swap_fee = ((current_y - new_y) / self.token2_precision_with_multiplier) - dy
        return (dy, dy_swap_fee)
    else:
        local dy_swap_fee = ((current_y - new_y) / self.token3_precision_with_multiplier) - dy
        return (dy, dy_swap_fee)
    end
end

func SWAP_UTIL_calculate_withdraw_one_token_dy{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    self : SWAP_UTIL_swap,
    token_index : felt,
    token_amount : Uint256,
    total_supply : Uint256,
    number_of_tokens : felt,
) -> (dy : felt, new_y : felt, xp: felt):
    alloc_locals
    with_attr error_message("number_of_tokens must be in range 0-2"):
        assert_le(number_of_tokens, 3)
    end
    with_attr error_message("token index out of range"):
        assert_le(0, number_of_tokens)
    end
    let (account) = get_caller_address()
    
    let (xp_len,xp_array)=SWAP_UTIL_xp(self)

    let (local precise_a) = SWAP_UTIL_get_a_precise(self)
    let (local d0) = SWAP_UTIL_get_d(precise_a, xp_len, xp_array)

    #d1= d0- token_amount*d0/total_supply
    let (amount_d0_mul)=uint256_checked_mul(token_amount,d0)
    let (amount_total_div,_)=uint256_checked_div_rem(amount_d0_mul,total_supply)
    let (d1)=uint256_checked_sub_lt(d0,amount_total_div)
    
    let scaled_token_amount=xp_array[token_index]

    let (available_condition)= uint256_le(token_amount,scaled_token_amount)

    with_attr error_message("withdraw exceeds available"):
        assert available_condition=1
    end
    #TODO
    #new_y=SWAP_UTIL_get_yd(precise_a,token_index,d1,account)
    # let v=SWAP_UTIL_calculate_withdraw_token_dy_info(0,0,0,0)

    return (0, 0, 0)
end

#func SWAP_UTIL_get_yd{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(precise_a : felt, token_index:felt, d:felt,account:felt):


# multiplier adjusted balances
func SWAP_UTIL_xp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self : SWAP_UTIL_swap
)->(xp_array_len:felt, xp_array:Uint256*):
    alloc_locals

    let (local xp1) = uint256_checked_mul(
        self.token1_balance, Uint256(self.token1_precision_with_multiplier, 0)
    )
    let (local xp2) = uint256_checked_mul(
        self.token1_balance, Uint256(self.token2_precision_with_multiplier, 0)
    )
    let (local xp3) = uint256_checked_mul(
        self.token1_balance, Uint256(self.token3_precision_with_multiplier, 0)
    )
    let (xp_array:Uint256*)=alloc()
    assert xp_array[0]=xp1
    assert xp_array[1]=xp2
    assert xp_array[2]=xp3
    let xp_array_len=3

    return (xp_array_len,xp_array )
end


func SWAP_UTIL_get_d{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    a : felt, xp_len : felt, xp : Uint256*
) -> (d : Uint256):
    alloc_locals

    let xp1= xp[0]
    let xp2= xp[1]
    let xp3= xp[2]

    let (local xp1_xp2_sum) = uint256_checked_add(xp1, xp2)
    let (local s) = uint256_checked_add(xp1_xp2_sum, xp3)

    let (s_condition) = uint256_le(Uint256(0, 0), s)
    if s_condition == 0:
        return (Uint256(0, 0))
    else:
        # TODO check for loops
        local n_a = a * xp_len
        
        let (new_d, converges) = get_d_loop(s, xp_len,xp, n_a, s, SWAP_UTIL_MAX_LOOP_LIMIT
        )

        if converges == 1:
            return (new_d)
        else:
            assert 1 = 2
            return (Uint256(0, 0))
        end
    end
end

func get_d_loop{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prev_d : Uint256,
    xp_len : felt,
    xp:Uint256*,
    n_a : felt,
    s : Uint256,
    length : felt,
) -> (new_d : Uint256, converge : felt):
    alloc_locals
    if length == 0:
        return (prev_d, 0)
    end

    let (current_d, prev_converge) = get_d_loop(prev_d, xp_len,xp, n_a, s, length - 1)

    if prev_converge == 1:
        return (current_d, prev_converge)
    else:
        let (dp) = get_dp_loop( current_d, xp_len,xp, xp_len)

        # TODO check equation
        # d = ((n_a * s /100+ N * dp) * d) / ((a - 1) * d/100 + (N + 1) * p)
        let (n_a_s_mul) = uint256_checked_mul(Uint256(n_a, 0), s)
        let (div1, _) = uint256_checked_div_rem(
            n_a_s_mul, Uint256(AMPLIFICATION_UTIL_A_PRECISION, 0)
        )
        let (n_dp_mul) = uint256_checked_mul(dp, Uint256(xp_len, 0))
        # ((n_a * s /100+ N * dp)
        let (add1) = uint256_checked_add(div1, n_dp_mul)
        let (mul1) = uint256_checked_mul(add1, current_d)

        # ((a - 1) * d/100 + (N + 1) * p)
        let (n_a_prec_sub) = uint256_sub(
            Uint256(n_a, 0), Uint256(AMPLIFICATION_UTIL_A_PRECISION, 0)
        )
        let (mul2) = uint256_checked_mul(n_a_prec_sub, current_d)
        let (div2, _) = uint256_checked_div_rem(mul2, Uint256(AMPLIFICATION_UTIL_A_PRECISION, 0))
        let (n_1_add) = uint256_checked_add(Uint256(xp_len, 0), Uint256(1, 0))
        let (n_1_dp_mul) = uint256_checked_mul(n_1_add, dp)
        let (add2) = uint256_checked_add(div2, n_1_dp_mul)
        let (new_d, _) = uint256_checked_div_rem(mul1, add2)

        # TODO check for neg values
        let (d_dif) = uint256_sub(new_d, current_d)
        let (less_than_one) = uint256_le(d_dif, Uint256(1, 0))
        let (neg_one) = uint256_neg(Uint256(1, 0))
        let (less_than_neg_one) = uint256_le(neg_one, d_dif)

        if less_than_one == 1:
            local converge = 1
            return (new_d, converge)
        end
        if less_than_neg_one == 1:
            local converge = 1
            return (new_d, converge)
        else:
            local converge = 0
            return (new_d, converge)
        end
    end
end

func get_dp_loop{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
     prev_d : Uint256, xp_len:felt,xp:Uint256*, token_length : felt
) -> (new_dp : Uint256):
    alloc_locals
    if token_length == 0:
        return (prev_d)
    end

    let (current_dp) = get_dp_loop(prev_d, xp_len,xp, token_length=token_length - 1)

     local current_xp:Uint256 = xp[token_length-1]

    let (xp_mul_tokens) = uint256_checked_mul( current_xp , Uint256(xp_len,0))
    let(dp_d_mul)=uint256_checked_mul(current_dp, prev_d)
    let (new_dp, _) = uint256_checked_div_rem(dp_d_mul,xp_mul_tokens )

    return (new_dp)
end
