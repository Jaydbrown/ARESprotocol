# ARES Protocol Architecture Document

## Overview

The ARES protocol was built around one idea — nothing touches the treasury 
directly. Every action has to go through a proposal, get confirmed, wait out 
a delay, and then execute. The system is split into four folders: modules, 
libraries, interface, and core. Each folder has a specific job and they do 
not overlap.


## System Architecture

The system works in layers. A user action starts at the core layer where 
the cryptographic authorization layer verifies the signature, checks the 
nonce, and makes sure the signature has not been used before. Once that 
passes, the action moves into the modules. The modules own all the state — 
the mappings, the proposal structs, the transaction queue. They use the 
libraries to validate inputs and compute hashes, and they use the interfaces 
to talk to external contracts like the token and the treasury.

The ProposalModule handles the full proposal lifecycle. The 
TimeDelayedExecutionEngine sits between approved proposals and the treasury, 
making sure nothing executes without waiting out the delay. ARES handles 
contributor rewards separately using a Merkle tree so you can have thousands 
of recipients without storing all of them on chain.

## Module Separation

The reason libraries are separate from modules is that libraries have no 
state. proposeAssetTransaction validates the inputs for transfer, call, and 
upgrade but it does not execute anything and it does not store anything. The 
module calls the library first, and if validation passes, the module handles 
the storage and the lifecycle. This keeps the logic clean — if you need to 
change the validation rules you change the library, you do not touch the 
module.

Same thing with MerkleLib. It builds the leaf, verifies the proof, recovers 
the signer. It does not know about the root or the claimed mapping — those 
live in ARES. The library just does the computation and returns the result. 
MultiSigLib works the same way — it takes a storage pointer from the module, 
operates on it, and hands control back.

## Security Boundaries

The boundaries are strict. Only authorized proposers can create proposals. 
Only admin can commit a proposal. Proposals need three proposer confirmations 
plus a two day delay before they move to Ready. Only admin can execute. This 
means admin alone cannot push a proposal through — they need the proposers to 
confirm first. And proposers alone cannot execute — they need admin to commit 
and execute.

For the timelock, only admin can queue and execute transactions. The minimum 
delay is one day and the maximum is thirty days. The eta is committed to 
storage at queue time so nobody can manipulate the timestamp to skip the 
delay. Transactions expire after seven days past eta so stale transactions 
cannot sit in the queue forever.

In ARES, setMerkleRoot is protected by onlyViaMultisig which checks that 
msg.sender is address(this). This means the only way to update the root is 
through the multisig execution path — owners submit, confirm to threshold, 
then execute, which calls the contract on itself.

## Trust Assumptions

Admin is trusted. If admin is compromised the attacker can queue transactions 
and commit proposals. The three proposer confirmation requirement slows this 
down because admin alone cannot move a proposal to Ready. But a patient 
attacker who controls admin can still get proposals executed after the delay.

The multisig in ARES reduces the single point of failure for root updates. 
No single owner can update the root alone — the threshold has to be met. 
But ProposalModule and TimeDelayedExecutionEngine are still single admin 
controlled. Moving admin to a multisig would close that gap entirely.

The libraries are trusted to be correct since they are internal and not 
upgradeable. The interfaces trust that the addresses passed into the 
constructors are honest implementations of the expected contracts. If a 
malicious contract is passed as the treasury, the system cannot detect that.