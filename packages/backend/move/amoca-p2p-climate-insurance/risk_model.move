module amoca::risk_model {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use std::string::{Self, String};
    use std::vector;
    
    // Risk Model Parameters
    struct RiskModel has key {
        id: UID,
        model_name: String,
        model_version: String,
        base_premium_rate: u64, // Base premium rate in basis points
        location_factors: Table<String, u64>, // Location -> Risk factor
        peril_factors: Table<String, u64>, // Peril -> Risk factor
        seasonal_factors: Table<u64, u64>, // Month -> Seasonal factor
        coverage_factors: Table<u64, u64>, // Coverage tier -> Factor
        last_updated: u64,
        created_by: address,
    }
    
    // Historical Risk Data
    struct HistoricalRiskData has key {
        id: UID,
        location: String,
        peril_type: String,
        data_points: vector<u64>, // Historical values
        timestamps: vector<u64>, // Corresponding timestamps
        last_updated: u64,
    }
    
    // Premium Calculation Result
    struct PremiumCalculation has copy, drop {
        policy_id: Option<ID>,
        location: String,
        peril_type: String,
        coverage_amount: u64,
        base_premium: u64,
        location_adjustment: u64,
        peril_adjustment: u64,
        seasonal_adjustment: u64,
        coverage_adjustment: u64,
        final_premium: u64,
        funding_rate: u64, // Daily funding rate in basis points
    }
    
    // Events
    struct RiskModelCreated has copy, drop {
        model_id: ID,
        model_name: String,
        model_version: String,
        created_by: address,
    }
    
    struct RiskModelUpdated has copy, drop {
        model_id: ID,
        field_updated: String,
        updated_by: address,
    }
    
    struct PremiumCalculated has copy, drop {
        policy_id: Option<ID>,
        location: String,
        peril_type: String,
        coverage_amount: u64,
        final_premium: u64,
        funding_rate: u64,
    }
    
    // Create a new risk model
    public entry fun create_risk_model(
        model_name: vector<u8>,
        model_version: vector<u8>,
        base_premium_rate: u64,
        ctx: &mut TxContext
    ) {
        let model = RiskModel {
            id: object::new(ctx),
            model_name: string::utf8(model_name),
            model_version: string::utf8(model_version),
            base_premium_rate,
            location_factors: table::new(ctx),
            peril_factors: table::new(ctx),
            seasonal_factors: table::new(ctx),
            coverage_factors: table::new(ctx),
            last_updated: tx_context::epoch(ctx),
            created_by: tx_context::sender(ctx),
        };
        
        // Initialize with default factors
        
        // Location factors (higher = riskier)
        table::add(&mut model.location_factors, string::utf8(b"east-africa"), 120); // 1.2x
        table::add(&mut model.location_factors, string::utf8(b"southeast-asia"), 150); // 1.5x
        table::add(&mut model.location_factors, string::utf8(b"central-america"), 130); // 1.3x
        table::add(&mut model.location_factors, string::utf8(b"south-pacific"), 140); // 1.4x
        
        // Peril factors (higher = riskier)
        table::add(&mut model.peril_factors, string::utf8(b"drought"), 130); // 1.3x
        table::add(&mut model.peril_factors, string::utf8(b"flood"), 160); // 1.6x
        table::add(&mut model.peril_factors, string::utf8(b"heat"), 120); // 1.2x
        table::add(&mut model.peril_factors, string::utf8(b"wind"), 140); // 1.4x
        
        // Seasonal factors (by month, 1-12)
        table::add(&mut model.seasonal_factors, 1, 100); // January
        table::add(&mut model.seasonal_factors, 2, 100);
        table::add(&mut model.seasonal_factors, 3, 110);
        table::add(&mut model.seasonal_factors, 4, 120);
        table::add(&mut model.seasonal_factors, 5, 130);
        table::add(&mut model.seasonal_factors, 6, 140); // June (hurricane season)
        table::add(&mut model.seasonal_factors, 7, 150);
        table::add(&mut model.seasonal_factors, 8, 160);
        table::add(&mut model.seasonal_factors, 9, 150);
        table::add(&mut model.seasonal_factors, 10, 130);
        table::add(&mut model.seasonal_factors, 11, 110);
        table::add(&mut model.seasonal_factors, 12, 100); // December
        
        // Coverage factors (by coverage tier in USD)
        table::add(&mut model.coverage_factors, 1000, 120); // $1,000 - higher relative premium
        table::add(&mut model.coverage_factors, 5000, 110); // $5,000
        table::add(&mut model.coverage_factors, 10000, 100); // $10,000 - baseline
        table::add(&mut model.coverage_factors, 50000, 90); // $50,000 - volume discount
        table::add(&mut model.coverage_factors, 100000, 85); // $100,000 - larger volume discount
        
        // Share the risk model
        transfer::share_object(model);
        
        // Emit event
        event::emit(RiskModelCreated {
            model_id: object::id(&model),
            model_name: string::utf8(model_name),
            model_version: string::utf8(model_version),
            created_by: tx_context::sender(ctx),
        });
    }
    
    // Update a risk model parameter
    public entry fun update_location_factor(
        model: &mut RiskModel,
        location: vector<u8>,
        factor: u64,
        ctx: &mut TxContext
    ) {
        // Only creator can update
        assert!(model.created_by == tx_context::sender(ctx), 0);
        
        let location_str = string::utf8(location);
        
        if (table::contains(&model.location_factors, location_str)) {
            let current_factor = table::borrow_mut(&mut model.location_factors, location_str);
            *current_factor = factor;
        } else {
            table::add(&mut model.location_factors, location_str, factor);
        };
        
        model.last_updated = tx_context::epoch(ctx);
        
        // Emit event
        event::emit(RiskModelUpdated {
            model_id: object::id(model),
            field_updated: string::utf8(b"location_factor"),
            updated_by: tx_context::sender(ctx),
        });
    }
    
    // Similar update functions would be implemented for other factors
    
    // Calculate premium for a policy
    public fun calculate_premium(
        model: &RiskModel,
        location: String,
        peril_type: String,
        coverage_amount: u64,
        current_month: u64,
        policy_id: Option<ID>
    ): PremiumCalculation {
        // Get base premium rate
        let base_premium_rate = model.base_premium_rate;
        
        // Get location factor
        let location_factor = if (table::contains(&model.location_factors, location)) {
            *table::borrow(&model.location_factors, location)
        } else {
            100 // Default 1.0x
        };
        
        // Get peril factor
        let peril_factor = if (table::contains(&model.peril_factors, peril_type)) {
            *table::borrow(&model.peril_factors, peril_type)
        } else {
            100 // Default 1.0x
        };
        
        // Get seasonal factor
        let month = if (current_month >= 1 && current_month <= 12) {
            current_month
        } else {
            1 // Default to January
        };
        
        let seasonal_factor = if (table::contains(&model.seasonal_factors, month)) {
            *table::borrow(&model.seasonal_factors, month)
        } else {
            100 // Default 1.0x
        };
        
        // Get coverage factor
        // Find the closest coverage tier
        let coverage_tiers = vector[1000, 5000, 10000, 50000, 100000];
        let closest_tier = 10000; // Default to $10,000 tier
        
        let i = 0;
        let min_diff = 1000000000; // Large number
        while (i < vector::length(&coverage_tiers)) {
            let tier = *vector::borrow(&coverage_tiers, i);
            let diff = if (tier > coverage_amount) {
                tier - coverage_amount
            } else {
                coverage_amount - tier
            };
            
            if (diff < min_diff) {
                min_diff = diff;
                closest_tier = tier;
            };
            
            i = i + 1;
        };
        
        let coverage_factor = if (table::contains(&model.coverage_factors, closest_tier)) {
            *table::borrow(&model.coverage_factors, closest_tier)
        } else {
            100 // Default 1.0x
        };
        
        // Calculate base premium (annual)
        let base_premium = (coverage_amount * base_premium_rate) / 10000;
        
        // Apply adjustments
        let location_adjustment = (base_premium * location_factor) / 100 - base_premium;
        let peril_adjustment = (base_premium * peril_factor) / 100 - base_premium;
        let seasonal_adjustment = (base_premium * seasonal_factor) / 100 - base_premium;
        let coverage_adjustment = (base_premium * coverage_factor) / 100 - base_premium;
        
        // Calculate final premium
        let final_premium = base_premium + location_adjustment + peril_adjustment + 
                           seasonal_adjustment + coverage_adjustment;
        
        // Calculate daily funding rate (annual premium / 365 / coverage amount * 10000)
        let funding_rate = (final_premium * 10000) / (coverage_amount * 365);
        
        // Return premium calculation
        PremiumCalculation {
            policy_id,
            location,
            peril_type,
            coverage_amount,
            base_premium,
            location_adjustment,
            peril_adjustment,
            seasonal_adjustment,
            coverage_adjustment,
            final_premium,
            funding_rate,
        }
    }
    
    // Add historical risk data
    public entry fun add_historical_data(
        location: vector<u8>,
        peril_type: vector<u8>,
        data_point: u64,
        ctx: &mut TxContext
    ) {
        let location_str = string::utf8(location);
        let peril_type_str = string::utf8(peril_type);
        
        // In a real implementation, this would:
        // 1. Check if historical data exists for this location/peril
        // 2. If it exists, update it; if not, create a new one
        
        // For this example, we'll just create a new one
        let historical_data = HistoricalRiskData {
            id: object::new(ctx),
            location: location_str,
            peril_type: peril_type_str,
            data_points: vector::singleton(data_point),
            timestamps: vector::singleton(tx_context::epoch(ctx)),
            last_updated: tx_context::epoch(ctx),
        };
        
        // Share the historical data
        transfer::share_object(historical_data);
    }
    
    // Get risk model details
    public fun get_risk_model_details(model: &RiskModel): (String, String, u64, u64) {
        (
            model.model_name,
            model.model_version,
            model.base_premium_rate,
            model.last_updated
        )
    }
}
