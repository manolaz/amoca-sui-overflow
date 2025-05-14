module amoca::switchboard_oracle {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use std::string::{Self, String};
    use std::vector;
    
    // Import Switchboard's Feed struct (simplified for this example)
    // In a real implementation, you would import from the Switchboard package
    struct SwitchboardFeed has key, store {
        id: UID,
        authority: address,
        data: vector<u8>,
        latest_value: u64,
        latest_timestamp: u64,
        update_interval: u64,
    }
    
    // Oracle Feed Registry
    struct OracleFeedRegistry has key {
        id: UID,
        feeds: Table<String, ID>, // Feed name -> Feed ID
        feed_authorities: Table<ID, address>, // Feed ID -> Authority
        feed_types: Table<ID, String>, // Feed ID -> Data type (e.g., "rainfall", "temperature")
        feed_locations: Table<ID, String>, // Feed ID -> Location
    }
    
    // Aggregated Oracle Data
    struct AggregatedData has key {
        id: UID,
        location: String,
        data_type: String,
        value: u64,
        timestamp: u64,
        confidence: u64, // Confidence score (higher = more confident)
        num_sources: u64, // Number of sources used in aggregation
        sources: vector<ID>, // IDs of source feeds
    }
    
    // Events
    struct FeedRegistered has copy, drop {
        feed_id: ID,
        feed_name: String,
        authority: address,
        data_type: String,
        location: String,
    }
    
    struct FeedUpdated has copy, drop {
        feed_id: ID,
        new_value: u64,
        timestamp: u64,
    }
    
    struct DataAggregated has copy, drop {
        aggregation_id: ID,
        location: String,
        data_type: String,
        value: u64,
        timestamp: u64,
        num_sources: u64,
    }
    
    // Initialize the oracle feed registry
    fun init(ctx: &mut TxContext) {
        let registry = OracleFeedRegistry {
            id: object::new(ctx),
            feeds: table::new(ctx),
            feed_authorities: table::new(ctx),
            feed_types: table::new(ctx),
            feed_locations: table::new(ctx),
        };
        
        transfer::share_object(registry);
    }
    
    // Register a new Switchboard feed
    public entry fun register_feed(
        registry: &mut OracleFeedRegistry,
        feed_name: vector<u8>,
        data_type: vector<u8>,
        location: vector<u8>,
        update_interval: u64,
        ctx: &mut TxContext
    ) {
        let feed_name_str = string::utf8(feed_name);
        let data_type_str = string::utf8(data_type);
        let location_str = string::utf8(location);
        
        // Create a new feed
        let feed = SwitchboardFeed {
            id: object::new(ctx),
            authority: tx_context::sender(ctx),
            data: vector::empty(),
            latest_value: 0,
            latest_timestamp: 0,
            update_interval,
        };
        
        let feed_id = object::id(&feed);
        
        // Register the feed
        table::add(&mut registry.feeds, feed_name_str, feed_id);
        table::add(&mut registry.feed_authorities, feed_id, tx_context::sender(ctx));
        table::add(&mut registry.feed_types, feed_id, data_type_str);
        table::add(&mut registry.feed_locations, feed_id, location_str);
        
        // Transfer the feed to the sender
        transfer::transfer(feed, tx_context::sender(ctx));
        
        // Emit event
        event::emit(FeedRegistered {
            feed_id,
            feed_name: feed_name_str,
            authority: tx_context::sender(ctx),
            data_type: data_type_str,
            location: location_str,
        });
    }
    
    // Update a feed with new data
    public entry fun update_feed(
        registry: &OracleFeedRegistry,
        feed: &mut SwitchboardFeed,
        new_value: u64,
        new_data: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Verify authority
        assert!(feed.authority == tx_context::sender(ctx), 0);
        
        // Update feed data
        feed.data = new_data;
        feed.latest_value = new_value;
        feed.latest_timestamp = tx_context::epoch(ctx);
        
        // Emit event
        event::emit(FeedUpdated {
            feed_id: object::id(feed),
            new_value,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    // Aggregate data from multiple feeds for a specific location and data type
    public entry fun aggregate_data(
        registry: &OracleFeedRegistry,
        location: vector<u8>,
        data_type: vector<u8>,
        feed_ids: vector<ID>,
        feed_values: vector<u64>,
        feed_timestamps: vector<u64>,
        ctx: &mut TxContext
    ) {
        let location_str = string::utf8(location);
        let data_type_str = string::utf8(data_type);
        
        // Verify inputs
        let num_feeds = vector::length(&feed_ids);
        assert!(num_feeds > 0, 0);
        assert!(num_feeds == vector::length(&feed_values), 1);
        assert!(num_feeds == vector::length(&feed_timestamps), 2);
        
        // Verify all feeds are registered and match the location and data type
        let i = 0;
        while (i < num_feeds) {
            let feed_id = *vector::borrow(&feed_ids, i);
            assert!(table::contains(&registry.feed_authorities, feed_id), 3);
            
            // Verify feed type and location
            assert!(*table::borrow(&registry.feed_types, feed_id) == data_type_str, 4);
            assert!(*table::borrow(&registry.feed_locations, feed_id) == location_str, 5);
            
            i = i + 1;
        };
        
        // Calculate median value (simplified - in reality would use a more robust algorithm)
        // Sort values (bubble sort for simplicity)
        let values = feed_values;
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
        
        // Create aggregated data
        let aggregated_data = AggregatedData {
            id: object::new(ctx),
            location: location_str,
            data_type: data_type_str,
            value: median_value,
            timestamp: tx_context::epoch(ctx),
            confidence: calculate_confidence(values, median_value),
            num_sources: num_feeds,
            sources: feed_ids,
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
            num_sources: num_feeds,
        });
    }
    
    // Calculate confidence score based on variance from median
    fun calculate_confidence(values: vector<u64>, median: u64): u64 {
        let n = vector::length(&values);
        if (n <= 1) {
            return 10000; // Max confidence if only one source
        };
        
        // Calculate average deviation from median
        let total_deviation = 0u64;
        let i = 0;
        while (i < n) {
            let value = *vector::borrow(&values, i);
            let deviation = if (value > median) {
                value - median
            } else {
                median - value
            };
            total_deviation = total_deviation + deviation;
            i = i + 1;
        };
        
        let avg_deviation = total_deviation / n;
        
        // Calculate confidence (10000 = max confidence)
        // Lower deviation = higher confidence
        if (avg_deviation == 0) {
            10000 // Perfect agreement
        } else if (median == 0) {
            5000 // Avoid division by zero, return medium confidence
        } else {
            // Confidence decreases as deviation increases
            let deviation_percentage = (avg_deviation * 10000) / median;
            if (deviation_percentage >= 10000) {
                1000 // Minimum confidence (10%)
            } else {
                10000 - deviation_percentage
            }
        }
    }
    
    // Get the latest value for a specific feed
    public fun get_feed_value(feed: &SwitchboardFeed): (u64, u64) {
        (feed.latest_value, feed.latest_timestamp)
    }
    
    // Get the latest aggregated data for a location and data type
    public fun get_aggregated_data(data: &AggregatedData): (String, String, u64, u64, u64) {
        (
            data.location,
            data.data_type,
            data.value,
            data.timestamp,
            data.confidence
        )
    }
}
