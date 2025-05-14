module amoca::walrus_integration {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use std::string::{Self, String};
    use std::vector;
    
    // Data types that can be stored in Walrus
    const DATA_TYPE_POLICY: u8 = 0;
    const DATA_TYPE_CLAIM: u8 = 1;
    const DATA_TYPE_ORACLE_READING: u8 = 2;
    const DATA_TYPE_RISK_MODEL: u8 = 3;
    const DATA_TYPE_AUDIT_LOG: u8 = 4;
    
    // WalrusReference struct representing a reference to data stored in Walrus
    struct WalrusReference has key, store {
        id: UID,
        data_type: u8,
        reference_id: String, // Walrus CID or reference ID
        metadata: String, // JSON metadata
        timestamp: u64,
        creator: address,
    }
    
    // WalrusRegistry to track all references
    struct WalrusRegistry has key {
        id: UID,
        references: Table<ID, WalrusReference>, // Reference ID -> Reference
        references_by_type: Table<u8, vector<ID>>, // Data Type -> Reference IDs
        references_by_creator: Table<address, vector<ID>>, // Creator -> Reference IDs
        references_by_entity: Table<ID, vector<ID>>, // Entity ID (e.g., Policy ID) -> Reference IDs
        total_references: u64,
    }
    
    // Events
    struct DataStored has copy, drop {
        reference_id: ID,
        data_type: u8,
        walrus_cid: String,
        entity_id: Option<ID>,
        creator: address,
    }
    
    struct DataVerified has copy, drop {
        reference_id: ID,
        verified: bool,
        verifier: address,
    }
    
    // Initialize the Walrus registry
    fun init(ctx: &mut TxContext) {
        let registry = WalrusRegistry {
            id: object::new(ctx),
            references: table::new(ctx),
            references_by_type: table::new(ctx),
            references_by_creator: table::new(ctx),
            references_by_entity: table::new(ctx),
            total_references: 0,
        };
        
        // Initialize tables for each data type
        table::add(&mut registry.references_by_type, DATA_TYPE_POLICY, vector::empty<ID>());
        table::add(&mut registry.references_by_type, DATA_TYPE_CLAIM, vector::empty<ID>());
        table::add(&mut registry.references_by_type, DATA_TYPE_ORACLE_READING, vector::empty<ID>());
        table::add(&mut registry.references_by_type, DATA_TYPE_RISK_MODEL, vector::empty<ID>());
        table::add(&mut registry.references_by_type, DATA_TYPE_AUDIT_LOG, vector::empty<ID>());
        
        transfer::share_object(registry);
    }
    
    // Store data in Walrus and create a reference
    public entry fun store_data(
        registry: &mut WalrusRegistry,
        data_type: u8,
        walrus_cid: vector<u8>,
        metadata: vector<u8>,
        entity_id: Option<ID>,
        ctx: &mut TxContext
    ) {
        // Create a reference
        let reference = WalrusReference {
            id: object::new(ctx),
            data_type,
            reference_id: string::utf8(walrus_cid),
            metadata: string::utf8(metadata),
            timestamp: tx_context::epoch(ctx),
            creator: tx_context::sender(ctx),
        };
        
        let reference_id = object::id(&reference);
        
        // Add to registry
        table::add(&mut registry.references, reference_id, reference);
        
        // Update references_by_type
        let type_refs = table::borrow_mut(&mut registry.references_by_type, data_type);
        vector::push_back(type_refs, reference_id);
        
        // Update references_by_creator
        let creator = tx_context::sender(ctx);
        if (table::contains(&registry.references_by_creator, creator)) {
            let creator_refs = table::borrow_mut(&mut registry.references_by_creator, creator);
            vector::push_back(creator_refs, reference_id);
        } else {
            let creator_refs = vector::singleton(reference_id);
            table::add(&mut registry.references_by_creator, creator, creator_refs);
        };
        
        // Update references_by_entity if entity_id is provided
        if (option::is_some(&entity_id)) {
            let entity = option::extract(&mut entity_id);
            if (table::contains(&registry.references_by_entity, entity)) {
                let entity_refs = table::borrow_mut(&mut registry.references_by_entity, entity);
                vector::push_back(entity_refs, reference_id);
            } else {
                let entity_refs = vector::singleton(reference_id);
                table::add(&mut registry.references_by_entity, entity, entity_refs);
            };
        };
        
        // Update total references
        registry.total_references = registry.total_references + 1;
        
        // Emit event
        event::emit(DataStored {
            reference_id,
            data_type,
            walrus_cid: string::utf8(walrus_cid),
            entity_id,
            creator,
        });
    }
    
    // Verify data integrity (simplified - in reality would use cryptographic verification)
    public entry fun verify_data(
        registry: &WalrusRegistry,
        reference_id: ID,
        expected_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&registry.references, reference_id), 0);
        
        // In a real implementation, this would:
        // 1. Retrieve the data from Walrus using the reference
        // 2. Compute the hash of the retrieved data
        // 3. Compare with the expected hash
        
        // For this example, we'll just emit an event
        let verified = true; // Placeholder
        
        // Emit event
        event::emit(DataVerified {
            reference_id,
            verified,
            verifier: tx_context::sender(ctx),
        });
    }
    
    // Get references by entity
    public fun get_references_by_entity(
        registry: &WalrusRegistry,
        entity_id: ID
    ): vector<ID> {
        if (table::contains(&registry.references_by_entity, entity_id)) {
            *table::borrow(&registry.references_by_entity, entity_id)
        } else {
            vector::empty<ID>()
        }
    }
    
    // Get references by type
    public fun get_references_by_type(
        registry: &WalrusRegistry,
        data_type: u8
    ): vector<ID> {
        *table::borrow(&registry.references_by_type, data_type)
    }
    
    // Get reference details
    public fun get_reference_details(
        registry: &WalrusRegistry,
        reference_id: ID
    ): (u8, String, String, u64, address) {
        let reference = table::borrow(&registry.references, reference_id);
        (
            reference.data_type,
            reference.reference_id,
            reference.metadata,
            reference.timestamp,
            reference.creator
        )
    }
}
