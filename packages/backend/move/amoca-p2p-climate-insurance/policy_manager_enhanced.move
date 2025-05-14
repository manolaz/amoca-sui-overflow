module amoca::policy_manager_enhanced {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::table::{Self, Table};
    use std::string::{Self, String};
    use std::vector;
    
    // Enhanced Policy struct with more detailed parameters
    struct Policy has key, store {
        id: UID,
        owner: address,
        location: String,
        location_coordinates: vector<u64>, // [latitude, longitude]
        peril_type: String,
        peril_details: String, // JSON string with detailed parameters
        coverage_amount: u64,
        trigger_threshold: u64,
        trigger_operator: u8, // 0: less than, 1: greater than, 2: equal to
        collateral_balance: Balance<SUI>,
        margin_requirement: u64, // Minimum collateral required
        funding_rate_paid: u64, // Accumulated funding rate paid
        funding_rate_received: u64, // Accumulated funding rate received
        active: bool,
        created_at: u64,
        last_updated: u64,
    }
    
    // Policy Registry to track all policies
    struct PolicyRegistry has key {
        id: UID,
        policies: Table<ID, address>, // Policy ID -> Owner
        policies_by_owner: Table<address, vector<ID>>, // Owner -> Policy IDs
        policies_by_location: Table<String, vector<ID>>, // Location -> Policy IDs
        policies_by_peril: Table<String, vector<ID>>, // Peril -> Policy IDs
        total_policies: u64,
        total_coverage: u64,
    }
    
    // Risk Parameters for different locations and perils
    struct RiskParameters has key {
        id: UID,
        location_risk: Table<String, u64>, // Location -> Risk Score (higher = riskier)
        peril_risk: Table<String, u64>, // Peril -> Risk Score
        base_margin_requirement: u64, // Base margin as percentage of coverage (in basis points)
    }
    
    // Events
    struct PolicyCreated has copy, drop {
        policy_id: ID,
        owner: address,
        location: String,
        peril_type: String,
        coverage_amount: u64,
        trigger_threshold: u64,
        collateral_amount: u64,
    }
    
    struct PolicyUpdated has copy, drop {
        policy_id: ID,
        owner: address,
        field_updated: String,
        new_value: String,
    }
    
    struct PolicyTerminated has copy, drop {
        policy_id: ID,
        owner: address,
        reason: String,
    }
    
    struct CollateralAdded has copy, drop {
        policy_id: ID,
        owner: address,
        amount: u64,
        new_balance: u64,
    }
    
    struct CollateralRemoved has copy, drop {
        policy_id: ID,
        owner: address,
        amount: u64,
        new_balance: u64,
    }
    
    // Initialize the policy registry
    fun init(ctx: &mut TxContext) {
        let registry = PolicyRegistry {
            id: object::new(ctx),
            policies: table::new(ctx),
            policies_by_owner: table::new(ctx),
            policies_by_location: table::new(ctx),
            policies_by_peril: table::new(ctx),
            total_policies: 0,
            total_coverage: 0,
        };
        
        let risk_params = RiskParameters {
            id: object::new(ctx),
            location_risk: table::new(ctx),
            peril_risk: table::new(ctx),
            base_margin_requirement: 1000, // 10% base margin requirement
        };
        
        // Initialize with some default risk parameters
        let locations = vector[
            string::utf8(b"east-africa"),
            string::utf8(b"southeast-asia"),
            string::utf8(b"central-america"),
            string::utf8(b"south-pacific")
        ];
        
        let location_risks = vector[1200, 1500, 1300, 1400]; // Risk scores in basis points
        
        let perils = vector[
            string::utf8(b"drought"),
            string::utf8(b"flood"),
            string::utf8(b"heat"),
            string::utf8(b"wind")
        ];
        
        let peril_risks = vector[1300, 1600, 1200, 1400]; // Risk scores in basis points
        
        let i = 0;
        while (i < vector::length(&locations)) {
            table::add(&mut risk_params.location_risk, *vector::borrow(&locations, i), *vector::borrow(&location_risks, i));
            i = i + 1;
        };
        
        let i = 0;
        while (i < vector::length(&perils)) {
            table::add(&mut risk_params.peril_risk, *vector::borrow(&perils, i), *vector::borrow(&peril_risks, i));
            i = i + 1;
        };
        
        // Share the registry and risk parameters
        transfer::share_object(registry);
        transfer::share_object(risk_params);
    }
    
    // Calculate margin requirement based on risk parameters
    public fun calculate_margin_requirement(
        risk_params: &RiskParameters,
        location: &String,
        peril_type: &String,
        coverage_amount: u64
    ): u64 {
        let base_margin = risk_params.base_margin_requirement;
        
        // Add location risk if available
        let location_risk = if (table::contains(&risk_params.location_risk, *location)) {
            *table::borrow(&risk_params.location_risk, *location)
        } else {
            1000 // Default 10% if location not found
        };
        
        // Add peril risk if available
        let peril_risk = if (table::contains(&risk_params.peril_risk, *peril_type)) {
            *table::borrow(&risk_params.peril_risk, *peril_type)
        } else {
            1000 // Default 10% if peril not found
        };
        
        // Calculate total risk factor (base + location + peril)
        let total_risk_factor = base_margin + location_risk + peril_risk;
        
        // Calculate margin requirement (coverage * risk factor / 10000)
        (coverage_amount * total_risk_factor) / 10000
    }
    
    // Create a new policy with enhanced parameters
    public entry fun create_policy(
        registry: &mut PolicyRegistry,
        risk_params: &RiskParameters,
        location: vector<u8>,
        location_coordinates: vector<u64>,
        peril_type: vector<u8>,
        peril_details: vector<u8>,
        coverage_amount: u64,
        trigger_threshold: u64,
        trigger_operator: u8,
        collateral: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let location_str = string::utf8(location);
        let peril_type_str = string::utf8(peril_type);
        
        // Calculate margin requirement
        let margin_requirement = calculate_margin_requirement(
            risk_params,
            &location_str,
            &peril_type_str,
            coverage_amount
        );
        
        // Check if collateral is sufficient
        let collateral_amount = coin::value(&collateral);
        assert!(collateral_amount >= margin_requirement, 0); // Error: Insufficient collateral
        
        // Create the policy
        let policy = Policy {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            location: location_str,
            location_coordinates,
            peril_type: peril_type_str,
            peril_details: string::utf8(peril_details),
            coverage_amount,
            trigger_threshold,
            trigger_operator,
            collateral_balance: coin::into_balance(collateral),
            margin_requirement,
            funding_rate_paid: 0,
            funding_rate_received: 0,
            active: true,
            created_at: tx_context::epoch(ctx),
            last_updated: tx_context::epoch(ctx),
        };
        
        let policy_id = object::id(&policy);
        let owner = tx_context::sender(ctx);
        
        // Update registry
        table::add(&mut registry.policies, policy_id, owner);
        
        // Update policies_by_owner
        if (table::contains(&registry.policies_by_owner, owner)) {
            let owner_policies = table::borrow_mut(&mut registry.policies_by_owner, owner);
            vector::push_back(owner_policies, policy_id);
        } else {
            let owner_policies = vector::singleton(policy_id);
            table::add(&mut registry.policies_by_owner, owner, owner_policies);
        };
        
        // Update policies_by_location
        if (table::contains(&registry.policies_by_location, location_str)) {
            let location_policies = table::borrow_mut(&mut registry.policies_by_location, location_str);
            vector::push_back(location_policies, policy_id);
        } else {
            let location_policies = vector::singleton(policy_id);
            table::add(&mut registry.policies_by_location, location_str, location_policies);
        };
        
        // Update policies_by_peril
        if (table::contains(&registry.policies_by_peril, peril_type_str)) {
            let peril_policies = table::borrow_mut(&mut registry.policies_by_peril, peril_type_str);
            vector::push_back(peril_policies, policy_id);
        } else {
            let peril_policies = vector::singleton(policy_id);
            table::add(&mut registry.policies_by_peril, peril_type_str, peril_policies);
        };
        
        // Update totals
        registry.total_policies = registry.total_policies + 1;
        registry.total_coverage = registry.total_coverage + coverage_amount;
        
        // Transfer the policy to the sender
        transfer::transfer(policy, owner);
        
        // Emit event
        event::emit(PolicyCreated {
            policy_id,
            owner,
            location: location_str,
            peril_type: peril_type_str,
            coverage_amount,
            trigger_threshold,
            collateral_amount,
        });
    }
    
    // Add collateral to a policy
    public entry fun add_collateral(
        policy: &mut Policy,
        additional_collateral: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Verify ownership
        assert!(policy.owner == tx_context::sender(ctx), 0);
        
        let amount = coin::value(&additional_collateral);
        let additional_balance = coin::into_balance(additional_collateral);
        
        // Add to existing collateral
        balance::join(&mut policy.collateral_balance, additional_balance);
        
        let new_balance = balance::value(&policy.collateral_balance);
        
        // Update last updated timestamp
        policy.last_updated = tx_context::epoch(ctx);
        
        // Emit event
        event::emit(CollateralAdded {
            policy_id: object::id(policy),
            owner: policy.owner,
            amount,
            new_balance,
        });
    }
    
    // Remove excess collateral from a policy
    public entry fun remove_collateral(
        policy: &mut Policy,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Verify ownership
        assert!(policy.owner == tx_context::sender(ctx), 0);
        
        // Calculate excess collateral
        let current_balance = balance::value(&policy.collateral_balance);
        let excess = current_balance - policy.margin_requirement;
        
        // Ensure withdrawal doesn't go below margin requirement
        assert!(amount <= excess, 0); // Error: Cannot withdraw below margin requirement
        
        // Remove collateral
        let coin_to_return = coin::take(&mut policy.collateral_balance, amount, ctx);
        
        // Transfer to owner
        transfer::transfer(coin_to_return, policy.owner);
        
        let new_balance = balance::value(&policy.collateral_balance);
        
        // Update last updated timestamp
        policy.last_updated = tx_context::epoch(ctx);
        
        // Emit event
        event::emit(CollateralRemoved {
            policy_id: object::id(policy),
            owner: policy.owner,
            amount,
            new_balance,
        });
    }
    
    // Terminate a policy and return collateral
    public entry fun terminate_policy(
        registry: &mut PolicyRegistry,
        policy: &mut Policy,
        ctx: &mut TxContext
    ) {
        // Verify ownership
        assert!(policy.owner == tx_context::sender(ctx), 0);
        assert!(policy.active, 1); // Error: Policy already terminated
        
        // Return collateral
        let balance_amount = balance::value(&policy.collateral_balance);
        let coin_to_return = coin::take(&mut policy.collateral_balance, balance_amount, ctx);
        transfer::transfer(coin_to_return, policy.owner);
        
        // Update policy status
        policy.active = false;
        policy.last_updated = tx_context::epoch(ctx);
        
        // Update registry totals
        registry.total_coverage = registry.total_coverage - policy.coverage_amount;
        
        // Emit event
        event::emit(PolicyTerminated {
            policy_id: object::id(policy),
            owner: policy.owner,
            reason: string::utf8(b"User terminated"),
        });
    }
    
    // Process funding payment for a policy
    public fun process_funding_payment(
        policy: &mut Policy,
        rate: u64,
        direction: bool, // true = policyholder pays, false = policyholder receives
        ctx: &mut TxContext
    ): u64 {
        assert!(policy.active, 0); // Error: Policy not active
        
        // Calculate payment amount based on coverage amount and rate
        let payment_amount = (policy.coverage_amount * rate) / 10000;
        
        if (direction) {
            // Policyholder pays - deduct from collateral
            assert!(balance::value(&policy.collateral_balance) >= payment_amount, 1); // Error: Insufficient collateral
            policy.funding_rate_paid = policy.funding_rate_paid + payment_amount;
            payment_amount
        } else {
            // Policyholder receives - add to tracking (actual payment handled by caller)
            policy.funding_rate_received = policy.funding_rate_received + payment_amount;
            payment_amount
        }
    }
    
    // Check if a policy is undercollateralized
    public fun is_undercollateralized(policy: &Policy): bool {
        balance::value(&policy.collateral_balance) < policy.margin_requirement
    }
    
    // Get total insured value (sum of all active policy coverage amounts)
    public fun get_total_insured_value(registry: &PolicyRegistry): u64 {
        registry.total_coverage
    }
    
    // Get policy details
    public fun get_policy_details(policy: &Policy): (address, String, String, u64, u64, u64, bool) {
        (
            policy.owner,
            policy.location,
            policy.peril_type,
            policy.coverage_amount,
            policy.trigger_threshold,
            balance::value(&policy.collateral_balance),
            policy.active
        )
    }
}
