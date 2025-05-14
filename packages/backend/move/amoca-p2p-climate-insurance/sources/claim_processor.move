module amoca::claim_processor {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use amoca::policy_manager::{Self, Policy};
    use amoca::oracle_aggregator::{Self, AggregatedData};
    use amoca::liquidity_pool::{Self, LiquidityPool};
    
    // Claim struct representing a processed claim
    struct Claim has key, store {
        id: UID,
        policy_id: ID,
        owner: address,
        trigger_value: u64,
        actual_value: u64,
        payout_amount: u64,
        processed_at: u64,
        status: u8, // 0: Pending, 1: Approved, 2: Rejected
    }
    
    // Events
    struct ClaimProcessed has copy, drop {
        claim_id: ID,
        policy_id: ID,
        owner: address,
        payout_amount: u64,
        status: u8,
    }
    
    // Process a claim based on oracle data
    public entry fun process_claim(
        policy: &Policy,
        oracle_data: &AggregatedData,
        pool: &mut LiquidityPool,
        ctx: &mut TxContext
    ) {
        // Verify that the oracle data matches the policy location and peril type
        assert!(policy.location == oracle_data.location, 0);
        assert!(policy.peril_type == oracle_data.data_type, 1);
        
        // Check if the trigger condition is met
        let trigger_met = false;
        
        // For simplicity, we're assuming lower values are worse (e.g., rainfall)
        // In a real implementation, this would depend on the peril type
        if (oracle_data.value <= policy.trigger_threshold) {
            trigger_met = true;
        };
        
        let status = if (trigger_met) { 1 } else { 2 };
        let payout_amount = if (trigger_met) { policy.coverage_amount } else { 0 };
        
        // Create claim record
        let claim = Claim {
            id: object::new(ctx),
            policy_id: object::id(policy),
            owner: policy.owner,
            trigger_value: policy.trigger_threshold,
            actual_value: oracle_data.value,
            payout_amount,
            processed_at: tx_context::epoch(ctx),
            status,
        };
        
        // If claim is approved, process payout from the liquidity pool
        if (status == 1) {
            // In a real implementation, we would:
            // 1. Transfer funds from the liquidity pool to the policyholder
            // 2. Update the policy status
            // 3. Update the pool's available liquidity
            
            // This is a simplified version
            liquidity_pool::process_claim_payout(pool, policy.owner, payout_amount, ctx);
        };
        
        // Transfer the claim record to the policy owner
        transfer::transfer(claim, policy.owner);
        
        // Emit event
        event::emit(ClaimProcessed {
            claim_id: object::id(&claim),
            policy_id: object::id(policy),
            owner: policy.owner,
            payout_amount,
            status,
        });
    }
    
    // Additional functions would include:
    // - get_claim_details
    // - check_claim_status
    // - manual_claim_review (for edge cases)
}
