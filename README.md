# Beacon Lottery

This is a simple Ethereum smart contract based lottery written in Solidity. The contract randomly picks a winner from the participating users, and rewards the winner with some Ether. The source of randomness for determining the winner is a [randomness beacon](http://www.copenhagen-interpretation.com/home/cryptography/cryptographic-beacons) based on the [Sloth protocol](https://eprint.iacr.org/2015/366). The working of the randomness beacon is explained [here](https://www.univie.ac.at/ct/stefan/blockchain19.pdf).

Note that this code has been written as a prototype and was used for gas measurements, and should NOT be used as an actual lottery on the mainnet, as users are not protected from losing their money if the lottery operator misbehaves, i.e., if the `draw()` method is never called. To this effect, the provided contract can be extended to offer the functionality described for ITV, INP, or OPT models.

The working of the lottery is explained in the following sections:

## Lottery

The participants have to pay the contract a certain amount (by invoking `bet()`) to participate in the lottery. 
The contract owner calls `fetch_random_value()` followed by `draw()` to determine the winner after a suitable number of users have placed their bets. A fraction of the total amount that was paid to the contract by the participants is paid to the winner of that round of the lottery. The rest is paid to the contract owner as earnings.

The contract obtains a random value from the beacon using an [oracle](www.oraclize.it). This value is used to randomly pick a winner from the participating users.

The lottery model implemented here lies between an OFF and an ITV model. It is mostly off-chain, while at the same time, performs verification of beacon output on-chain and does not require the users to send the commitment value obtained from the beacon to the smart contract.

## Beacon

The implementation of the beacon can be found [here](https://github.com/randomchain/randbeacon). The beacon runs off-chain and is assumed to have a API that can be accessed (that returns the random value and the proof (explained in the following section)) via a URL. The URL is then queried by the Oraclize service to obtain the values into the smart contract. A sample implementation of the beacon as a web-app is provided [here](https://github.com/randomchain/randbeacon/blob/master/extra_apps/wapp.py).

The participants interact with the beacon directly to send their inputs and verify the commitments themselves (to check if their input has been included or not).

Note that this lottery implementation assumes that the beacon operator need not be the same as the lottery operator.

## Sloth Verification

The contract also performs verification (on request by a user) of the proof given by the beacon as per the verification algorithm given [here](https://github.com/randomchain/pysloth/blob/3ed53be7cb4da03aa83b4799729151454aa934a1/sloth.c#L200).

Sloth verification is performed using repeated modular squaring. The `bigModExp` precompile is used to perform this operation.

The following assumptions are made about the 'proof' given by the beacon:
- The proof contains `witness`, `seed`, `iter_exp` and `prime`.
    - The hash of the `witness` is the random value generated by the beacon.
    - The values of `seed` and `prime` are assumed to be computed by the beacon itself according to the algorithm [here](https://github.com/randomchain/pysloth/blob/3ed53be7cb4da03aa83b4799729151454aa934a1/sloth.c#L99) from the `input_string` which here is the root of merkle tree of inputs committed by the users. Users can verify if this computation is correct by themselves.
    - `iter_exp` is the value: 2<sup>iterations</sup>. Squaring a value `iterations` times is the same as raising it to the exponent 2<sup>iterations</sup>. Pre-computing this value by the beacon allows for directly making use of the `bigModExp` precompile.
- The above parameters are encoded as strings (of their values in base-10) separated by hiphens for easy parsing in the smart contract. The string is formatted as: `"witness-seed-iter_exp-prime"`.

A user who wants to verify the proof given by the beacon first invokes `fetch_proof()`, which obtains the proof from the beacon using the oracle, followed by `verify()` which performs the verification.

The verification works as follows:
- Square 'witness' 'iterations' times modulo 'prime'.
- Check if the resultant value equals the seed:
    - if 'true', then beacon output is valid
    - else, beacon output is invalid

Since the 'seed' value is obtained from the user inputs (condensed as a Merkle tree), performing the above verification checks if the user submitted inputs have correctly been used in computing the random number (which is equal to the hash of the 'witness') according to the Sloth algorithm or not.

## Gas Values for Modular Exponentation

| Size of Witness (bits) | Size of Prime Modulus (bits) | Iterations | Gas       |
|------------------------|------------------------------|------------|-----------|
| 512                    | 512                          | 1024       | 159,129   |
| 1024                   | 1024                         | 1024       | 517,171   |
| 512                    | 512                          | 2048       | 368,844   |
| 1024                   | 1024                         | 2048       | 1,198,745 |

These values are obtained using the gas calculation formula given [here](https://eips.ethereum.org/EIPS/eip-198).
