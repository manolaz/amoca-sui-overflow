module amoca::oracle_aggregator {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};
    use std::vector;
    
    // OracleData struct representing climate data from oracles
    struct OracleData has key, store {
        id: UID,
        location: String,
        data_type: String, // e.g., "rainfall", "temperature", "wind_speed"
        value: u64,
        timestamp: u64,
        source: address, // Oracle that provided the data
    }
    
    // AggregatedData struct representing the aggregated data from multiple oracles
    struct AggregatedData has key {
        id: UID,
        location: String,
        data_type: String,
        value: u64, // Aggregated value (e.g., median, average)
        timestamp: u64,
        sources_count: u64,
    }
    
    // Events
    struct DataReceived has copy, drop {
        location: String,
        data_type: String,
        value: u64,
        source: address,
    }
    
    struct DataAggregated has copy, drop {
        location: String,
        data_type: String,
        value: u64,
        sources_count: u64,
    }
    
    // Authorized oracles
    struct OracleRegistry has key {
        id: UID,
        authorized_oracles: vector<address>,
    }
    
    // Submit data from an oracle
    public entry fun submit_data(
        registry: &OracleRegistry,
        location: vector<u8>,
        data_type: vector<u8>,
        value: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check if the sender is an authorized oracle
        assert!(vector::contains(&registry.authorized_oracles, &sender), 0);
        
        let oracle_data = OracleData {
            id: object::new(ctx),
            location: string::utf8(location),
            data_type: string::utf8(data_type),
            value,
            timestamp: tx_context::epoch(ctx),
            source: sender,
        };
        
        // Store the data
        // In a real implementation, we would store this in a collection
        // and use it for aggregation
        
        // Emit event
        event::emit(DataReceived {
            location: string::utf8(location),
            data_type: string::utf8(data_type),
            value,
            source: sender,
        });
    }
    
    // Aggregate data from multiple oracles
    // This is a simplified version - in reality, this would be more complex
    public entry fun aggregate_data(
        location: vector<u8>,
        data_type: vector<u8>,
        values: vector<u64>,
        sources: vector<address>,
        ctx: &mut TxContext
    ) {
        // In a real implementation, we would:
        // 1. Validate that all sources are authorized oracles
        // 2. Sort the values and take the median, or calculate the average
        // 3. Apply additional validation logic
        
        let values_len = vector::length(&values);
        assert!(values_len > 0, 0);
        assert!(values_len == vector::length(&sources), 1);
        
        // Simple aggregation: take the average
        let sum = 0u64;
        let i = 0;
        while (i < values_len) {
            sum = sum + *vector::borrow(&values, i);
            i = i + 1;
        };
        
        let avg_value = sum / values_len;
        
        let aggregated_data = AggregatedData {
            id: object::new(ctx),
            location: string::utf8(location),
            data_type: string::utf8(data_type),
            value: avg_value,
            timestamp: tx_context::epoch(ctx),
            sources_count: values_len,
        };
        
        // Share the aggregated data
        transfer::share_object(aggregated_data);
        
        // Emit event
        event::emit(DataAggregated {
            location: string::utf8(location),
            data_type: string::utf8(data_type),
            value: avg_value,
            sources_count: values_len,
        });
    }
    
    // Additional functions would include:
    // - register_oracle
    // - remove_oracle
    // - get_latest_data
    // - validate_data
}
