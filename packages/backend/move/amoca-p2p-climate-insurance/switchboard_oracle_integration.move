module amoca::switchboard_oracle_integration {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use std::string::{Self, String};
    use std::vector;
    
    // Import Switchboard modules
    use switchboard::aggregator::{Self, Aggregator, CurrentResult};
    use switchboard::decimal::{Self, Decimal};
    
    // Constants for Switchboard deployment addresses
    const SWITCHBOARD_MAINNET: address = @0xe6717fb7c9d44706bf8ce8a651e25c0a7902d32cb0ff40c0976251ce8ac25655;
    const SWITCHBOARD_TESTNET: address = @0x578b91ec9dcc505439b2f0ec761c23ad2c533a1c23b0467f6c4ae3d9686709f6;
    
    // Oracle Feed Registry to track climate data feeds
    struct OracleFeedRegistry has key {
        id: UID,
        feeds: Table<String, ID>, // Feed name -> Aggregator ID
        feed_types: Table<ID, String>, // Aggregator ID -> Data type (e.g., "rainfall", "temperature")
        feed_locations: Table<ID, String>, // Aggregator ID -> Location
        feed_details: Table<ID, String>, // Aggregator ID -> Additional details (JSON)
    }
    
    // Aggregated Oracle Data
    struct AggregatedData has key {
        id: UID,
        location: String,
        data_type: String,
        value: u128,
        decimal_places: u8,
        timestamp: u64,
        min_timestamp: u64,
        max_timestamp: u64,
        mean: u128,
        stdev: u128,
        min_value: u128,
        max_value: u128,
        sources_count: u64,
    }
    
    // Events
    struct FeedRegistered has copy, drop {
        feed_id: ID,
        feed_name: String,
        data_type: String,
        location: String,
    }
    
    struct DataAggregated has copy, drop {
        aggregation_id: ID,
        location: String,
        data_type: String,
        value: u128,
        timestamp: u64,
        sources_count: u64,
    }
    
    // Initialize the oracle feed registry
    fun init(ctx: &mut TxContext) {
        let registry = OracleFeedRegistry {
            id: object::new(ctx),
            feeds: table::new(ctx),
            feed_types: table::new(ctx),
            feed_locations: table::new(ctx),
            feed_details: table::new(ctx),
        };
        
        transfer::share_object(registry);
    }
    
    // Register a new Switchboard feed
    public entry fun register_feed(
        registry: &mut OracleFeedRegistry,
        feed_name: vector<u8>,
        data_type: vector<u8>,
        location: vector<u8>,
        details: vector<u8>,
        aggregator: &Aggregator,
        ctx: &mut TxContext
    ) {
        let feed_name_str = string::utf8(feed_name);
        let data_type_str = string::utf8(data_type);
        let location_str = string::utf8(location);
        let details_str = string::utf8(details);
        
        let aggregator_id = object::id(aggregator);
        
        // Register the feed
        table::add(&mut registry.feeds, feed_name_str, aggregator_id);
        table::add(&mut registry.feed_types, aggregator_id, data_type_str);
        table::add(&mut registry.feed_locations, aggregator_id, location_str);
        table::add(&mut registry.feed_details, aggregator_id, details_str);
        
        // Emit event
        event::emit(FeedRegistered {
            feed_id: aggregator_id,
            feed_name: feed_name_str,
            data_type: data_type_str,
            location: location_str,
        });
    }
    
    // Read data from a Switchboard aggregator and create aggregated data
    public entry fun read_aggregator_data(
        registry: &OracleFeedRegistry,
        aggregator: &Aggregator,
        ctx: &mut TxContext
    ) {
        let aggregator_id = object::id(aggregator);
        
        // Verify the aggregator is registered
        assert!(table::contains(&registry.feed_types, aggregator_id), 0);
        
        // Get the current result from the aggregator
        let current_result = aggregator::current_result(aggregator);
        
        // Get the result as a Decimal
        let result = aggregator::result(&current_result);
        
        // Get the data type and location
        let data_type = *table::borrow(&registry.feed_types, aggregator_id);
        let location = *table::borrow(&registry.feed_locations, aggregator_id);
        
        // Create aggregated data
        let aggregated_data = AggregatedData {
            id: object::new(ctx),
            location,
            data_type,
            value: decimal::value(&result),
            decimal_places: decimal::decimal_places(&result),
            timestamp: tx_context::epoch(ctx),
            min_timestamp: aggregator::min_timestamp_ms(&current_result),
            max_timestamp: aggregator::max_timestamp_ms(&current_result),
            mean: decimal::value(&aggregator::mean(&current_result)),
            stdev: decimal::value(&aggregator::stdev(&current_result)),
            min_value: decimal::value(&aggregator::min_result(&current_result)),
            max_value: decimal::value(&aggregator::max_result(&current_result)),
            sources_count: 1, // Single aggregator
        };
        
        // Share the aggregated data
        transfer::share_object(aggregated_data);
        
        // Emit event
        event::emit(DataAggregated {
            aggregation_id: object::id(&aggregated_data),
            location,
            data_type,
            value: decimal::value(&result),
            timestamp: tx_context::epoch(ctx),
            sources_count: 1,
        });
    }
    
    // Aggregate data from multiple Switchboard aggregators for a specific location and data type
    public entry fun aggregate_multiple_feeds(
        registry: &OracleFeedRegistry,
        aggregators: vector<&Aggregator>,
        location: vector<u8>,
        data_type: vector<u8>,
        ctx: &mut TxContext
    ) {
        let location_str = string::utf8(location);
        let data_type_str = string::utf8(data_type);
        
        // Verify inputs
        let num_feeds = vector::length(&aggregators);
        assert!(num_feeds > 0, 0);
        
        // Collect values from all aggregators
        let values = vector::empty<u128>();
        let min_timestamps = vector::empty<u64>();
        let max_timestamps = vector::empty<u64>();
        
        let i = 0;
        while (i < num_feeds) {
            let aggregator = *vector::borrow(&aggregators, i);
            let aggregator_id = object::id(aggregator);
            
            // Verify the aggregator is registered
            assert!(table::contains(&registry.feed_types, aggregator_id), 1);
            
            // Verify feed type and location match
            assert!(*table::borrow(&registry.feed_types, aggregator_id) == data_type_str, 2);
            assert!(*table::borrow(&registry.feed_locations, aggregator_id) == location_str, 3);
            
            // Get the current result from the aggregator
            let current_result = aggregator::current_result(aggregator);
            
            // Get the result as a Decimal
            let result = aggregator::result(&current_result);
            
            // Add to values
            vector::push_back(&mut values, decimal::value(&result));
            vector::push_back(&mut min_timestamps, aggregator::min_timestamp_ms(&current_result));
            vector::push_back(&mut max_timestamps, aggregator::max_timestamp_ms(&current_result));
            
            i = i + 1;
        };
        
        // Calculate median value (simplified - in reality would use a more robust algorithm)
        // Sort values (bubble sort for simplicity)
        let n = vector::length(&values);
        let i = 0;
        while (i < n) {
            let j = 0;
            while (j < n - i - 1) {
                if (*vector::borrow(&values, j) > *vector::borrow(&values, j + 1)) {
                    let temp = *vector::borrow(&values, j);
                    *vector::borrow_mut(&mut values, j) = *vector::borrow(&values, j + 1);
                    *vector::borrow_mut(&mut values, j + 1) = temp;
                };
                j = j + 1;
            };
            i = i + 1;
        };
        
        // Get median value
        let median_value = if (n % 2 == 0) {
            (*vector::borrow(&values, n / 2 - 1) + *vector::borrow(&values, n / 2)) / 2
        } else {
            *vector::borrow(&values, n / 2)
        };
        
        // Calculate mean
        let sum = 0u128;
        let i = 0;
        while (i < n) {
            sum = sum + *vector::borrow(&values, i);
            i = i + 1;
        };
        let mean = sum / (n as u128);
        
        // Calculate min and max timestamps
        let min_timestamp = *vector::borrow(&min_timestamps, 0);
        let max_timestamp = *vector::borrow(&max_timestamps, 0);
        let i = 1;
        while (i < vector::length(&min_timestamps)) {
            let current_min = *vector::borrow(&min_timestamps, i);
            let current_max = *vector::borrow(&max_timestamps, i);
            
            if (current_min < min_timestamp) {
                min_timestamp = current_min;
            };
            
            if (current_max > max_timestamp) {
                max_timestamp = current_max;
            };
            
            i = i + 1;
        };
        
        // Calculate standard deviation (simplified)
        let variance_sum = 0u128;
        let i = 0;
        while (i < n) {
            let diff = if (*vector::borrow(&values, i) > mean) {
                *vector::borrow(&values, i) - mean
            } else {
                mean - *vector::borrow(&values, i)
            };
            variance_sum = variance_sum + (diff * diff);
            i = i + 1;
        };
        let stdev = (variance_sum / (n as u128)) ^ (1/2);
        
        // Create aggregated data
        let aggregated_data = AggregatedData {
            id: object::new(ctx),
            location: location_str,
            data_type: data_type_str,
            value: median_value,
            decimal_places: 8, // Standard decimal places
            timestamp: tx_context::epoch(ctx),
            min_timestamp,
            max_timestamp,
            mean,
            stdev,
            min_value: *vector::borrow(&values, 0), // First value after sorting is min
            max_value: *vector::borrow(&values, n - 1), // Last value after sorting is max
            sources_count: n,
        };
        
        // Share the aggregated data
        transfer::share_object(aggregated_data);
        
        // Emit event
        event::emit(DataAggregated {
            aggregation_id: object::id(&aggregated_data),
            location: location_str,
            data_type: data_type_str,
            value: median_value,
            timestamp: tx_context::epoch(ctx),
            sources_count: n,
        });
    }
    
    // Get the latest value from an aggregator
    public fun get_latest_value(aggregator: &Aggregator): (u128, u8, bool) {
        let current_result = aggregator::current_result(aggregator);
        let result = aggregator::result(&current_result);
        
        (
            decimal::value(&result),
            decimal::decimal_places(&result),
            decimal::neg(&result)
        )
    }
    
    // Get aggregated data details
    public fun get_aggregated_data_details(data: &AggregatedData): (String, String, u128, u64, u64) {
        (
            data.location,
            data.data_type,
            data.value,
            data.timestamp,
            data.sources_count
        )
    }
}
