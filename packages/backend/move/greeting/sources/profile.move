// Copyright (c) AMOCA Team and other contributors
// SPDX-License-Identifier: MIT
/// Module: profile
module greeting::profile {
    use std::string::{utf8, String};
    use sui::display;
    use sui::event::emit;
    use sui::package;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;

    // === Constants ===
    const EInvalidExperience: u64 = 0;
    const EInvalidEducation: u64 = 1;
    const EInvalidSkill: u64 = 2;
    const EEmptyName: u64 = 3;

    // === Structs ===
    /// Represents a professional experience entry
    public struct Experience has store, drop, copy {
        company: String,
        title: String,
        start_date: String,
        end_date: String,
        description: String
    }

    /// Represents an education entry
    public struct Education has store, drop, copy {
        institution: String,
        degree: String,
        field: String,
        start_date: String,
        end_date: String
    }

    /// Represents a skill with endorsements
    public struct Skill has store, drop, copy {
        name: String,
        endorsements: u64
    }

    /// Main Profile object representing a user's career profile
    public struct Profile has key {
        id: UID,
        owner: address,
        name: String,
        headline: String,
        bio: String,
        profile_image_url: String,
        location: String,
        contact_email: String,
        experiences: vector<Experience>,
        education: vector<Education>,
        skills: vector<Skill>,
        connections: vector<address>
    }

    /// One-Time-Witness for the module
    public struct PROFILE has drop {}

    // === Events ===
    /// Emitted when a profile is created
    public struct ProfileCreated has copy, drop {
        profile_id: ID,
        owner: address
    }

    /// Emitted when a profile is updated
    public struct ProfileUpdated has copy, drop {
        profile_id: ID,
        owner: address
    }

    /// Emitted when an experience is added
    public struct ExperienceAdded has copy, drop {
        profile_id: ID,
        company: String,
        title: String
    }

    /// Emitted when an education is added
    public struct EducationAdded has copy, drop {
        profile_id: ID,
        institution: String,
        degree: String
    }

    /// Emitted when a skill is added
    public struct SkillAdded has copy, drop {
        profile_id: ID,
        skill_name: String
    }

    /// Emitted when a connection is added
    public struct ConnectionAdded has copy, drop {
        profile_id: ID,
        connection_address: address
    }

    // === Initializer ===
    fun init(otw: PROFILE, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];
        
        let values = vector[
            utf8(b"{name}"),
            utf8(b"{profile_image_url}"),
            utf8(b"{headline}"),
            utf8(b"https://amoca.network"),
            utf8(b"AMOCA Team"),
        ];

        // Claim the `Publisher` for the package
        let publisher = package::claim(otw, ctx);
        
        // Get a new `Display` object for the `Profile` type
        let mut display = display::new_with_fields<Profile>(
            &publisher,
            keys,
            values,
            ctx,
        );
        
        // Commit first version of `Display` to apply changes
        display::update_version(&mut display);
        
        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(display, ctx.sender());
    }

    // === Public Creation Functions ===
    /// Create a new profile
    public entry fun create_profile(
        name: String,
        headline: String,
        bio: String,
        profile_image_url: String,
        location: String,
        contact_email: String,
        ctx: &mut TxContext
    ) {
        assert!(name != b"".to_string(), EEmptyName);
        
        let profile = Profile {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            name,
            headline,
            bio,
            profile_image_url,
            location,
            contact_email,
            experiences: vector::empty<Experience>(),
            education: vector::empty<Education>(),
            skills: vector::empty<Skill>(),
            connections: vector::empty<address>()
        };
        
        emit(ProfileCreated {
            profile_id: object::id(&profile),
            owner: tx_context::sender(ctx)
        });
        
        transfer::transfer(profile, tx_context::sender(ctx));
    }

    // === Profile Update Functions ===
    /// Update basic profile information
    public entry fun update_profile_info(
        profile: &mut Profile,
        name: String,
        headline: String,
        bio: String,
        profile_image_url: String,
        location: String,
        contact_email: String,
        ctx: &mut TxContext
    ) {
        assert!(name != b"".to_string(), EEmptyName);
        assert!(tx_context::sender(ctx) == profile.owner, 0); // Only owner can update
        
        profile.name = name;
        profile.headline = headline;
        profile.bio = bio;
        profile.profile_image_url = profile_image_url;
        profile.location = location;
        profile.contact_email = contact_email;
        
        emit(ProfileUpdated {
            profile_id: object::id(profile),
            owner: profile.owner
        });
    }

    /// Add a professional experience
    public entry fun add_experience(
        profile: &mut Profile,
        company: String,
        title: String,
        start_date: String,
        end_date: String,
        description: String,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == profile.owner, 0);
        assert!(company != b"".to_string() && title != b"".to_string(), EInvalidExperience);
        
        let experience = Experience {
            company,
            title,
            start_date,
            end_date,
            description
        };
        
        vector::push_back(&mut profile.experiences, experience);
        
        emit(ExperienceAdded {
            profile_id: object::id(profile),
            company,
            title
        });
    }

    /// Add an education entry
    public entry fun add_education(
        profile: &mut Profile,
        institution: String,
        degree: String,
        field: String,
        start_date: String,
        end_date: String,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == profile.owner, 0);
        assert!(institution != b"".to_string() && degree != b"".to_string(), EInvalidEducation);
        
        let education = Education {
            institution,
            degree,
            field,
            start_date,
            end_date
        };
        
        vector::push_back(&mut profile.education, education);
        
        emit(EducationAdded {
            profile_id: object::id(profile),
            institution,
            degree
        });
    }

    /// Add a skill
    public entry fun add_skill(
        profile: &mut Profile,
        skill_name: String,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == profile.owner, 0);
        assert!(skill_name != b"".to_string(), EInvalidSkill);
        
        let skill = Skill {
            name: skill_name,
            endorsements: 0
        };
        
        vector::push_back(&mut profile.skills, skill);
        
        emit(SkillAdded {
            profile_id: object::id(profile),
            skill_name
        });
    }

    /// Add a connection
    public entry fun add_connection(
        profile: &mut Profile,
        connection_address: address,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == profile.owner, 0);
        assert!(connection_address != profile.owner, 0); // Can't connect to self
        
        // Check if connection already exists
        let i = 0;
        let len = vector::length(&profile.connections);
        let mut exists = false;
        
        while (i < len) {
            if (vector::borrow(&profile.connections, i) == &connection_address) {
                exists = true;
                break
            };
            i = i + 1;
        };
        
        if (!exists) {
            vector::push_back(&mut profile.connections, connection_address);
            
            emit(ConnectionAdded {
                profile_id: object::id(profile),
                connection_address
            });
        }
    }

    // === Public View Functions ===
    /// Get profile name
    public fun name(profile: &Profile): String {
        profile.name
    }
    
    /// Get profile headline
    public fun headline(profile: &Profile): String {
        profile.headline
    }
    
    /// Get profile bio
    public fun bio(profile: &Profile): String {
        profile.bio
    }
    
    /// Get profile image URL
    public fun profile_image_url(profile: &Profile): String {
        profile.profile_image_url
    }
    
    /// Get profile owner
    public fun owner(profile: &Profile): address {
        profile.owner
    }
    
    /// Get profile experiences count
    public fun experiences_count(profile: &Profile): u64 {
        vector::length(&profile.experiences)
    }
    
    /// Get profile education count
    public fun education_count(profile: &Profile): u64 {
        vector::length(&profile.education)
    }
    
    /// Get profile skills count
    public fun skills_count(profile: &Profile): u64 {
        vector::length(&profile.skills)
    }
    
    /// Get profile connections count
    public fun connections_count(profile: &Profile): u64 {
        vector::length(&profile.connections)
    }

    // === Test Functions ===
    #[test_only]
    /// Initialize for testing
    public fun init_for_testing(ctx: &mut TxContext) {
        init(PROFILE {}, ctx);
    }
}