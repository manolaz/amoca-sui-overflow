module amoca::claim_processor_updated {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use amoca::policy_manager_enhanced::{Self, Policy};
    use amoca::switchboard_oracle_integration::{Self, AggregatedData};
    use amoca::liquidity_pool::{Self, LiquidityPool};
    use switchboard::aggregator::{Self, Aggregator};
    use switchboard::decimal::{Self, Decimal};
    
    // Claim struct representing a processed claim
    struct Claim has key, store {
        id: UID,
        policy_id: ID,
        owner: address,
        trigger_value: u64,
        actual_value: u128,
        decimal_places: u8,
        payout_amount: u64,
        processed_at: u64,
        status: u8, // 0: Pending, 1: Approved, 2: Rejected
        oracle_sources: u64,
    }
    
    // Events
    struct ClaimProcessed has copy, drop {
        claim_id: ID,
        policy_id: ID,
        owner: address,
        payout_amount: u64,
        status: u8,
    }
    
    // Process a claim based on aggregated oracle data
    public entry fun process_claim_with_aggregated_data(
        policy: &Policy,
        oracle_data: &AggregatedData,
        pool: &mut LiquidityPool,
        ctx: &mut TxContext
    ) {
        // Get policy details
        let (owner, location, peril_type, coverage_amount, trigger_threshold, _, active) = 
            policy_manager_enhanced::get_policy_details(policy);
        
        // Verify policy is active
        assert!(active, 0);
        
        // Get oracle data details
        let (oracle_location, oracle_data_type, oracle_value, _, sources_count) = 
            switchboard_oracle_integration::get_aggregated_data_details(oracle_data);
        
        // Verify that the oracle data matches the policy location and peril type
        assert!(location == oracle_location, 1);
        assert!(peril_type == oracle_data_type, 2);
        
        // Check if the trigger condition is met
        let trigger_met = false;
        
        // Convert oracle value to u64 for comparison (simplified)
        let oracle_value_u64 = (oracle_value as u64);
        
        // Get trigger operator from policy (0: less than, 1: greater than, 2: equal to)
        let trigger_operator = policy_manager_enhanced::get_trigger_operator(policy);
        
        if (trigger_operator == 0) {
            // Less than
            trigger_met = oracle_value_u64 <= trigger_threshold;
        } else if (trigger_operator == 1) {
            // Greater than
            trigger_met = oracle_value_u64 >= trigger_threshold;
        } else if (trigger_operator == 2) {
            // Equal to (with some tolerance)
            let diff = if (oracle_value_u64 > trigger_threshold) {
                oracle_value_u64 - trigger_threshold
            } else {
                trigger_threshold - oracle_value_u64
            };
            trigger_met = diff <= (trigger_threshold / 100); // 1% tolerance
        };
        
        let status = if (trigger_met) { 1 } else { 2 };
        let payout_amount = if (trigger_met) { coverage_amount } else { 0 };
        
        // Create claim record
        let claim = Claim {
            id: object::new(ctx),
            policy_id: object::id(policy),
            owner,
            trigger_value: trigger_threshold,
            actual_value: oracle_value,
            decimal_places: 8, // Standard decimal places
            payout_amount,
            processed_at: tx_context::epoch(ctx),
            status,
            oracle_sources: sources_count,
        };
        
        // If claim is approved, process payout from the liquidity pool
        if (status == 1) {
            // Process payout from the liquidity pool
            liquidity_pool::process_claim_payout(pool, owner, payout_amount, ctx);
        };
        
        // Transfer the claim record to the policy owner
        transfer::transfer(claim, owner);
        
        // Emit event
        event::emit(ClaimProcessed {
            claim_id: object::id(&claim),
            policy_id: object::id(policy),
            owner,
            payout_amount,
            status,
        });
    }
    
    // Process a claim directly with a Switchboard aggregator
    public entry fun process_claim_with_aggregator(
        policy: &Policy,
        aggregator: &Aggregator,
        pool: &mut LiquidityPool,
        ctx: &mut TxContext
    ) {
        // Get policy details
        let (owner, location, peril_type, coverage_amount, trigger_threshold, _, active) = 
            policy_manager_enhanced::get_policy_details(policy);
        
        // Verify policy is active
        assert!(active, 0);
        
        // Get the current result from the aggregator
        let current_result = aggregator::current_result(aggregator);
        
        // Get the result as a Decimal
        let result = aggregator::result(&current_result);
        let oracle_value = decimal::value(&result);
        let decimal_places = decimal::decimal_places(&result);
        
        // Check if the trigger condition is met
        let trigger_met = false;
        
        // Convert oracle value to u64 for comparison (simplified)
        let oracle_value_u64 = (oracle_value as u64);
        
        // Get trigger operator from policy (0: less than, 1: greater than, 2: equal to)
        let trigger_operator = policy_manager_enhanced::get_trigger_operator(policy);
        
        if (trigger_operator == 0) {
            // Less than
            trigger_met = oracle_value_u64 <= trigger_threshold;
        } else if (trigger_operator == 1) {
            // Greater than
            trigger_met = oracle_value_u64 >= trigger_threshold;
        } else if (trigger_operator == 2) {
            // Equal to (with some tolerance)
            let diff = if (oracle_value_u64 > trigger_threshold) {
                oracle_value_u64 - trigger_threshold
            } else {
                trigger_threshold - oracle_value_u64
            };
            trigger_met = diff <= (trigger_threshold / 100); // 1% tolerance
        };
        
        let status = if (trigger_met) { 1 } else { 2 };
        let payout_amount = if (trigger_met) { coverage_amount } else { 0 };
        
        // Create claim record
        let claim = Claim {
            id: object::new(ctx),
            policy_id: object::id(policy),
            owner,
            trigger_value: trigger_threshold,
            actual_value: oracle_value,
            decimal_places,
            payout_amount,
            processed_at: tx_context::epoch(ctx),
            status,
            oracle_sources: 1, // Single aggregator
        };
        
        // If claim is approved, process payout from the liquidity pool
        if (status == 1) {
            // Process payout from the liquidity pool
            liquidity_pool::process_claim_payout(pool, owner, payout_amount, ctx);
        };
        
        // Transfer the claim record to the policy owner
        transfer::transfer(claim, owner);
        
        // Emit event
        event::emit(ClaimProcessed {
            claim_id: object::id(&claim),
            policy_id: object::id(policy),
            owner,
            payout_amount,
            status,
        });
    }
    
    // Get claim details
    public fun get_claim_details(claim: &Claim): (ID, address, u64, u128, u64, u8, u64) {
        (
            claim.policy_id,
            claim.owner,
            claim.trigger_value,
            claim.actual_value,
            claim.payout_amount,
            claim.status,
            claim.oracle_sources
        )
    }
}
