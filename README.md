# 🛡️ Reclaim – Preserve Your Legacy on Starknet

This repository contains the **Reclaim** project, developed for the [Re{ignite} Starknet Hackathon](https://hackathon.starknet.org).

<div style="display:flex; flex-direction:column; row-gap:40px; align-items:center; padding:40px">
<img src='./assets/Starknet-logo.png' width='50%' />
<img src='https://cdn.prod.website-files.com/67fd133ddb82322a63a09d4b/67fd17f25d83ce882f306427_hackathon-logo.svg'  width='50%'/>
</div>

[logo1]: https://cdn.prod.website-files.com/67fd133ddb82322a63a09d4b/67fd17f25d83ce882f306427_hackathon-logo.svg
[logo2]: ./assets/Starknet-logo.png
[logo3]: ./assets/reclaim-logo.jpg
[hackathon-link]: https://hackathon.starknet.org
[starknet-link]: https://starknet.io

---

## 🌱 What is Reclaim?
<div style="display:grid; place-content:center; padding:30px">
<img src="./assets/reclaim-logo.jpg" width="350" >
</div>
**Reclaim** is a decentralized memory vault built on Starknet. It allows users to store their most meaningful memories—photos, audio, text—**encrypted and permanently accessible**, while preserving **privacy, ownership and controlled access** over time.

Reclaim is not just a memory app. It’s a protocol that:
- Ensures encrypted data is **accessible only under strict conditions** (e.g. after a date or through heir consensus).
- Respects the **sovereignty** of the user: they hold their keys, and access never depends on a centralized service.
- Demonstrates the foundation of decentralized key management on-chain, paving the way for future integrations like LitProtocol.
---

## 🧩 The Problem

Web3 lacks reliable, decentralized mechanisms to:
- Permanently store **private** data.
- Enable **conditional access** to encrypted content.
- Allow users to **pass down** digital assets or secrets without trusting third parties.

---

## 🧪 Our Solution

Reclaim defines a **dual-access protocol** allowing:

1. **Time-lock unlocks**: Memories can be revealed after a specific date, validated by the smart contract.
2. **Heir consensus unlocks** using **Shamir Secret Sharing (SSS)**:
   - The encryption key is split into 3 parts:
     - One held by the user
     - One held by the smart contract (encrypted)
     - One distributed across designated heirs, requiring consensus to reconstruct
   - Access is granted when at least 2 out of 3 shares are recovered.

All encryption and decryption happens **client-side**, ensuring total data privacy.

---

## 🏗️ Architecture

reclaim
├── contract/ # Starknet Cairo 1.0 smart contract
├── frontend/ 
├── backend/ 


- Files are encrypted in-browser using AES-256.
- Encrypted content is pinned to IPFS.
- Metadata and access control rules are stored in the Starknet smart contract.

---

## 🧠 Technologies Used

- ⚡ Starknet (Cairo 1.0)
- ⚡ Starknet.dart
- 🔐 AES-256 symmetric encryption
- 🧩 Shamir Secret Sharing (SSS)
- 🌐 IPFS
- 📱 Flutter (Dart) – cross-platform frontend (mobile + web)
- 🧠 Future-ready: LitProtocol & ZK-compatible design

---

## 🚀 MVP Features

- Register with Google → invisible wallet creation
- Upload encrypted memories (image, text)
- Choose access method:
  - Unlock after specific date
  - Unlock by heir consensus
- View stored memories once access is granted

---

🔮 Future Vision
This MVP demonstrates that:

Fully decentralized access control is possible without central custodians

The protocol can scale by integrating:

⏳ Smart contract unlock conditions (time, wallet, NFT ownership, etc.)

🔐 Secret storage via LitProtocol or other threshold-based MPCs

🧠 zk-Proofs for verifiable conditions without revealing data

👪 Social recovery and heir designation UI

🤝 Contributors
Built with care by:

- Jean Pool Cruz [@jpool09](https://github.com/jpool09) — App design + Flutter development
- Mateo Atilio Mancinelli [@teoeme](https://github.com/teoeme) — Smart Contract + protocol design
- Ricardo Mazuera [@ricardomazuera](https://github.com/ricardomazuera) — Invisible wallet creation + starknet.dart implementation



🧠 Learn More

about the protocol: [docs/protocol.md](./docs/protocol.md)

[LitProtocol & SSS](https://litprotocol.io) – our approach lays groundwork for their integration

[Shamir Secret Sharing (Wikipedia)](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing)

[Cairo 1.0](https://book.cairo-lang.org/) – the Starknet programming language

“Memories are meant to last. Reclaim ensures they do — even after we're gone.”
