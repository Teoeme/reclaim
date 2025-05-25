//util deploy function
use snforge_std::{
    ContractClassTrait,
    declare,
    DeclareResultTrait,
    start_cheat_block_timestamp_global,
    spy_events,
    EventSpyAssertionsTrait,
    start_cheat_caller_address,
    stop_cheat_caller_address,
};
use contracts::reclaim::{
    IReclaimDispatcher,
    IReclaimDispatcherTrait,
    reclaim
};
use starknet::ContractAddress;
use core::byte_array::{ByteArray, ByteArrayTrait};
use core::array::ArrayTrait;

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

fn USER_1() -> ContractAddress {
    'USER_1'.try_into().unwrap()
}


fn USER_2() -> ContractAddress {
    'USER_2'.try_into().unwrap()
}

// Definimos las variables globales correctamente
fn CIPHER_SECRET() -> ByteArray {
    "0x394176462b6f4369624d7747593732476a4e3452523243714c6f37456b2f2b553852326b4e4e78326b34566443737753325645617a62336f396f6536305462306461366f31554f56554e5838556b56696a414b64784b303530504d51593842622f49422f5478417734756d725350512b706f39644d71326c4266714d325a6f4a596b486c2f6a4578646643724271486a31794f4f464965362f633264307a6b516b34584d4e6a34317575305077324369343346504f32354b5338663970446c462f39566353586e6571533368507a3662767259766d6b766b464243487a45455871676450686b3334536a54674361712b2f50516342793349314e53556b506441432f53615770544a575a724d667368523733585672425a336a6f516b4f784c6664434f616731324b38616938657a50416f707467464874572f2f2f354b4d3273"
}

fn CIPHER_SECRET2() -> ByteArray {
    "0x38334373676b45504b2f75664a66546b4a4343416d6f2b42327476444735474d75622f476a6a55494e59386841625a2f6645717a335138734d766e504843636e5976483034633652786149362b52384c5a58506b5074435966586450464456795a386e623756504e43335047797a5433534e3457396551516d694f38513153654142366a56356779334a3676413058774d765a5a506651413144316b4a4b61377750384c6e5871324d6d787035374342716c37457a3239754e6263566c6d35654c72314c566b623177547545512f42666f32477166746445624846783062777a332f7572345130726a6e713077377874702b36546e6e39666a644d366f63376138396f706833386a6679412b434c41786a2f3756503361384f4e56786c38593458732b627273727130446d4b752f665739574c37557a6c535731324e6765394f"
}

fn CIPHER_SECRET3() -> ByteArray {
    "0x4f50477544784e72364552436d48664c43733447514b344a644a454f564954774773686c696637754b5942694c2b4f4c53356630464e474f774c526e6f615630317a75477952466f75624970626642566b7a353672327561587a6b767a66524d37696f62683139706e456c7856775432473366594b707942536b614747416971664f4256735470596e2b4559796c794b7a74586f74364374725565504250626e5244686147567273616b34717434622b6466585359317067384744393152376e6142414e7032676e4a397067434d6b7a396a425730726d6c485736416e3663444f2f6e2f35767252543932654c6256717a6748474b397173442b6c5a4e556c4d4f6b4c502f4f663067396879582b627546547a7844584b6458366f776e6339346a62304c6a2b664b344f3679513354366e626f6d4153626736727a316e544231"
}

fn CID() -> ByteArray {
    "QmVa11uCRjM5VPzibumea6yzkUtYc3u1rMibcUyReTBgau/1748015337000.txt"
}

fn CID_2() -> ByteArray {
    "Qmd11fniBBuyXJkoQLge93xrgVr2zG2QNiAhdt1kBdoeao/1748036498000.txt"
}

fn CID_3() -> ByteArray {
    "QmZChwCyfoNDUHQ5S2bFgUiJsHq5UcyBKakqgc6yda1Z1k/1748036483000.txt"
}

fn HASH_COMMIT() -> ByteArray {
    "440c506dc4d939ccac762dc1ced8e965"
}

fn HASH_COMMIT_2() -> ByteArray {
    "e2c8148ec4c00874fcc52977356937f3dc9c9ca4e8489a038f8f0ff3f930449b"
}
fn HASH_COMMIT_2_SHORT() -> ByteArray {
    "e2c8148ec4c00874fcc52977356937f"
}

fn HASH_COMMIT_3() -> ByteArray {
    "949e94934a751e6b947351b23642a0b093998d062d07d2a359f4cc5e44febcd7"
}

fn __deploy__() -> IReclaimDispatcher {
    let contractClass= declare("reclaim").unwrap().contract_class();
    let constructor_calldata = ArrayTrait::new();
    let (contract_address,_ )= contractClass.deploy(@constructor_calldata).expect('Failed to deploy contract');
    
    let Reclaim = IReclaimDispatcher { contract_address };
    
    
    Reclaim
}

#[test]
fn test_save_metadata(){
    let reclaim = __deploy__();

    let unlock_timestamp: felt252 = 1747018800; // 2025-05-12 00:00:00 hackathon start date
    
    start_cheat_caller_address(reclaim.contract_address, USER_1());
    reclaim.save_metadata(HASH_COMMIT(), CIPHER_SECRET(), CID(), unlock_timestamp);
    stop_cheat_caller_address(reclaim.contract_address);
    
    start_cheat_block_timestamp_global(unlock_timestamp.try_into().unwrap() + 1);
    
    let (record_cipher_secret, record_cid, record_hash_commit, owner) = reclaim.reclaim(HASH_COMMIT());
    assert(record_cipher_secret == CIPHER_SECRET(), 'Cipher secret mismatch');
    assert(record_cid == CID(), 'CID mismatch');
    assert(record_hash_commit == truncate_hash(HASH_COMMIT()), 'Hash commit mismatch');
    assert(USER_1().into() == owner, 'Owner mismatch');
}

#[test]
fn test_save_and_reclaim_multiple_files(){
    let reclaim = __deploy__();

    let unlock_timestamp:felt252 = 1747018800; // 2025-05-12 00:00:00 hackathon start date

    reclaim.save_metadata(HASH_COMMIT(), CIPHER_SECRET(), CID(), unlock_timestamp);

    let unlock_timestamp2:felt252 = 1747018800; 

    reclaim.save_metadata(HASH_COMMIT_2(), CIPHER_SECRET2(), CID_2(), unlock_timestamp2);

    let unlock_timestamp3:felt252 = 1747018800; 

    reclaim.save_metadata(HASH_COMMIT_3(), CIPHER_SECRET3(), CID_3(), unlock_timestamp3);

    start_cheat_block_timestamp_global(unlock_timestamp.try_into().unwrap() + 1);

    let (record_cipher_secret, record_cid, record_hash_commit,_) = reclaim.reclaim(HASH_COMMIT_2());
    assert(record_cipher_secret == CIPHER_SECRET2(), 'Cipher secret mismatch');
    assert(record_cid == CID_2(), 'CID mismatch');
    assert(record_hash_commit == truncate_hash(HASH_COMMIT_2()), 'Hash commit mismatch');


    let (record_cipher_secret, record_cid, record_hash_commit,_) = reclaim.reclaim(HASH_COMMIT());
    assert(record_cipher_secret == CIPHER_SECRET(), 'Cipher secret mismatch');
    assert(record_cid == CID(), 'CID mismatch');
    assert(record_hash_commit == truncate_hash(HASH_COMMIT()), 'Hash commit mismatch'); 
}

#[test]
#[should_panic(expected : 'R: File still locked')]
fn test_reclaim_before_unlock_timestamp(){
    let reclaim = __deploy__();

    let unlock_timestamp:felt252 = 1747018800; 

    reclaim.save_metadata(HASH_COMMIT(), CIPHER_SECRET(), CID(), unlock_timestamp);
    
    start_cheat_block_timestamp_global(unlock_timestamp.try_into().unwrap() - 1);

    reclaim.reclaim(HASH_COMMIT());
}

#[test]
fn test_save_metadata_event(){
    let reclaim = __deploy__();

    let unlock_timestamp: felt252 = 1747018800; 

    let mut emitted_events = spy_events();
    reclaim.save_metadata(HASH_COMMIT(), CIPHER_SECRET(), CID(), unlock_timestamp);

    emitted_events.assert_emitted(
        @array![
            (
                reclaim.contract_address,
                reclaim::Event::MetadataSaved(reclaim::MetadataSaved {
                    hash_commit: truncate_hash(HASH_COMMIT()),
                    unlock_timestamp
                })
            )
        ]
    )
}

#[test]
fn test_reclaim_event(){
    let reclaim = __deploy__();

    let unlock_timestamp: felt252 = 1747018800; 

    let mut emitted_events = spy_events();
    reclaim.save_metadata(HASH_COMMIT(), CIPHER_SECRET(), CID(), unlock_timestamp);

    start_cheat_block_timestamp_global(unlock_timestamp.try_into().unwrap() + 1);

    reclaim.reclaim(HASH_COMMIT());
    
    emitted_events.assert_emitted(
        @array![
            (
                reclaim.contract_address,
                reclaim::Event::FileReclaimed(reclaim::FileReclaimed { 
                    hash_commit: truncate_hash(HASH_COMMIT())
                })
            )
        ]
    )
}

#[test]
fn test_get_records_by_owner(){
    let reclaim = __deploy__();

    let unlock_timestamp: felt252 = 1747018800; 
    start_cheat_caller_address(reclaim.contract_address, USER_1());
    reclaim.save_metadata(HASH_COMMIT(), CIPHER_SECRET(), CID(), unlock_timestamp);
    
    let unlock_timestamp2: felt252 = 1747018800; 
    
    reclaim.save_metadata(HASH_COMMIT_2(), CIPHER_SECRET2(), CID_2(), unlock_timestamp2);
    stop_cheat_caller_address(reclaim.contract_address);

    start_cheat_caller_address(reclaim.contract_address, USER_2());
    let unlock_timestamp3: felt252 = 1747018800; 
    
    reclaim.save_metadata(HASH_COMMIT_3(), CIPHER_SECRET3(), CID_3(), unlock_timestamp3);
    stop_cheat_caller_address(reclaim.contract_address);

    let records = reclaim.get_records_by_owner(USER_1().into());
    assert(records.len() == 2, 'Number of records mismatch');
    let (first_cid, _, _) = records[0];
    assert(first_cid == @CID(), 'CID mismatch');
    println!(" USER_1 records: {:?}", first_cid);

    let records2 = reclaim.get_records_by_owner(USER_2().into());
    assert(records2.len() == 1, 'Number of records mismatch');
    let (first_cid2, _, _) = records2[0];
    assert(first_cid2 == @CID_3(), 'CID mismatch');
}

#[test]
fn test_reclaim_with_short_hash_commit(){
    let reclaim = __deploy__();

    let unlock_timestamp: felt252 = 1747018800; 

    reclaim.save_metadata(HASH_COMMIT_2(), CIPHER_SECRET(), CID(), unlock_timestamp);
    
    let short_hash_commit = truncate_hash(HASH_COMMIT_2());
    let short_hash_commit_barray= HASH_COMMIT_2_SHORT();
    println!("short_hash_commit_barray: {:?}", short_hash_commit_barray);
    
    start_cheat_block_timestamp_global(unlock_timestamp.try_into().unwrap() + 1);
    let (record_cipher_secret, record_cid, record_hash_commit,_) = reclaim.reclaim(short_hash_commit_barray);
    assert(record_cipher_secret == CIPHER_SECRET(), 'Cipher secret mismatch');
    assert(record_cid == CID(), 'CID mismatch');
    assert(record_hash_commit == short_hash_commit, 'Hash commit mismatch'); 
}