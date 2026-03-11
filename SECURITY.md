# ARES Protocol — Security Analysis

## Overview

ARES moves tokens and executes treasury calls. That makes it a target. 
This document covers the attack surfaces, how the system handles them, 
and what gaps still exist.


## Attack Surfaces

### Signature Replay

The attack is simple — intercept a valid signature and resubmit it. 
The system tracks every signature by hashing r and s together and storing 
the result in usedSignatures. Once used, it is marked true and cannot go 
through again. The nonce adds a second lock — every address has a counter 
that increments after each valid use. Even if the attacker has the exact 
signature bytes, the nonce it was signed against is already consumed so 
the hash will not match.

### Signature Malleability

Every ECDSA signature has a mirror. For any valid (v, r, s) there is a 
second valid (v flipped, r, -s mod n) that also passes verification for 
the same message. An attacker can flip your signature into its mirror and 
get a second valid one without knowing your private key. The ECDSA library 
blocks this by rejecting any s value in the upper half of the secp256k1 
curve. Only one canonical signature is accepted per message so the mirror 
is always invalid.

### Cross-Chain Replay

A signature produced on mainnet should not work on Sepolia. The 
personalHash bakes block.chainid into the domain at construction time and 
stores it as immutable. Two chains produce different personalHash values 
so ecrecover returns the wrong address on the wrong chain and the check 
fails.

### Domain Collisions

Two contracts with the same code at different addresses should not share 
valid signatures. address(this) is also in the personalHash. Different 
deployment addresses produce different hashes so a signature for contract 
A always fails on contract B.

### Reentrancy

A malicious recipient could call back into executeTransaction during the 
treasury transfer and execute the same transaction twice. Two things stop 
this. The noReentrancy modifier sets a locked bool before the external 
call and releases it after. On top of that, txn.status is set to Executed 
before the treasury call happens. If the modifier is bypassed the status 
check still catches the second entry.

### Transaction Replacement

Between queue time and execution time an attacker could try to swap the 
parameters. At queue time all parameters are hashed with personalHash and 
stored in txHash. At execution time the hash is recomputed from storage 
and checked against the stored value. The parameters at execution come 
from storage not calldata so there is no substitution surface.

### Proposal Replay

The same proposal submitted twice would trigger two executions. Every 
proposal hashes its type, all parameters, and the proposer address into 
proposalHash. That hash is checked against proposalHashUsed before 
storage. Same inputs cannot produce a second proposal.

### Double Claim

A contributor submitting the same proof twice would drain the reward pool. 
Claims are tracked per root and per address in claimed[merkleRoot][msg.sender]. 
First claim sets it true. Second claim hits the require and reverts. Root 
updates do not clear old records so each root manages its own claim state 
independently.

### Timestamp Manipulation

Miners can shift block.timestamp by around 15 seconds. The eta is 
committed to storage at queue time as block.timestamp plus delay. 
MIN_DELAY is 1 day so a 15 second shift does nothing. Execution checks 
the stored eta not a fresh calculation so the window cannot be gamed.

---

## Remaining Risks

The biggest gap is single admin. ProposalModule and 
TimeDelayedExecutionEngine both run on one admin key. If that key is 
compromised an attacker can queue transactions and commit proposals. The 
proposer confirmation slows them down but does not stop a patient attacker. 
A multisig on admin would fix this.

Constructor addresses are trusted without verification. If a malicious 
contract is passed as treasury the system cannot detect it.

The contracts are not upgradeable. A bug found after deployment means 
redeploy and migrate. That is the tradeoff for immutability.