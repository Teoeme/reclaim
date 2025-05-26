#[starknet::interface]
pub trait IReclaim<TContractState> {
    fn save_metadata(
        ref self: TContractState, 
        hash_commit: ByteArray, 
        cipher_secret: ByteArray, 
        cid: ByteArray, 
        unlock_timestamp: felt252,
        access_type: felt252,
        name: ByteArray
    );
    fn reclaim(self: @TContractState, hash_commit: ByteArray) -> (ByteArray, ByteArray, felt252, felt252, felt252, ByteArray);
    fn get_records_by_owner(self: @TContractState, owner: felt252) -> Array<(ByteArray, felt252, felt252, felt252, ByteArray)>;
}

#[starknet::contract]
pub mod reclaim {
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map, Vec, VecTrait, MutableVecTrait
    };
    use starknet::{ContractAddress, get_caller_address};
    use starknet::get_block_timestamp;
    use super::IReclaim;
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    
    #[derive(Drop,Serde, starknet::Store)]
    struct FileRecord {
        cid: ByteArray,
        hash_commit: felt252,
        cipher_secret: ByteArray,
        unlock_timestamp: felt252,
        owner: ContractAddress,
        access_type: felt252,
        name: ByteArray,
    }

    #[storage]
    pub struct Storage {
        records: Map<felt252, FileRecord>,
        all_hash_commits: Vec<felt252>  // All hash_commits array
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MetadataSaved: MetadataSaved,
        FileReclaimed: FileReclaimed
    }

    #[derive(Drop, starknet::Event)]
    pub struct MetadataSaved {
        pub hash_commit: felt252,
        pub unlock_timestamp: felt252
    }

    #[derive(Drop, starknet::Event)]
    pub struct FileReclaimed {
        pub hash_commit: felt252
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn truncate_hash(hash: ByteArray) -> felt252 {
            let mut result: felt252 = 0;
            for i in 0_u32..31_u32 {
                match hash.at(i) {
                    Option::Some(byte) => {
                        result = result * 256 + byte.into();
                    },
                    Option::None => {
                        break;
                    }
                }
            }
            result
        }
    }

    #[abi(embed_v0)]
    impl ReclaimImpl of IReclaim<ContractState> {

        fn save_metadata(
            ref self: ContractState, 
            hash_commit: ByteArray,
            cipher_secret: ByteArray, 
            cid: ByteArray, 
            unlock_timestamp: felt252,
            access_type: felt252,
            name: ByteArray
        ) {
            let truncated_hash = InternalFunctions::truncate_hash(hash_commit);
            assert(truncated_hash != 0, 'R: Invalid hash commit');
            assert(cipher_secret.len() > 0, 'R: Invalid cipher secret');
            assert(cid.len() > 0, 'R: Invalid CID');
            assert(name.len() > 0, 'R: Invalid name');
            assert(unlock_timestamp.try_into().unwrap() > get_block_timestamp(), 'R: Invalid unlock timestamp');
            assert(access_type == 'timestamp' || access_type == 'heirs', 'R: Invalid access type');
            
            let existing = self.records.entry(truncated_hash).read();
            assert(existing.hash_commit == 0, 'R: Hash commit already exists');
            
            let owner = get_caller_address();
            let record = FileRecord { 
                hash_commit: truncated_hash,
                cipher_secret, 
                cid, 
                unlock_timestamp, 
                owner,
                access_type,
                name
            };
            self.records.entry(truncated_hash).write(record);
            self.all_hash_commits.push(truncated_hash);

            self.emit(Event::MetadataSaved(MetadataSaved { hash_commit: truncated_hash, unlock_timestamp }));
        }
    
        fn reclaim(self: @ContractState, hash_commit: ByteArray) -> (ByteArray, ByteArray, felt252, felt252, felt252, ByteArray) {
            let truncated_hash: felt252 = InternalFunctions::truncate_hash(hash_commit);
            let record = self.records.entry(truncated_hash).read();
            assert(record.hash_commit != 0, 'R: Record not found');
            assert(get_block_timestamp() >= record.unlock_timestamp.try_into().unwrap(), 'R: File still locked');

            // self.emit(Event::FileReclaimed(FileReclaimed { hash_commit: truncated_hash }));
            (record.cipher_secret, record.cid, record.hash_commit, record.owner.into(), record.access_type, record.name)
        }

        fn get_records_by_owner(self: @ContractState, owner: felt252) -> Array<(ByteArray, felt252, felt252, felt252, ByteArray)> {
            let mut records_array = ArrayTrait::new();
            
            for i in 0..self.all_hash_commits.len() {
                let hash_commit = self.all_hash_commits.at(i).read();
                let record = self.records.entry(hash_commit).read();
                let owner_address: felt252 = record.owner.into();
                if owner_address == owner {
                    records_array.append((record.cid, record.hash_commit, record.unlock_timestamp, record.access_type, record.name));
                }
            };
            
            records_array
        }
    }

}