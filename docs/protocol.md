🤩 The Problem

In the digital age, the most personal and valuable data we create — our memories, voices, and emotions — are often stored in centralized, fragile, and opaque systems. We entrust our legacy to cloud providers with limited guarantees of permanence, privacy, or autonomy.

The core technical problem is this: how can we preserve personal memories in a decentralized, private, and permanent way, while allowing access only under specific user-defined conditions, especially in the case of death or loss of access?

🔐 The Solution

Reclaim enables users to upload encrypted memories (images, text, audio) to IPFS, while recording metadata and access conditions on a Starknet smart contract. All data is encrypted in-browser using AES-256, ensuring Reclaim and third parties never have access to the contents.

Transactions are signed automatically using an embedded invisible wallet provided by Cavos Wallet Provider, enabling a Web2-like experience with Web3 guarantees.

🧪 The Protocol: Decentralized Access Control

Reclaim’s main innovation lies in its decentralized conditional access protocol, conceptually aligned with key management schemes like LitProtocol, but implemented natively on-chain and without external services.

We use Shamir Secret Sharing (SSS) to split the decryption key into three parts:

🔑 One part for the user (memory owner)

🧬 One part distributed among designated heirs (with minimum threshold consensus)

🛡️ One part held by the smart contract, encrypted with a secondary secret

Any 2 out of the 3 parts can reconstruct the full decryption key.

The smart contract does not expose addresses or keys directly. It releases its share only if certain conditions are met — for example, a specific unlock_timestamp.

To access a memory:

Heirs must collaborate to reconstruct their portion

Claim the contract’s encrypted share

Decrypt it

Combine the pieces to rebuild the full key

All of this happens client-side, preserving privacy

⏳ Variant 1: Time-based Access (No SSS)

A simplified version of the flow supports solo access using time-based unlocks:

A symmetric encryption key is generated client-side to encrypt the file

This key is then encrypted with the user’s public key

The encrypted file is uploaded to IPFS

The encrypted symmetric key and unlock metadata are stored in the contract

After the unlock date, the user can retrieve the encrypted symmetric key, decrypt it using their private key, and then use the resulting symmetric key to access the memory (all client-side)

This version removes heir coordination and enables personal legacy vaults.

🧠 Reclaim & LitProtocol

Reclaim does not aim to replace LitProtocol — it shares the same foundational goals.

Lit uses distributed nodes to coordinate access conditions and release decryption keys. Reclaim builds on these concepts, implementing a fully on-chain approach tailored to Starknet.

While Reclaim currently avoids relying on external validator nodes, the architecture is designed to evolve. Future versions may incorporate LitProtocol nodes, ZK-proofs, or other decentralized validation layers to express more complex access conditions.

Rather than competing with Lit, Reclaim demonstrates that on-chain logic enforcement and key custodianship are already viable, laying the groundwork for seamless interoperability and composability. Conceptually, Reclaim and Lit share the same vision of decentralized access control.

💡 Unique Value

📁 End-to-end encryption by default

⛓️ On-chain conditional access with no custodians

🤝 Digital inheritance without central points of failure

🧉 Protocol compatible with LitProtocol and future secret-sharing networks

Reclaim addresses a critical challenge in Web3: how to securely store private, immutable data with programmable, decentralized access — without relying on centralized services.

This is not a concept. Reclaim is a live, working proof-of-concept, showing that personal data sovereignty is already achievable.

🚀 The Future

Reclaim is just the beginning of a broader platform for managing digital legacies. Future iterations will allow users to:

Define dynamic access conditions (dates, identities, NFTs, verifiable events)

Delegate access to individuals, contracts, or DAOs

Permanently store their most important memories with full sovereignty

We plan to integrate LitProtocol or ZK-based validation, and improve UX with advanced invisible wallets.

But the foundation is already here: a decentralized, privacy-preserving protocol for personal data — no intermediaries, no custodians, no tricks.

Reclaim is not a demo — it's a foundation for the future.

