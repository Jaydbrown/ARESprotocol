# ARES Protocol

ARES is a treasury governance protocol built in Solidity. It lets authorized 
participants propose, approve, and execute treasury actions through a 
time-delayed, multi-confirmation system. It also handles contributor reward 
distribution through a scalable Merkle-based claim system.




## How It Works

### Proposal System
Authorized proposers can propose three types of treasury actions:
- `transfer(token, recipient, amount)`
- `call(target, calldata)`
- `upgrade(oldContract, newContract)`

A proposal cannot execute immediately. It goes through this lifecycle:
```
PENDING → COMMITTED → READY → EXECUTED
                           ↘ CANCELLED
```

- Admin commits the proposal
- 3 proposers confirm it
- 2 day delay must pass
- Admin executes it

### Time Delay Engine
Every treasury operation is queued with a delay between 1 and 30 days. 
The execution window is 7 days after the eta passes. After that the 
transaction expires.

### ARES Reward Distribution
Contributors claim tokens independently using a Merkle proof. The root 
is updated through a multisig flow — owners submit, confirm to threshold, 
and execute. Claims are tracked per root so a root update does not 
invalidate old claims.


## Security

| Threat | Protection |
|---|---|
| Signature replay | `usedSignatures` mapping + nonce |
| Signature malleability | ECDSA s-value check |
| Cross-chain replay | `block.chainid` in `personalHash` |
| Domain collisions | `address(this)` in `personalHash` |
| Reentrancy | `locked` bool + state update before external call |
| Transaction replacement | Hash committed at queue time, verified at execution |
| Proposal replay | `proposalHashUsed` mapping |
| Double claim | `claimed[root][address]` mapping |
| Timestamp manipulation | `eta` committed to storage, `MIN_DELAY` = 1 day |


## Setup
```bash
forge install
forge build
forge test
```


## Running Tests
```bash
# run all tests
forge test

# run with logs
forge test -vvv

# run specific test
forge test --match-test test_proposalLifecycle -vvv
```

---

## Test Coverage

### Functional Tests
- `test_proposalLifecycle` — full proposal flow from pending to executed
- `test_timelockExecution` — queue and execute a transaction after delay
- `test_proposeCall` — propose a call type proposal
- `test_proposeUpgrade` — propose an upgrade type proposal
- `test_cancelProposal` — cancel a pending proposal
- `test_aresClaimFlow` — full Merkle claim flow
- `test_multisigThreshold` — confirm multisig threshold enforcement

### Exploit Tests
- `testFail_reentrancyAttack` — malicious contract tries to reenter execute
- `testFail_doubleClaimAttempt` — claim twice with same proof
- `testFail_invalidSignature` — claim with wrong signer key
- `testFail_prematureTimelockExecution` — execute before delay elapses
- `testFail_proposalReplay` — submit identical proposal twice
- `testFail_executeBeforeReady` — execute proposal before confirmations
- `testFail_confirmWithoutCommit` — confirm before proposal is committed
- `testFail_unauthorizedProposer` — non-proposer tries to create proposal
- `testFail_doubleConfirm` — same proposer confirms twice
- `testFail_timelockReplay` — execute same transaction twice
- `testFail_belowDelayQueue` — queue with delay below minimum
- `testFail_expiredTransaction` — execute after 7 day expiry window


## Contracts

### ProposalModule
Manages the full proposal lifecycle. Authorized proposers create proposals, 
admin commits them, proposers confirm them, admin executes them.

### TimeDelayedExecutionEngine
Queues treasury transactions with a mandatory delay. Prevents reentrancy, 
transaction replacement, timestamp manipulation, and proposal replay.

### ARES
Handles contributor reward distribution. Uses Merkle proofs for scalable 
claims and a multisig for root updates.

### cryptoGraphicAuthorizationLayer
Entry point for signed actions. Handles ECDSA recovery, nonce management, 
replay protection, and domain binding.


## Libraries

### proposeAssetTransaction
Validates inputs for transfer, call, and upgrade proposals.

### MultiSigLib
Handles multisig state operations via storage pointer passed from module.

### MerkleLib
Proof verification, leaf building, message hashing, signer recovery.

### ECDSA
Signature recovery with s-value malleability protection.


## Interfaces

- `Itoken` — ERC20 standard
- `Itreasury` — deposit, transfer, call, upgrade, checkBalance
- `IgoverningParticipants` — createProposal, queueProposal, confirmProposal, executeProposal


## License
