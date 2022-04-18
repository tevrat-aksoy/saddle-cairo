%lang starknet
%builtins pedersen range_check


from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_mul, uint256_le, uint256_lt, uint256_check,
     uint256_eq, uint256_neg,uint256_signed_nn,uint256_unsigned_div_rem
)
from starkware.cairo.common.math_cmp  import  (is_le,)
from starkware.cairo.common.math import (assert_le,unsigned_div_rem)


from starkware.starknet.common.syscalls import (
    get_block_number,
    get_block_timestamp,
)
from contracts.interfaces.IERC20_lp_token import IERC20_lp_token

@event
func AMPLIFICATION_UTIL_ramp_a_event(old_a:felt, new_a:felt, initial_time:felt, future_time:felt):
end
@event
func AMPLIFICATION_UTIL_stomp_rump_A(current_a:felt, time:felt):
end


const AMPLIFICATION_UTIL_A_PRECISION = 100
const AMPLIFICATION_UTIL_MAX_A = 10**6
const AMPLIFICATION_UTIL_MAX_A_CHANGE = 2
const AMPLIFICATION_UTIL_MIN_RAMP_TIME = 14*24*60*60





#TODO: check for felt-uint256values
@event
func SWAP_UTIL_token_swap(
    buyer:felt,
    tokens_sold:felt, 
    tokens_bought:felt, 
    sold_id:felt,
    bought_id:felt):
end

@event
func SWAP_UTIL_add_liquidity(
    provider:felt,
    tokens_amount_len:felt, 
    tokens_amount:felt*,
    fees_len:felt, 
    fees:felt*,
    invariant:felt, 
    lp_token_supply:felt):
end
@event
func SWAP_UTIL_remove_liquidity(
    provider:felt,
    tokens_amount_len:felt, 
    tokens_amount:felt*, 
    lp_token_supply:felt):
end

@event
func SWAP_UTIL_remove_liquidity_one(
    provider:felt,
    lp_tokens_amount_len:felt,
    lp_token_supply:felt,
    bought_id:felt, 
    tokens_bought:felt):
end

@event
func SWAP_UTIL_remove_liquidity_imbalance(
    provider:felt,
    tokens_amount_len:felt, 
    tokens_amount:felt*,
    fees_len:felt, 
    fees:felt*,
    invariant:felt, 
    lp_token_supply:felt):
end
@event
func SWAP_UTIL_new_admin_fee(new_admin_fee:felt):
end

@event
func SWAP_UTIL_new_swap_fee(new_swap_fee:felt):
end

struct SWAP_UTIL_swap:
    member initial_a:felt
    member future_a:felt
    member initial_a_time:felt
    member future_a_time:felt
    member swap_fee:felt
    member admin_fee:felt
    member lp_token_address:felt
    member pooled_tokens_len:felt
    member pooled_tokens:felt*
    member token_precision_with_multiplier_len:felt
    member token_precision_with_multiplier:felt*
    member balances_len:felt
    member balances:felt*
end

struct SWAP_UTIL_calculate_withdraw_token_dy_info:
    member d0:felt
    member d1:felt
    member new_y:felt
    member fee_pert_token:felt
    member precise_a:felt
end
struct SWAP_UTIL_manage_liqudity_info:
    member d0:felt
    member d1:felt
    member d2:felt
    member precise_a:felt
    member lp_token_address:felt
    member total_supply:Uint256
    member balances_len:felt
    member balances:felt*
    member multipliers_len:felt
    member multipliers:felt*
end


const SWAP_UTIL_POOL_PRECISION_DECIMALS = 18
const SWAP_UTIL_FEE_DENOMINATOR = 10**10
const SWAP_UTIL_MAX_SWAP_FEE = 10**8
const SWAP_UTIL_MAX_ADMIN_FEE = 10**10
const SWAP_UTIL_MAX_LOOP_LIMIT = 256

func AMPLIFICATION_UTIL_get_a{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(self: SWAP_UTIL_swap)->(
    a_result:felt):
    alloc_locals
    
    let (a_precise)=AMPLIFICATION_UTIL_get_a_precise(self)
    let (a_result,_remeain) =unsigned_div_rem(a_precise,AMPLIFICATION_UTIL_A_PRECISION)
    return (a_result)
end



func AMPLIFICATION_UTIL_get_a_precise{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(self: SWAP_UTIL_swap)->(
    division_result:felt):
    alloc_locals

    let t1=self.future_a_time
    let a1=self.future_a

    let (local timestamp)=get_block_timestamp()

    let (t1_condition)=is_le(timestamp,t1)

    if t1_condition==1:

        let t0=self.initial_a_time
        let a0= self.initial_a

        let (a_condition)=is_le(a0,a1)
        if a_condition==1:
            #TODO check 
            let result1= a0 + (a1 - a0) * (timestamp - t0) / (t1 - t0)
            return (result1)
        else:
            #TODO check 
            let result2=a0 - (a0 - a1) * (timestamp - t0) / (t1 - t0)
            return (result2)
        end
    else:
        return (a1)
    
    end

end


func AMPLIFICATION_UTIL_ramp_a{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(self: SWAP_UTIL_swap, future_a:felt, future_time:felt):
    alloc_locals

    let (timestamp)=get_block_timestamp()

    let init_time= self.initial_a_time+ 24*60*60
    with_attr error_message("wait 1 day before starting ramp"):
        assert_le(init_time,timestamp)
    end

    let min_ramp_check= timestamp+AMPLIFICATION_UTIL_MIN_RAMP_TIME
    with_attr error_message("insufficient ramp time"):
        assert_le(min_ramp_check, future_time)
    end

    with_attr error_message("future_a must be > 0 and < MAX_A"):
        assert_le(0,future_a)
    end

    with_attr error_message("future_a must be > 0 and < MAX_A"):
        assert_le(future_a,AMPLIFICATION_UTIL_MAX_A)
    end  
    let (  initial_a_precise)=AMPLIFICATION_UTIL_get_a_precise(self)
    tempvar  future_a_precise= future_a*AMPLIFICATION_UTIL_A_PRECISION

    tempvar future_a_mul_max_a= future_a_precise*AMPLIFICATION_UTIL_MAX_A_CHANGE
    tempvar init_a_mul_max_a= initial_a_precise*AMPLIFICATION_UTIL_MAX_A_CHANGE

    let  (future_a_check)=  is_le( future_a_precise ,initial_a_precise)

    if future_a_check==1:
        with_attr error_message("future_a is too small"):
            assert_le(initial_a_precise,future_a_mul_max_a )
        end
        tempvar range_check_ptr = range_check_ptr
    else:
        with_attr error_message("futureA_ is too large"):
            assert_le(future_a_precise,init_a_mul_max_a )
        end
        tempvar range_check_ptr = range_check_ptr
    end

    #TODO check assignments
    self.initial_a=initial_a_precise


    AMPLIFICATION_UTIL_ramp_a_event.emit(
        initial_a_precise,
        future_a_precise,
        timestamp,
        future_time,)


    return()

end 


func AMPLIFICATION_UTIL_stop_ramp_a{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(self: SWAP_UTIL_swap):
    alloc_locals
    let (timestamp)=get_block_timestamp()
    with_attr error_message("ramp is already stopped"):
        assert_le(timestamp,self.future_a_time)
    end

    let (current_a)= AMPLIFICATION_UTIL_get_a_precise(self)
    #TODO check storage assignments



    return()
end



func SWAP_UTIL_get_a_precise{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self:SWAP_UTIL_swap )->(
    a_precise:felt):
    let (a_precise)= AMPLIFICATION_UTIL_get_a_precise(self)

    return (a_precise)

end


func SWAP_UTIL_calculate_withdraw_one_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self:SWAP_UTIL_swap, token_amount:Uint256, token_index:felt )->(
    dy:Uint256,dy_swap_fee:Uint256):

    
    let lp_token_address=self.lp_token_address

    let (total_supply)=IERC20_lp_token.totalSupply(lp_token_address)

    let (dy, new_y, current_y)=SWAP_UTIL_calculate_withdraw_one_token_dy(self, token_index,token_amount, total_supply)
    #TODO check for math
    let dy_swap_fee=((current_y-new_y)/self.token_precision_with_multiplier[token_index])-dy

   return(dy,dy_swap_fee) 
end


func SWAP_UTIL_calculate_withdraw_one_token_dy{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    self:SWAP_UTIL_swap,token_index:felt, token_amount:Uint256, total_supply:Uint256 )->(
    dy:Uint256,new_y:Uint256,xp:Uint256):

    let (xp) = SWAP_UTIL_xp(self.balances, self.token_precision_with_multiplier)
    with_attr error_message("token index out of range"):
        assert_le(token_index,xp.lenght)
    end
   
    #TODO 
    let (precise_a)= SWAP_UTIL_get_a_precise(self)
    
     let v=SWAP_UTIL_calculate_withdraw_token_dy_info(0,0,0,0)

    return(Uint256(0,0),Uint256(0,0),Uint256(0,0))

end


func SWAP_UTIL_xp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
   self:SWAP_UTIL_swap)->(
    xp:Uint256*):
    let num_tokens= self.balances_len

    with_attr error_message("balances must match multipliers"):
        assert num_tokens=self.token_precision_with_multiplier

    end
    #TODO check for loops
    return(Uint256(0,0))
end








