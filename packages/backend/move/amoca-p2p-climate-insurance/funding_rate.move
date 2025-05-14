module amoca::funding_rate {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use amoca::policy_manager::{Self, Policy};
    use amoca::liquidity_pool::{Self, LiquidityPool};
    
    // FundingRate struct representing the current funding rate
    struct FundingRate has key {
        id: UID,
        rate: u64, // Basis points (e.g., 100 = 1%)
        direction: bool, // true = policyholders pay LPs, false = LPs pay policyholders
        calculated_at: u64,
        valid_until: u64,
    }
    
    // Events
    struct FundingRateUpdated has copy, drop {
        rate: u64,
        direction: bool,
        calculated_at: u64,
    }
    
    struct FundingPaymentProcessed has copy, drop {
        policy_id: ID,
        amount: u64,
        direction: bool,
    }
    
    // Calculate and update the funding rate
    public entry fun update_funding_rate(
        pool: &LiquidityPool,
        total_insured_value: u64,
        ctx: &mut TxContext
    ) {
        // Get the total liquidity in the pool
        let total_liquidity = liquidity_pool::get_total_liquidity(pool);
        
        // Calculate the utilization ratio
        // utilization = total_insured_value / total_liquidity
        let utilization = if (total_liquidity == 0) {
            10000 // 100% utilization if no liquidity
        } else {
            (total_insured_value * 10000) / total_liquidity
        };
        
        // Calculate the funding rate based on utilization
        // This is a simplified model - in reality, this would be more complex
        let target_utilization = 8000; // 80%
        let base_rate = 50; // 0.5% base rate
        
        let rate;
        let direction;
        
        if (utilization > target_utilization) {
            // High utilization - policyholders pay LPs
            rate = base_rate + ((utilization - target_utilization) / 100);
            direction = true;
        } else {
            // Low utilization - LPs pay policyholders (or zero rate)
            rate = if (utilization < 5000) {
                // Below 50% utilization, LPs pay a small rate
                (target_utilization - utilization) / 1000
            } else {
                // Between 50-80% utilization, zero rate
                0
            };
            direction = false;
        };
        
        // Create the funding rate object
        let funding_rate = FundingRate {
            id: object::new(ctx),
            rate,
            direction,
            calculated_at: tx_context::epoch(ctx),
            valid_until: tx_context::epoch(ctx) + 24, // Valid for 24 epochs (e.g., 24 hours)
        };
        
        // Share the funding rate object
        transfer::share_object(funding_rate);
        
        // Emit event
        event::emit(FundingRateUpdated {
            rate,
            direction,
            calculated_at: tx_context::epoch(ctx),
        });
    }
    
    // Process funding payment for a policy
    public entry fun process_funding_payment(
        policy: &mut Policy,
        funding_rate: &FundingRate,
        pool: &mut LiquidityPool,
        ctx: &mut TxContext
    ) {
        // Verify that the funding rate is valid
        assert!(tx_context::epoch(ctx) <= funding_rate.valid_until, 0);
        
        // Calculate the funding payment
        let payment_amount = (policy.coverage_amount * funding_rate.rate) / 10000;
        
        if (payment_amount > 0) {
            if (funding_rate.direction) {
                // Policyholders pay LPs
                // Deduct from policy collateral and add to pool
                policy_manager::deduct_collateral(policy, payment_amount);
                liquidity_pool::add_funding_payment(pool, payment_amount);
            } else {
                // LPs pay policyholders
                // Deduct from pool and add to policy collateral
                liquidity_pool::deduct_funding_payment(pool, payment_amount);
                policy_manager::add_collateral(policy, payment_amount);
            };
            
            // Emit event
            event::emit(FundingPaymentProcessed {
                policy_id: object::id(policy),
                amount: payment_amount,
                direction: funding_rate.direction,
            });
        };
    }
    
    // Additional functions would include:
    // - get_current_funding_rate
    // - calculate_funding_payment
    // - historical_funding_rates
}
