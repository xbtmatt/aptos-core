---
title: "Mint NFTs (v2) with the Aptos CLI"
---

# Mint NFTs (v2) with the Aptos CLI

This tutorial is intended to demonstrate how to programmatically mint NFTs on Aptos. The simplest version of a minting contract is the NFT collection creator manually minting and sending an NFT to a user.

We build upon this several times until we eventually create an automated NFT minting smart contract that has:
- A whitelist
- An end time
- An admin
- The ability for the admin to enable & disable the mint

## Prerequisites

This tutorial assumes you have:

* the [Aptos CLI](../../tools/install-cli/index.md) (or you can run from [aptos-core](https://github.com/aptos-labs/aptos-core) source via `cargo run`)
* the `aptos-core` repository checked out: `git clone https://github.com/aptos-labs/aptos-core.git`
* a basic understanding of Move, NFTs and NFT Collections

## 1. Creating a simple smart contract to mint an NFT

We're going to start by making the simplest form of the flow for creating a collection and minting a token and sending it to a user. The code for this part of the tutorial is in the first section of the `move-examples/mint_nft_v2_part1` folder in the aptos-core repository.

Here are the things we need to do first:

* Create the NFT collection and store the configuration options for it
* Mint a non-fungible token within that collection using the configuration options
* Send the minted token to a user account

### Defining the configuration options

The first thing we need to do is store the fields necessary to identify the collection and mint a token from it. We store these so we don't have to pass them in as fields to our mint function later.

```rust
struct MintConfiguration has key {
    collection_name: String,
    token_name: String,
    token_uri: String,
}
```

We give `MintConfiguration` the `key` ability so that the module contract can store it at an account's resources, which the module can programmatically retrieve later if we have the account address. The account address we store it to will be the creator of the collection, which is, in this section, the module publisher.

The rest of the fields necessary to call the mint function will be stored as `const` variables in the contract for simplicity. You could make these configurable on your own by adding them to the list of parameters sent into `initialize_collection` function below.

### Writing a collection creation function

First off, note the first couple lines of the `initialize_collection` function:

```rust
let creator_addr = signer::address_of(creator);
assert!(creator_addr == @mint_nft_v2_part1, error::permission_denied(ENOT_AUTHORIZED));
```
This gates the ability to run this function to the owner of the contract. This isn't necessary, but unless you specifically design a contract around
letting multiple accounts use it, it's simpler to only allow the account that deploys the contract to use it. This avoids a few potential vulnerabilities where you unintentionally allow an account to modify internal module resources for another account.

Later on in part 3 of this tutorial, we'll remove this restriction by utilizing an admin model for module resources.

:::note
We define `@mint_nft_v2_part1` when we deploy the module with the `--named-addresses mint_nft_v2_part1=<YOUR_ACCOUNT_ADDRESS>` flag.
:::

After that, we see the logic for our very basic initialize collection function. It creates a collection based off the parameters given in the
function arguments and then stores the minting config info to the creator's account resources with `move_to`.

```rust
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
```

Most of these fields are self-explanatory, but if you want to look at them in more detail, you can visit the [collection.move](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-token-objects/sources/collection.move) contract.

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
  let creator_addr = signer::address_of(creator);
  // ...
}
```

The first thing to notice is that the `mint` function itself requires the creator of the collection to sign the transaction
and a receiver address to send the minted NFT to.

Note that we aren't requiring the receiver to approve of being sent an NFT, which isn't ideal. But requiring two signers is even more
convoluted, so we'll change this in a later section.

Token objects are created by generating a hash from the account's sequentially increasing GUID. We get the next GUID number before minting and then use it after minting to get the token object's address:
```rust
let token_creation_num = account::get_guid_next_creation_num(creator_addr);
```
Here we're accessing the on-chain resources stored at `creator_addr`, and then using them to pass to the mint function:

```rust
let mint_configuration = borrow_global<MintConfiguration>(creator_addr);

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

:::tip Advanced Info
Property maps are unique polymorphic data structures that enable storing multiple data types into a mapped vector. You can read more about them in the [aptos-token-objects/property_map.move](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-token-objects/sources/property_map.move) contract.
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

Navigate your terminal to the `aptos-core/aptos-move/move-examples/mint_nft_v2_part1/1-Create-Nft` folder and publish the module, specifying
to publish it with your `default` profile and then using its address as the contract deployment address.

Devnet tokens are free, so we've included the `--assume-yes` flag that confirms you want to pay the gas fee for submitting the transaction.

```shell
aptos move publish --named-addresses mint_nft_v2_part1=default --profile default --assume-yes
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

### Running the contract

To call a Move entry function, you need to provide:
1. The address it was published to
2. The module name
3. The function to call
4. The function parameters

In our case, our address is at the `DEFAULT_PROFILE_ACCOUNT_ADDRESS` we looked up earlier, the module name is `create_nft`, defined as such
at the top of the file where it says: `module mint_nft_v2_part1::create_nft`, and the function call is either `initialize_collection` or `mint`.

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
                  string:"Krazy Kangaroos"                                \
                  string:"https://www.link-to-your-collection-image.com"  \
                  u64:3                                                   \
                  u64:5                                                   \
                  u64:100                                                 \
                  string:"Krazy Kangaroo #1"                              \
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

To view the events in this transaction, paste your transaction hash in the Aptos explorer search bar and navigate to the events section, or directly go to:

https://explorer.aptoslabs.com/txn/YOUR_TRANSACTION_HASH_HERE/events?network=devnet

You should see a `0x4::collection::MintEvent` and a `0x1::object::TransferEvent`.

## 2. Automating the mint function with a resource account

The issue with the code we've written so far is that it requires explicit approval from the creator to mint a token. The process isn't automated and the receiver doesn't ever approve of receiving the token.

The first step to improving the flow of this process is automating the creator's approval. We can do this with the use of what's called a resource account.

To achieve this, in this section we'll show you how to:

- Create the NFT collection with a resource account
- Store the capability to sign things with the resource account, a `SignerCapability`, into the owner's resources on-chain
- Automate minting the token to the user; that is, write a mint function that works without the collection creator's signature

### What is a resource account?

A resource account is essentially an account that another account can own. They are useful for separating and managing different types of resources, but they're also capable of delegating decisions to sign transactions to the logic in a smart contract.

If you want to approve a transaction for later, but don't want to have to be present to sign the transaction, you can write Move code to manage the conditional signature from a resource account to approve that transaction. You can view the resource account functionality in [account.move](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/account.move) and [resource_account.move](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/resource_account.move).

### Adding a resource account to our contract

Most of the code for our contract in this second part is very similar, so we're only going to discuss the parts added that make it different.

:::note
Please note that in this contract, the resource account will now technically be the `creator` of the collection, so for clarity we've changed the account representing the deployer (you) to be named `owner` and the account that creates the collection and mints tokens to remain `creator.`
:::

Let's start by adding the `SignerCapability` to our contract, which is the structure that produces the capability to sign a transaction programmatically.

We'll store it in our `MintConfiguration`:

```rust
struct MintConfiguration has key {
    signer_capability: SignerCapability,
    collection_name: String,
    token_name: String,
    token_uri: String,
}
```

We create it, providing it a seed in the form of the collection name.

```rust
let seed = *string::bytes(&collection_name);
let (resource_signer, resource_signer_cap) = account::create_resource_account(owner, seed);
```

:::info
The seed can be anything we want, but since resource accounts are unique hashes of the combination of the creating account + seed, it's good to make the seed something that will also be unique. In our case, the owner and collection name combination will always be unique because that is a constraint enforced by the `collection.move` contract, so the seed being the collection name logically follows.
:::

To clarify, the `resource_signer` is the actual structure on chain that signs things, it is of type `signer`; whereas the `SignerCapability` is a unique
on-chain resource that generates a signer for an account, given whomever requesting it has permission to access the `SignerCapability` resource.

Now we can provide the `resource_signer` as the creator of the collection, and move the `resource_signer_cap` to the `MintConfiguration`, so we can programmatically retrieve the creator's ability to sign later.

Note also that we store the `MintConfiguration` resource onto the resource account now, so when you call `create_collection` you'll have to look up the resource account's address to call the mint function later.

```rust
aptos_token::create_collection(
    &resource_signer,
    // ...
);

move_to(&resource_signer, MintConfiguration {
    signer_capability: resource_signer_cap,
    collection_name,
    token_name,
    token_uri,
});
```

Let's alter the mint function so that it uses the resource account instead of the owner account.

The first thing to notice is that the arguments to the function have changed. We no longer need the owner or the creator to sign the transaction. To do this before, we would've had to implement a function that takes two signers, which would've been complex. Not requiring the signer, however, meant the receiver had no say in whether or not they even wanted to receive the NFT.

Now, we can require the receiver to sign so that a user can mint whenever they like, and the owner doesn't have to approve of it beforehand.

```rust
public entry fun mint(receiver: &signer, resource_addr: address) acquires MintConfiguration {
    //...
}
```

Note that we require the user to pass in the resource address- we've provided a view function as one way for you to calculate it. We show you how to use this function later in the [Running the contract section](#running-the-contract-1).

```rust
#[view]
public fun get_resource_address(collection_name: String): address {
    account::create_resource_address(&@mint_nft_v2_part2, *string::bytes(&collection_name))
}
```

:::tip Advanced Tip
Computing the `resource_addr` inside the `mint` function with `account::create_resource_address(...)` has heavy computational overhead because it uses a cryptographic hashing function. In some instances where we only call the `mint` function a few times, this might be okay, but since a `mint` function is intended to be called by potentially thousands of users in a very short period of time, we ensure that it has been precomputed and have the user pass it in as an argument.
:::

Next, we access the mint configuration data to retrieve the signer capability. We generate a temporary signer with `account::create_signer_with_capability` and use it to sign the mint function and transfer the token object to the receiver.

```rust
public entry fun mint(receiver: &signer) acquires MintConfiguration {
    // access the configuration resources stored on-chain at @mint_nft_v2_part2's address
    let mint_configuration = borrow_global<MintConfiguration>(@mint_nft_v2_part2);
    let signer_cap = &mint_configuration.signer_capability;
    let resource_signer: &signer = &account::create_signer_with_capability(signer_cap);
    // ...
    // ... similar code as part 1
    // ... just replace `creator` and `creator_addr` with `resource_signer` and `resource_addr`
    // ...
}
```
:::warning
Be careful about how you generate and retrieve signers from a `SignerCapability` resource. It is, in essence, the keys to a resource account. If you purposely or inadvertently let any account access a `SignerCapability` freely, they can do almost anything they want with the resources in the associated account.

In our case, our code essentially makes the mint free, because there is no cost to mint and anyone can do it as many times as they like. This could be
intentional in some cases, but should be considered before hand. Always be highly aware of how you grant access to a resource account's signer capability.
:::

### Publishing the module and running the contract

Publishing the module is basically the same as before. Just make sure you're in the `2-Using-Resource-Account` directory and run this command, note the only thing that changed is the module name in the first line, `create_nft_with_resource_account` instead of `create_nft`:

```shell
aptos move publish --named-addresses mint_nft_v2_part2=default --profile default --assume-yes
```

Call this function as the owner of the contract, which is our `default` profile. Keep in mind the `--profile default` flag:

```shell
aptos move run --function-id default::create_nft_with_resource_account::initialize_collection   \
               --profile default                                          \
               --args                                                     \
                  string:"Krazy Kangaroos"                                \
                  string:"https://www.link-to-your-collection-image.com"  \
                  u64:3                                                   \
                  u64:5                                                   \
                  u64:100                                                 \
                  string:"Krazy Kangaroo #1"                              \
                  string:"https://www.link-to-your-token-image.com"       
```

Next we need to get the resource address for the contract with our view function.

```shell
aptos move view --function-id default::create_nft_with_resource_account::get_resource_address \
                --profile default \
                --args string:"Krazy Kangaroos"
```

Now we call this function as a user, which we simulate with our `nft-receiver` profile:

```shell
aptos move run --function-id default::create_nft_with_resource_account::mint \
               --profile nft-receiver \
               --args address:YOUR_RESOURCE_ADDRESS_HERE
```

Great! Now you've created the collection as an owner and requested to mint as a user and received the newly minted NFT.

It may not feel different since you're acting as the owner and the receiver all from the command line, but in an actual dapp this user flow makes much more sense than before.

In the first section, the user has to wait for the owner of the contract to mint and send them an NFT. In the second section, the user can request to mint and receive an NFT themselves.

## 3. Adding an end time, an admin, and an enabled flag

We're still missing some very common features for NFT minting contracts:

1. A start and end time
2. The ability to enable or disable the mint
3. An admin that can alter #1 and #2

To keep things simple, we're not going to set a start time, but we'll add the other functionality to the contract.

### Adding the new configuration options

We need to add the expiration timestamp, the enabled flag, and the admin address to the mint configuration resource:

```rust
struct MintConfiguration has key {
    // ...
    expiration_timestamp: u64,
    minting_enabled: bool,
    admin: address,
}
```

When we initialize the collection, we default to an expired timestamp that's one second in the past and disable the mint:

```rust
public entry fun initialize_collection( /* ... */ ) {
    // ...

    move_to(&resource_signer, MintConfiguration {
        // ...

        expiration_timestamp: timestamp::now_seconds() - 1,
        minting_enabled: false,
        admin: owner_addr,
    });
}
```

### Using assertions to enforce rules

We can utilize these fields to enforce restrictions on the mint function by aborting the call with an error message if either of the two conditions aren't met:

```rust
public entry fun mint(receiver: &signer, resource_addr: address) acquires MintConfiguration {
    // ...

    // throw an error if this function is called after the expiration_timestamp
    assert!(timestamp::now_seconds() < mint_configuration.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
    // throw an error if minting is disabled
    assert!(mint_configuration.minting_enabled, error::permission_denied(EMINTING_DISABLED));

    // ...
}
```

:::note
Function calls with failed assertions don't have side effects. When an error is thrown after a function alters a field with `borrow_global_mut`, none of the changes in the entire transaction occur. This includes any resource affected by nested and parent function calls.
:::

We also need a way to set all of these values, but we don't want to give just anyone the ability to freely set these fields. We can ensure that in our setter functions, the account requesting the change
is also the designated admin:

```rust
public entry fun set_minting_enabled(
    admin: &signer,
    minting_enabled: bool,
    resource_addr: address,
) acquires MintConfiguration {
    let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
    let admin_addr = signer::address_of(admin);
    // abort if the signer is not the admin
    assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
    mint_configuration.minting_enabled = minting_enabled;
}
```

The `set_expiration_timestamp` function is almost identical to `set_minting_enabled`, so we've left it out.

If we want to change the admin, we'll do something similar:

```rust
public entry fun set_admin(
    current_admin: &signer,
    new_admin_addr: address,
    resource_addr: address,
) acquires MintConfiguration {
    let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
    let current_admin_addr = signer::address_of(current_admin);
    // ensure the signer attempting to change the admin is the current admin
    assert!(current_admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
    // ensure the new admin address is an account that's been initialized so we don't accidentally lock ourselves out
    assert!(account::exists_at(new_admin_addr), error::not_found(ENOT_FOUND));
    mint_configuration.admin = new_admin_addr;
}
```
Note the extra error check to make sure the new admin account exists. If we don't check this, we could accidentally lock ourselves out by setting the admin to an account that doesn't exist yet.

### Publishing the module and running the contract

Navigate to the `3-Adding-Admin` directory and publish the module for part 3:

```shell
aptos move publish --named-addresses mint_nft_v2_part3=default --profile default --assume-yes
```

Initialize the collection:

```shell
aptos move run --function-id default::create_nft_with_resource_and_admin_accounts::initialize_collection   \
               --profile default                                          \
               --args                                                     \
                  string:"Krazy Kangaroos"                                \
                  string:"https://www.link-to-your-collection-image.com"  \
                  u64:3                                                   \
                  u64:5                                                   \
                  u64:100                                                 \
                  string:"Krazy Kangaroo #1"                              \
                  string:"https://www.link-to-your-token-image.com"       
```

Get the new resource address:

```shell
aptos move view --function-id default::create_nft_with_resource_and_admin_accounts::get_resource_address \
                --profile default \
                --args string:"Krazy Kangaroos"
```

Mint as `nft-receiver`:

```shell
aptos move run --function-id default::create_nft_with_resource_and_admin_accounts::mint \
               --profile nft-receiver \
               --args address:YOUR_RESOURCE_ADDRESS_HERE
```

We haven't set our expiration timestamp to be in the future yet, so you should get an error here:

```shell
"ECOLLECTION_EXPIRED(0x50002): The collection minting is expired"
```

Okay, let's try to set the timestamp. Here's an easy way to get a current timestamp in seconds:

```shell
aptos move view --function-id 0x1::timestamp::now_seconds
```

Add enough time to this so you can mint before the timestamp expires.

```shell
aptos move run --function-id default::create_nft_with_resource_and_admin_accounts::set_expiration_timestamp \
               --profile default                           \
               --args                                      \
                   u64:YOUR_TIMESTAMP_IN_SECONDS_HERE      \
                   address:YOUR_RESOURCE_ADDRESS_HERE   
```

If you try to mint again, you should get a different error this time:

```shell
"EMINTING_DISABLED(0x50003): The collection minting is disabled"
```

Enable the mint:

```shell
aptos move run --function-id default::create_nft_with_resource_and_admin_accounts::set_minting_enabled \
               --profile default                           \
               --args                                      \
                   bool:true                               \
                   address:YOUR_RESOURCE_ADDRESS_HERE   
```

Try to mint again, and it should succeed! You can try setting the admin with the `set_admin(...)` call and then set the `expiration_timestamp` and `minting_enabled` fields on your own. Use the correct and incorrect admin to see how it works.

## 4. Adding a customizable whitelist, custom events, and unit tests

We've set restrictions for *when* a user can mint, but we have no rules regarding how many times or which users can mint. This is the purpose of a whitelist- only allowing certain accounts to mint, often with a restriction on how many times. We also want to add custom events so that when a user mints, an event is emitted on-chain that describes details about the mint transaction.

1. Add a whitelist that restricts minting to whitelisted addresses
2. Add the ability to add/remove addresses from the whitelist
3. Emit a custom event when a user mints
4. Explore and discuss the implications of using different data structures
### Adding a whitelist

The functionality of a whitelist is very simple: we abort if the address doesn't exist in the list. 

Let's explore the different data structures we could use for this:

1. You might be tempted to use a `vector<address>` for this, but the lookup time of a vector gets prohibitively expensive when the size of the list starts growing into the thousands.
2. A Table offers very efficient lookup times, so we could use `Table<address, bool>` for our whitelist. The `bool` would be a useless field, though, because we'd just be using the `table::contains(...)` function to check that an address exists as a key in the table.
3. An Object offers us a similar efficient lookup time as a Table, but also allows us to emit minting events from the Object, rather than a single resource. This frees up a bottleneck that would disallow parallelization on the function call. 

Let's use an Object called `MintTicket` to allow the user to "get in" to the mint function. First let's define the data that will go into the object:

```rust
#[resource_group_member(group = aptos_framework::object::ObjectGroup)]
struct MintTicket has key {
    mint_events: event::EventHandle<MintEvent>,
    extend_ref: ExtendRef,
}

struct MintEvent has drop, store {
    collection: String,
    creator: address,
    name: String,
    receiver: address,
}
```

Let's write our add/remove from whitelist functionality:

```rust
public entry fun add_to_whitelist(admin: &signer, addresses: vector<address>, resource_addr: address) {
    assert!(is_admin(admin, resource_addr), error::permission_denied(ENOT_AUTHORIZED));
    let resource_signer = &account::create_signer_with_capability(&borrow_global<MintConfiguration>.signer_capability);

    vector::for_each(addresses, |user_addr|) {
        // create a seed from the BCS serialized user address
        let seed = bcs::to_bytes(&user_addr);
        // generate the object address to check if it already exists
        let object_addr = object::create_object_address(&resource_addr, seed);
        if (!object::exists_at<MintTicket>(object_addr)) {
            // create the object with our seed (user_address + b"MintTicket")
            let constructor_ref = object::create_named_object(resource_signer, seed);
            let object_signer = object::generate_signer(&constructor_ref);
            move_to(
                &object_signer,
                MintTicket {
                    mint_events: object::new_event_handle(&object_signer),
                    extend_ref: object::generate_extend_ref(&constructor_ref),
                }
            );
        };
    };
}
```



# can you run the inline function of an Object/Module hybrid?

# don't let admin change whitelist while mint is enabled!



// calculate resource address off chain
// send it in with minter as signer
// verify address_of(minter: &signer) is the owner of the Object

:::tip Choosing the right data structure 
This means we're going to want a data structure that has an efficient lookup time when there's a large set of entries
:::

### Adding and removing addresses from the whitelist

### Emitting custom events

