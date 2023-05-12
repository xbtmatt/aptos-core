---
title: "Mint NFTs with the Aptos CLI"
---

# Mint NFTs with the Aptos CLI

This tutorial is intended to demonstrate how to programmatically mint NFTs on Aptos. It builds upon the simplest version of an NFT Collection creator manually minting an NFT to a receiver's account to eventually creating a more complex smart contract that facilitates users requesting an NFT and receiving it without ever having to get explicit signer approval from the Collection creator.

## Prerequisites

This tutorial assumes you have:

* the [Aptos CLI](../../tools/install-cli/index.md) (or you can run from [aptos-core](https://github.com/aptos-labs/aptos-core) source via `cargo run`)
* the `aptos-core` repository checked out: `git clone https://github.com/aptos-labs/aptos-core.git`
* a general understanding of NFTs and NFT Collections
* an understanding of [the Token V2 standard](https://aptos.dev/guides/nfts/token-v2)

## 1. Create an NFT

We're going to start by making the simplest form of the flow for creating a collection and minting a token and sending it to a user. The code for this part of the tutorial is in the first section of the `move-examples/mint_nft` folder in the aptos-core repository.

Here are the most basic things we need to do first:

* Create the NFT collection and store the configuration options for it
* Mint a non-fungible token within that collection using the configuration options
* Send the minted token to a user account

### Defining configuration options

The first thing we need to do is store the collection information somewhere. These will be fields we get on-chain later to mint the token.

We'll store it in a `struct` called `MintConfiguration`. These fields aren't the only fields used to create a collection, but they are the most basic ones meant to demonstrate how to store configuration details.

```rust
struct MintConfiguration has key {
    collection_name: String,
    token_name: String,
    token_uri: String,
}
```

We give `MintConfiguration` the `key` ability so that the module contract can store it at an account's resources, which the module can find later if supplied with the account address. The account address we store it to will be the creator of the collection.

Some collection configuration parameters will be hard-coded in the contract as `const` variables:

```rust
    const COLLECTION_DESCRIPTION: vector<u8> = b"Your collection description here!";
    const TOKEN_DESCRIPTION: vector<u8> = b"Your token description here!";
    // ...other const values
    const TOKENS_BURNABLE_BY_CREATOR: bool = false;
    const TOKENS_FREEZABLE_BY_CREATOR: bool = false;
```

You can make these configurable on your own by adding them to the list of parameters sent into `initialize_collection` function below.

### Writing a collection creation function

```rust
public entry fun initialize_collection(
    creator: &signer
    collection_name: String,
    collection_uri: String,
    maximum_supply: u64,
    royalty_numerator: u64,
    royalty_denominator: u64,
    token_name: String,
    token_uri: String,
) acquires MintConfiguration {
    // ensure the signer of this function call is also the owner of the contract
    let creator_addr = signer::address_of(creator);
    assert!(creator_addr == @mint_nft, error::permission_denied(ENOT_AUTHORIZED));

    aptos_token::create_collection(
        creator,
        string::utf8(COLLECTION_DESCRIPTION),
        maximum_supply,
        collection_name,
        collection_uri,
        MUTABLE_COLLECTION_DESCRIPTION,
        MUTABLE_ROYALTY,
        MUTABLE_URI,
        MUTABLE_TOKEN_DESCRIPTION,
        MUTABLE_TOKEN_NAME,
        MUTABLE_TOKEN_PROPERTIES,
        MUTABLE_TOKEN_URI,
        TOKENS_BURNABLE_BY_CREATOR,
        TOKENS_FREEZABLE_BY_CREATOR,
        royalty_numerator,
        royalty_denominator,
    );
    move_to(creator, MintConfiguration {
        collection_name,
        token_name,
        token_uri,
    });
}
```

First off, note the first couple lines of the function:

```rust
let creator_addr = signer::address_of(creator);
assert!(creator_addr == @mint_nft, error::permission_denied(ENOT_AUTHORIZED));
```

This gates the ability to run this function to the owner of the contract. This isn't necessary, but unless you specifically design a contract around
letting multiple accounts use it, it's simpler to only allow the account that deploys the contract to use it. This avoids a few potential vulnerabilities where you unintentionally allow an account to modify internal module resources for another account.

:::note
We define `@mint_nft` when we deploy the module with the `--named-addresses mint_nft=<YOUR_ACCOUNT_ADDRESS>` flag.
:::

After that, we see the logic for our very basic initialize collection function. It creates a collection based off the parameters given in the
function arguments and then stores the minting config info to the creator's account resources with `move_to`.

Some of these fields are self-explanatory, but here's a quick rundown of what you're actually setting here:

* `creator`: The creator and owner of the collection. This is the only account authorized to mint NFTs for this collection and change fields marked as mutable.
* `COLLECTION_DESCRIPTION`: A brief description of the collection. This often appears in wallets and marketplaces where the collection is listed. The `const` value for a string needs to be in raw u8 bytes, so we convert it into a String with `string::utf8(COLLECTION_DESCRIPTION)`
* `maximum_supply`: The maximum number of NFTs the collection can have.
* `collection_name`: The name of the collection, also used as a unique identifier in combination with the creator. There are no two collections with the same name and creator.
* `collection_uri`: A external, off-chain link pointing to large amounts of data for wallets and marketplaces to use. Most commonly used as the main collection image.
* `MUTABLE_PROPERTY`: All of these fields that start with `MUTABLE_` are used to enable or disable the ability for the collection creator to change the corresponding values later. For example: `MUTABLE_COLLECTION_DESCRIPTION` means the 
* `TOKENS_BURNABLE_BY_CREATOR`: Whether or not the token can be burned by the creator.
* `TOKENS_FREEZABLE_BY_CREATOR`: Whether or not the token can be temporarily or permanently frozen by the creator, meaning that the owner cannot change; that is, it cannot be transferred.
* `royalty_numerator`: The numerator for the royalty percentage.
* `royalty_denominator`: The denominator for the royalty percentage.

:::info
A `royalty_numerator` and `royalty_denominator` of 5 and 100 respectively would mean the royalty percentage is 5% for any secondary sales of the NFT. Secondary sales are most commonly enforced by marketplaces. For example, if someone buys the NFT for 100 APT, a royalty percentage of 5% would mean 5 APT goes to the creator of the collection.
:::

### Writing a mint function

The last step is to actually mint the NFT. Let's break down our mint function:

```rust
public entry fun mint(
    creator: &signer,
    receiver_address: address
) acquires MintConfiguration {
  // ...
}
```

The first thing to notice is that the `mint` function itself requires the creator of the collection to sign the transaction
and a receiver address to send the minted NFT to.

Note that we aren't requiring the receiver to approve of being sent an NFT, which isn't ideal. But requiring two signers is even more
convoluted, so we'll change this in a later section.

<br/>

Token objects are created by generating a hash from the account's sequentially increasing GUID. We get the next GUID number before minting and then use it after minting to get the token object's address:
```rust
let token_creation_num = account::get_guid_next_creation_num(creator_addr);
```

<br/>

Here we're accessing the on-chain resources stored in the @mint_nft contract account, and then using them to pass to the mint function:

```rust
let mint_configuration = borrow_global<MintConfiguration>(@mint_nft);

aptos_token::mint(
    creator,
    mint_configuration.collection_name,
    string::utf8(TOKEN_DESCRIPTION),
    mint_configuration.token_name,
    mint_configuration.token_uri,
    vector<String> [ string::utf8(b"mint_timestamp") ],
    vector<String> [ string::utf8(b"u64") ],
    vector<vector<u8>> [ bcs::to_bytes(&timestamp::now_seconds()) ],
);
```

The last 3 parameters are used to create a property map. Respectively, they are the property key, type, and value for the token property map. We pass in a field called `mint_timestamp` of type `u64` to display how to use it. The inner vector values are BCS serialized bytes that map to a key's corresponding `value` for the `key: value` structure of the map. 

:::info
Property maps are unique polymorphic data structures that enable storing multiple data types into a mapped vector. You can read more about them in the `aptos-token-objects/property_map.move` contract.
:::

<br/>

We re-generate the object address with the GUID we generated earlier so we can transfer it to the receiver.

```rust
let token_object = object::address_to_object<AptosToken>(object::create_guid_object_address(creator_addr, token_creation_num));
object::transfer(creator, token_object, receiver_address);
```

### Publishing the module
First, let's initialize a `default` profile to use for our contracts.

```shell
aptos init --profile default
```

When prompted for the network, either leave it blank or write `devnet`. For the private key, you can hit enter on a blank entry to have the CLI create and fund a new account on devnet for you.

Navigate your terminal to the `aptos-core/aptos-move/move-examples/mint_nft/1-Create-Nft` folder and publish the module, specifying
to publish it with your `default` profile and then using its address as the `mint_nft` contract deployment address.

Devnet tokens are free, so we've included the `--assume-yes` flag that confirms you want to pay the gas fee for submitting the transaction.

```shell
aptos move publish --named-addresses mint_nft=default --profile default --assume-yes
```

The contract is now deployed to your `default` profile account on `devnet`!

In case you forget your default profile account address, you can use this command to view it:

```shell
aptos account lookup-address --profile default
```
This command returns something like:
```shell
{
  "Result": "DEFAULT_PROFILE_ACCOUNT_ADDRESS"
}
```

Create another profile to send the NFT to. We'll call it `nft-receiver`:

```shell
aptos init --profile nft-receiver
```

### Run the contract

To call a Move entry function, you need to provide:
1. The address it was published to
2. The module name
3. The function to call
4. The function parameters

In our case, our address is at the `DEFAULT_PROFILE_ACCOUNT_ADDRESS` we looked up earlier, the module name is `create_nft`, defined as such
at the top of the file where it says: `module mint_nft::create_nft`, and the function call is either `initialize_collection` or `mint`.

For the function parameters, you need to supply the function parameters in order with their corresponding types. See below for an example.

Move resources and functions are constructed by concatenating the module address, the module name, and the function or resource type with 2 colons
in between each one.

The globally addressable name of the function will look something like this:

```shell
0x5b9a0410a054bc63889759d2069096c31a7a941597d4a177cd7de5dee15790d8::create_nft::initialize_collection
```

Now let's call the `initialize_collection` function. Since we deployed the contract with the `default` profile, the CLI will let you substitute your profile name for an address.

```shell
aptos move run --function-id default::create_nft::initialize_collection   \
               --profile default                                          \
               --args                                                     \
                  string:"Choose your collection name here!"              \
                  string:"https://www.link-to-your-collection-image.com"  \
                  u64:3                                                   \
                  u64:5                                                   \
                  u64:100                                                 \
                  string:"Your Token #1"                                  \
                  string:"https://www.link-to-your-token-image.com"       
```

:::info
When you sign and submit a transaction with an account's private key, you automatically pass the first `&signer` parameter to the function.

Running an entry function with `--profile default` signs and submits the transaction for the `default` profile, which is why you don't need to provide the signer to the `--args` parameter list.
:::

Once you run that command and confirm that you'd like to submit the transaction, you've created your collection on-chain on the `devnet` network.

This means we can run the `mint` function now:

```shell
aptos move run --function-id default::create_nft::mint   \
               --profile default                         \
               --args address:nft-receiver 
```

Congratulations! You've created a collection, minted an NFT, and transferred the NFT to another account.

To view the events in this transaction, go to:

https://explorer.aptoslabs.com/txn/YOUR_TRANSACTION_HASH_HERE/events?network=devnet

But replace `YOUR_TRANSACTION_HASH_HERE` with the output of the transaction hash from the `aptos move run ...` command, or paste it into the explorer's search bar.

You should see a `0x4::collection::MintEvent` and a `0x1::object::TransferEvent`.

## 2. Automate the mint function with a resource account
