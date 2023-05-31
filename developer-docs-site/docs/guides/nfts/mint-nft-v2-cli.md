---
title: "Mint NFTs (v2) with the Aptos CLI"
---

# Mint NFTs (v2) with the Aptos CLI

This tutorial is intended to demonstrate how to programmatically mint NFTs on Aptos.

The simplest version of a minting contract is the NFT collection creator manually minting and sending an NFT to a user, so we'll start with that and iterate on it several times until we eventually create an automated NFT minting smart contract that has:
- A mint function that automates minting a token and sending it to a receiver account
- A whitelist
- A price the receiver has to pay to mint
- A start time
- An end time
- An admin
- The ability for the admin to enable & disable the mint
- Token names that auto-increment
- The ability to store token metadata for each token that's attached to a token upon mint

## Prerequisites

This tutorial assumes you have:

* the [Aptos CLI](../../tools/install-cli/index.md) (or you can run from [aptos-core](https://github.com/aptos-labs/aptos-core) source via `cargo run`)
* the `aptos-core` repository checked out: `git clone https://github.com/aptos-labs/aptos-core.git`
* a basic understanding of Move, NFTs and NFT Collections

Note that the terms "NFT" and "Token" are used interchangeably here. Tokens can be fungible, but we may refer to them as just "Tokens" and imply that they're non-fungible.

## 1. Creating a simple smart contract to mint an NFT

We're going to start by making the simplest form of the flow for creating a collection and minting a token and sending it to a user. The code for this part of the tutorial is in the first section of the `move-examples/mint_nft_v2_part1` folder in the aptos-core repository.

Here are the things we need to do first:

* Create the NFT collection and store the configuration options for it
* Mint an NFT within that collection using the configuration options
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

For simplicity, we'll make hard-coded `const` variables to store default data for the rest of the fields necessary to call the mint function. You could make these configurable on your own by adding them to the list of parameters sent into `initialize_collection` function below.

### Writing a collection creation function

First off, note the first couple lines of the `initialize_collection` function:

This gates the ability to run this function to the owner of the contract. This isn't necessary, but unless you specifically design a contract around
letting multiple accounts use it, it's simpler to only allow the account that deploys the contract to use it. This avoids a few potential vulnerabilities where you unintentionally allow an account to modify internal module resources for another account.

```rust
let creator_addr = signer::address_of(creator);
assert!(creator_addr == @mint_nft_v2_part1, error::permission_denied(ENOT_AUTHORIZED));
```

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

The first thing to notice is that the `mint` function itself requires the creator of the collection to sign the transaction
and a receiver address to send the minted NFT to.

```rust
public entry fun mint(
    creator: &signer,
    receiver_address: address
) acquires MintConfiguration {
  let creator_addr = signer::address_of(creator);
  // ...
}
```

So there's a few issues with this function that we'll improve later:
1. the creator has to sign, so you'd need to process off-chain asynchronous requests from a user to approve of a mint.
2. the receiver doesn't have to sign. We do this for educational purposes, because requiring two signers is beyond the scope of this tutorial, and we haven't automated it so the creator doesn't have to sign yet

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

The last 3 parameters are used to create a property map. Respectively, they are the property key, type, and value for the token property map. We pass in a field called `mint_timestamp` for the key name, `u64` to specify its type, and the last field is a BCS serialized byte vector that maps to a key's corresponding `value` for the `key: value` structure of the map.

You could think of the property map as a map with one key. In pseudocode: `property_map['mint_timestamp']: u64 = now_seconds()`

:::tip Advanced Info
Property maps are unique polymorphic data structures that enable storing multiple data types into a mapped vector. You can read more about them in the [aptos-token-objects/property_map.move](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-token-objects/sources/property_map.move) contract.
:::

<br/>

We generate the object address with the GUID we generated earlier so we can transfer it to the receiver.

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

Navigate your terminal to the `aptos-core/aptos-move/move-examples/mint_nft_v2_part1/1-Create-NFT` folder and publish the module, specifying
to publish it with your `default` profile and then using its address as the contract deployment address.

```shell
aptos move publish --named-addresses mint_nft_v2_part1=default --profile default
```

The contract is now deployed to your `default` profile account on `devnet`! In case you forget your default profile account address, you can use this command to view it:

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

Since we deployed the contract with the `default` profile, the CLI will let you substitute your profile name for an address.
 
Now let's call the `initialize_collection` function.

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

There's two issues with the code we've written so far that we'll fix in part 2:

1. The contract requires explicit approval from the creator to mint a token. Thus, the process isn't automated and in addition to that, the receiver doesn't necessarily ever approve of receiving the token.
2. We don't have any way to mint multiple tokens, because the name doesn't change from the first mint to the second, meaning the unique token ids will clash and it'll fail.

To resolve these issues, in this section we'll show you how to:

- Create the NFT collection with a resource account
- Store the capability to sign things with the resource account, a `SignerCapability`, into the contract's resources on-chain
- Automate minting the token to the user; that is, write a mint function that works without the collection creator's signature
- Automatically increment the token name based on the collection supply: `Krazy Kangaroo #1, Krazy Kangaroo #2, Krazy Kangaroo #3` etc

### What is a resource account?

A resource account is an account that's used to store and manage resources. Upon creation, a resource account is designated an auth key for a different account. This auth key specifies which account can manage its resources. If you make a resource account and don't specify an auth key directly, the account you use to create it will be used as the designated auth key, meaning it has the ability to manage the resource account's resources.

There is also a unique function you can call to rotate the auth key to `0x0`, giving the Move runtime engine the ability to generate the resource account's signer with a `SignerCapability` resource.

You can create a resource account in a move contract by specifying a seed and calling it with the owning account's signer. The resulting resource account address is derived from a SHA3-256 hash of the owner's account + the seed.

To actually store this SignerCapability and use it later, the process typically looks something like this:

```rust
// define a resource we can store the SignerCapability in in our contract:
struct MySignerCapability has key {
    resource_signer_cap: SignerCapability,
}

public entry fun store_signer_capability(creator: &signer) {
    // We can store `MySignerCapability` to an account, because it has the ability `key`. We can even store it on the resource account itself:
    let (resource_signer, resource_signer_cap) = account::create_resource_account(creator, b"seed bytes");
    move_to(resource_signer, MySignerCapability {
        resource_signer_cap,
    });
}

public entry fun sign_with_resource_account(creator: &signer) acquires MySignerCapability {
    let resource_address = account::create_resource_address(signer::address_of(creator), b"seed bytes");
    let signer_cap = borrow_global<MySignerCapability>(resource_account_address);
    let resource_signer = account::create_signer_with_capability(signer_cap);

    // here we'd do something with the resource_signer that we can only do with its `signer`, like call the mint function!
}
```
Utilizing a resource account in this way is the fundamental process for automating the generation and retrieval of resources on-chain.

You might be wondering "*Why does this work? Isn't it dangerous to be able to create a signer for an account so easily?*"

Yes, you need to make sure you're gating access to the `SignerCapability`, but it's designed in such a way that if you have access to it, you either created it, or you were given it by someone who very intentionally gave it to you.

```rust
struct SignerCapability has drop, store {
    account: address
}
```

:::tip
To intuitively understand why a `SignerCapability` is allowed to be so powerful, you need to consider how resource storage and control work in Move. You can't directly access, create, or modify a resource outside of the module it's defined in, meaning if you have access to a resource in some way, the creator of the module it belongs to explicitly gave it to you.

The `account` address contained within specifies the address the `SignerCapability` can generate a signer for. As defined in `account.move`, there is no way to change this field once it's set upon creation, so the owner of a `SignerCapability` can never change which resource account it controls. There is no `copy` ability on the struct, either, meaning there can only be a single `SignerCapability` in existence for each resource account.

Upon creating the `SignerCapability`, you're free to decide how you want to expose it. You can store it somewhere, give it away, or gate its access to functions that use it or conditionally return it.
:::

You can view the resource account functionality in more detail at [account.move](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/account.move) and [resource_account.move](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/resource_account.move).

### Adding a resource account to our contract

We need to create a resource account and use it to automate the minting function. We can create the collection with the resource account upon initialization, store its `SignerCapability` and then, when a user requests to mint later on, we retrieve it and use it to generate the signer for the `mint(creator: &signer, ...)` function. 

This is what facilitates the autonomous nature of the contract- since the creator is now the resource account, we can program it to conditionally approve of a request to mint!

Most of the code for our contract in this second part is very similar, so we're only going to discuss the parts added that make it different.

:::note
Note that in this new contract, the resource account will now technically be the `creator` of the collection, so for clarity we've changed the account representing the deployer (you) to be named `owner` and the account that creates the collection and mints tokens to remain `creator.`
:::

Let's start by adding the `SignerCapability` to our contract. We'll store it in our `MintConfiguration`. We've also changed the `token_name` field to `base_token_name` so we can auto-increment the name with a base, such as `Krazy Kangaroo`, as opposed to the full `Krazy Kangaroo #1`:

```rust
struct MintConfiguration has key {
    signer_capability: SignerCapability,
    collection_name: String,
    base_token_name: String,
    token_uri: String,
}
```

There is a CLI command `aptos move publish create-resource-account-and-publish-package` that we're going to use to publish our code to a resource account. When you call this command, it doesn't call `create_resource_account`. It calls a slightly different function under the hood:

```rust
account::create_resource_account_and_publish_package(
    origin: &signer,
    seed: vector<u8>,
    metadata_serialized: vector<u8>,
    code: vector<vector<u8>>,
);
```

This creates a resource account and publishes the module to that resource account's address.

:::warning
If you do not add a function to retrieve the resource signer to your contract the *first* time you publish it, it will inadvertently be an immutable contract. You will never be able to change it, because there is no way to acquire the SignerCapability stored inside the module and use it freely, which is the only way you can update the contract since the resource signer is the owner.
:::

The only way to retrieve the signer cap down the road is if we store it upon initialization, so we need to use a unique module function called `init_module(resource_signer: &signer) { ... }` that is only run upon the first publication of the module. The `resource_signer` is the signer for the resource account passed into the function. We can use it to store the `MintConfiguration` resource at the resource address upon initialization:

```rust
fun init_module(resource_signer: &signer) {
    let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @owner);
    move_to(resource_signer, MintConfiguration {
        signer_capability: resource_signer_cap,
        collection_name: string::utf8(b""),
        base_token_name: string::utf8(b""),
        token_uri: string::utf8(b""),
    });
}
```

Note that `@owner` is specified later, it's going to be our `default` profile account address. We also leave the other fields as empty strings, because we're only using it to store the signer capability upon the module initialization.

:::info
To reiterate, a `signer` is the representation of an account's signature on chain. It represents the permission to manage an account's resources and sign things. A `SignerCapability` is a resource used to generate a `signer` for the resource account located at the address in its `account` field.
:::

Now we can provide the `resource_signer` as the creator of the collection, and move the `resource_signer_cap` to the `MintConfiguration`, so we can programmatically retrieve the creator's ability to sign later.

```rust
public entry fun initialize_collection(...) {
    // ...
    aptos_token::create_collection(
        &resource_signer,
        // ...
    );

    let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part2);
    mint_configuration.collection_name = collection_name;
    mint_configuration.base_token_name = base_token_name;
    mint_configuration.token_uri = token_uri;
}
```
Let's alter the mint function so that it uses the resource account instead of the owner account.

The first thing to notice is that the arguments to the function have changed. We no longer need the owner or the creator to sign the transaction. To do this before, we would've had to implement a function that takes two signers, which would've been complex. Not requiring the signer, however, meant the receiver had no say in whether or not they even wanted to receive the NFT.

Now, we don't need the owner to sign because the the resource account will do it within the `mint` function. This means we can enforce that the receiver signs a request to mint, but still only use one signer.

```rust
public entry fun mint(receiver: &signer) acquires MintConfiguration {
    //...
}
```

Next, we access the mint configuration data to retrieve the signer capability. We generate a temporary signer with `account::create_signer_with_capability` and use it to sign the mint function and transfer the token object to the receiver.

```rust
public entry fun mint(receiver: &signer) acquires MintConfiguration {
    // access the configuration resources stored on-chain at @mint_nft_v2_part2's address
    let mint_configuration = borrow_global<MintConfiguration>(@mint_nft_v2_part2);
    let signer_cap = &mint_configuration.signer_capability;
    let resource_signer: &signer = &account::create_signer_with_capability(signer_cap);
    // ...
    let token_name = next_token_name_from_supply(
        resource_signer,
        mint_configuration.base_token_name,
        mint_configuration.collection_name,
    );

    // ...
    // ... similar code as part 1
    // ... just replace `creator` and `creator_addr` with `resource_signer` and `resource_addr`, respectively
    // ...
}
```

Let's look at the code for how the `token_name` is generated to understand how we're auto-incrementing the name:

```rust
/// generates the next token name by concatenating the supply onto the base token name
fun next_token_name_from_supply(
    creator: &signer,
    base_token_name: String,
    collection_name: String,
): String {
    let collection_addr = collection::create_collection_address(&signer::address_of(creator), &collection_name);
    let collection_object = object::address_to_object<Collection>(collection_addr);
    let current_supply = option::borrow(&collection::count(collection_object));
    let format_string = base_token_name;
    // if base_token_name == Token Name
    string::append_utf8(&mut format_string, b" #{}");
    // 'Token Name #1' when supply == 0
    string_utils::format1(string::bytes(&format_string), *current_supply + 1)
}
```

It's quite simple what we're doing- we've made an internal function that queries from `collection.move` the collection's supply. It's an `option` value, so we `borrow` the element inside, dereference it, and then add 1 to it to get the collection's current supply + 1.

We append a ` #` to the token base name, and then use the `string_utils` contract to format a string with interpolation similar to how you would in most other languages. Post append, it'd look like this:

```rust
string_utils::format1("Krazy Kangaroo #{}", *current_supply + 1)
```

We return this value and call it in our mint function to set our token name!


### Publishing the module and running the contract

Publishing the module is basically the same as before. Just make sure you're in the `2-Using-Resource-Account` directory and run this command, note the only thing that changed is the module name in the first line, `create_nft_with_resource_account` instead of `create_nft`:

```shell
aptos move publish --named-addresses mint_nft_v2_part2=default --profile default
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

## 3. Adding restrictions: a whitelist, an end time, an admin, and an enabled flag

We're still missing some very common features for NFT minting contracts:

1. A whitelist that restricts minting to whitelisted addresses
2. The ability to add/remove addresses from the whitelist
3. An end time
4. The ability to enable or disable the mint
5. An admin model: restricting using these functions to an assigned admin account

### Adding the new configuration options

We need to add the expiration timestamp, the enabled flag, and the admin address to the mint configuration resource:

```rust
struct MintConfiguration has key {
    // ...
    whitelist: Table<address, bool>,
    expiration_timestamp: u64,
    minting_enabled: bool,
    admin: address,
}
```

Note that we're storing a `bool` in the whitelist as the value in each key: value pair. We won't use it in this tutorial, but you could easily use it to limit each account to 1 mint or even use an integer type to limit it to an arbitrary number of mints.  

When we initialize the collection, we create a default empty whitelist, an expiration timestamp that's one second in the past, and disable the mint:

```rust
public entry fun initialize_collection( /* ... */ ) {
    // ...

    move_to(&resource_signer, MintConfiguration {
        // ...
        whitelist: table::new<address, bool>(),
        expiration_timestamp: timestamp::now_seconds() - 1,
        minting_enabled: false,
        admin: owner_addr,
    });
}
```

### Using assertions to enforce rules

We can utilize these fields to enforce restrictions on the mint function by aborting the call with an error message if any of the conditions aren't met:

```rust
public entry fun mint(receiver: &signer, resource_addr: address) acquires MintConfiguration {
    // ...

    // abort if user is not in whitelist
    assert!(table::contains(&mint_configuration.whitelist, receiver_addr), ENOT_IN_WHITELIST);
    // abort if this function is called after the expiration_timestamp
    assert!(timestamp::now_seconds() < mint_configuration.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
    // abort if minting is disabled
    assert!(mint_configuration.minting_enabled, error::permission_denied(EMINTING_DISABLED));

    // ...
}
```

:::note
Function calls with failed assertions don't have side effects. When an error is thrown after a function alters a field with `borrow_global_mut`, none of the changes in the entire transaction occur. This includes any resource affected by nested and parent function calls.
:::

We also need a way to set all of these values, but we don't want to give just anyone the ability to freely set these fields. We can ensure that in our setter functions, the account requesting the change
is also the designated admin:

### Enabling the mint and setting the expiration time

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

### Setting the admin of the module

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

### Adding to the whitelist

Now let's add our add_to_whitelist and remove_from_whitelist functions. They're very similar, so we'll just show the former:

```rust
public entry fun add_to_whitelist(
    admin: &signer,
    addresses: vector<address>,
    resource_addr: address
) acquires MintConfiguration {
    let admin_addr = signer::address_of(admin);
    let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
    assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));

    vector::for_each(addresses, |user_addr| {
        // note that this will abort in `table` if the address exists already- use `upsert` to ignore this
        table::add(&mut mint_configuration.whitelist, user_addr, true);
    });
}
```

Most of this is fairly straightforward, although note the new inline function we use with `for_each`. This is a functional programming construct Aptos Move offers that lets us run an inline function over each element in a vector. `user_addr` is the locally named element that's passed into the `for_each` function block.

:::tip Why do we use a table instead of a vector for the whitelist?
You might be tempted to use a `vector<address>` for this, but the lookup time of a vector gets prohibitively expensive when the size of the list starts growing into the thousands.

A Table offers very efficient lookup times. Since it's a hashing function, it's an O(1) lookup time. A vector is O(n). When it comes to thousands of calls on-chain, that can make a substantial difference in execution cost and time.
:::


### Publishing the module and running the contract

Navigate to the `3-Adding-Admin-and-Whitelist` directory and publish the module for part 3:

```shell
aptos move publish --named-addresses mint_nft_v2_part3=default --profile default
```

Initialize the collection:

```shell
aptos move run --function-id default::adding_admin_and_whitelist::initialize_collection   \
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
aptos move view --function-id default::adding_admin_and_whitelist::get_resource_address \
                --profile default \
                --args string:"Krazy Kangaroos"
```

Mint as `nft-receiver`:

```shell
aptos move run --function-id default::adding_admin_and_whitelist::mint \
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
aptos move run --function-id default::adding_admin_and_whitelist::set_expiration_timestamp \
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
aptos move run --function-id default::adding_admin_and_whitelist::set_minting_enabled \
               --profile default                           \
               --args                                      \
                   bool:true                               \
                   address:YOUR_RESOURCE_ADDRESS_HERE   
```

Last error we'll get is the user not being on the whitelist:

```shell
"ENOT_IN_WHITELIST(0x5): The user account is not in the whitelist"
```

Add the user to the whitelist:

```shell
aptos move run --function-id default::adding_admin_and_whitelist::add_to_whitelist \
               --profile default                           \
               --args                                      \
                   "vector<address>:nft-receiver"          \
                   address:YOUR_RESOURCE_ADDRESS_HERE
```

Try to mint again, and it should succeed! You can try setting the admin with the `set_admin(...)` call and then set the `whitelist`, `expiration_timestamp` and `minting_enabled` fields on your own. Use the correct and incorrect admin to see how it works.


## 4. Adding a public phase, custom events, and unit tests

We've got most of the basics down, but there are some additions we can still make to round out the contract:

1. Add a start time
2. Add a public phase after the whitelist phase where accounts not on the whitelist are allowed to mint
3. Add a `TokenMintingEvent` that we emit whenever a user calls the `mint` function successfully
4. Write Move unit tests to more efficiently test our code

### Adding a public phase

The simplest way to set a public phase is to add a start timestamp for both the public and whitelist minters. 

```rust
struct MintConfiguration has key {
    // ...
    start_timestamp_public: u64,
    start_timestamp_whitelist: u64,
}

const U64_MAX: u64 = 18446744073709551615;

public entry fun initialize_collection( ... ) {
    // ...
    move_to(&resource_signer, MintConfiguration {
        // ...
        // default to an impossibly distant future time to force owner to set this
        start_timestamp_whitelist: U64_MAX,
        start_timestamp_public: U64_MAX,
        // ...
    });
}
```

Then we enforce those restrictions in the mint function again.

We add an abort for trying to mint before the whitelist time, then check to see if the user is even on the whitelist. If they aren't, we abort if the public time hasn't come yet.

If the user is whitelisted and the whitelist time has begun or the public minting has begun, we finish our checks for `expiration_timestamp` and `minting_enabled`.

```rust
public entry fun mint(receiver: &signer, resource_addr: address) acquires MintConfiguration {
    // ...

    assert!(timestamp::now_seconds() >= mint_configuration.start_timestamp_whitelist, EWHITELIST_MINT_NOT_STARTED);
    // we are at least past the whitelist start. Now check for if the user is in the whitelist
    if (!table::contains(&mint_configuration.whitelist, signer::address_of(receiver))) {
        // user address is not in the whitelist, assert public minting has begun
        assert!(timestamp::now_seconds() >= mint_configuration.start_timestamp_public, EPUBLIC_MINT_NOT_STARTED);
    };

    // abort if this function is called after the expiration_timestamp
    assert!(timestamp::now_seconds() < mint_configuration.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
    // abort if minting is disabled
    assert!(mint_configuration.minting_enabled, error::permission_denied(EMINTING_DISABLED));

    // ...
}
```

Note that we haven't had a start time- we've been using the `minting_enabled` variable to gate access, but it's better design to have `minting_enabled` as a hard on/off switch for the contract and an actual start time for public and whitelist mints.

Our setter functions are nearly identical to `set_expiration_timestamp` just with a few additional checks to ensure our times make sense with each other:

```rust
public entry fun set_start_timestamp_public(
    admin: &signer,
    start_timestamp_public: u64,
    resource_addr: address,
) acquires MintConfiguration {
    // ...
    assert!(mint_configuration.start_timestamp_whitelist <= start_timestamp_public, EPUBLIC_NOT_AFTER_WHITELIST);
    // ...
}
public entry fun set_start_timestamp_whitelist(
    admin: &signer,
    start_timestamp_whitelist: u64,
    resource_addr: address,
) acquires MintConfiguration {
    // ...
    assert!(mint_configuration.start_timestamp_public >= start_timestamp_whitelist, EPUBLIC_NOT_AFTER_WHITELIST);
    // ...
}
```

### Adding custom events

In order to use events, we need to create a data structure that will be used to fill out the event data when it's emitted.

```rust
struct TokenMintingEvent has drop, store {
    token_receiver_address: address,
    creator: address,
    collection_name: String,
    token_name: String,
}
```

```rust
We need to create an EventHandle so we have somewhere to emit the events from: 
struct MintConfiguration has key {
    // ...
    token_minting_events: EventHandle<TokenMintingEvent>,
}
```

:::warning
Emitting events to the same resource is a bottleneck in this contract for parallelization. Check out our tutorials on how to parallelize contracts to remove this bottleneck.
:::

Initialize the `EventHandle` in the `initialize_collection` function and add the event emission function in `mint`:

```rust
public entry fun initialize_collection(...) {
    // ...

    move_to(&resource_signer, MintConfiguration {
        // ...
        token_minting_events: account::new_event_handle<TokenMintingEvent>(&resource_signer);
    });
}

public entry fun mint(receiver: &signer, resource_addr: address) acquires MintConfiguration {
    // ...

    event::emit_event<TokenMintingEvent>(
        &mut mint_configuration.token_minting_events,
        TokenMintingEvent {
            token_receiver_address: receiver_addr,
            creator: resource_addr,
            collection_name: mint_configuration.collection_name,
            token_name: mint_configuration.token_name,
        }
    );
}
```

Now whenever a user mints, a `TokenMintingEvent` will be emitted. You can view the events in a transaction on the Aptos explorer by looking up the transaction and viewing the Events section. Here are the events of the first transaction ever as an example: https://explorer.aptoslabs.com/txn/1/events?network=mainnet

Read more about events [here](https://aptos.dev/concepts/events/).

### Adding unit tests

So far, we've been making sure our code works by running it and checking if we get error codes as expected. This is a messy and inconsistent way of testing our code. It relies upon us not making any mistakes when running the commands in a specific order and that we run these checks every time we add new functionality.

We can leverage Move's native unit testing to create basic checks for our code that ensure our contract is working as expected. Read more about unit testing in Move [here](https://aptos.dev/move/move-on-aptos/cli/#compiling-and-unit-testing-move).

We'll make a simple list of every condition we've added to the contract, implicit or explicit, and ensure that when these conditions are met things go as expected and when they are not met, we get the error we expect.

Let's start with expected errors and when we'd expect to see them. We'll run a unit test for each of these error codes:

```rust
/// Action not authorized because the signer is not the admin of this module
const ENOT_AUTHORIZED: u64 = 1;
/// The collection minting is expired
const ECOLLECTION_EXPIRED: u64 = 2;
/// The collection minting is disabled
const EMINTING_DISABLED: u64 = 3;
/// The requested admin account does not exist
const ENOT_FOUND: u64 = 4;
/// The user account is not in the whitelist
const ENOT_IN_WHITELIST: u64 = 5;
/// Whitelist minting hasn't begun yet
const EWHITELIST_MINT_NOT_STARTED: u64 = 6;
/// Public minting hasn't begun yet
const EPUBLIC_MINT_NOT_STARTED: u64 = 7;
/// The public time must be after the whitelist time
const EPUBLIC_NOT_AFTER_WHITELIST: u64 = 8;
```

We also need to test that on-chain resources are changed accordingly if everything goes as expected. We'll refer to these as our positive testing conditions.

# Positive Test Conditions

1. When the collection is initialized, all on-chain resources are initialized in the resource account.
2. When the admin is changed, the next admin can successfully call admin-only functions.
3. When any functions that mutate resources are called, the resource on-chain is updated accordingly.
4. When a user mints successfully, they actually receive the NFT.

:::info
Running a basic test where everything goes right is called `happy path testing` in testing terminology. It's the most basic way of ensuring that running a program with no errors runs exactly as intended.
:::

When you're running a unit test with the Aptos Move CLI, the testing environment creates a sort of microcosm where your machine is initializing the entire blockchain and running it for a few seconds in order to simulate your unit tests.

This means that there are no accounts initialized anywhere, the time on-chain hasn't been set, and that you need to set all these things up when you begin your tests. We'll write a helper function that we call in each of our unit tests that initializes our testing environment.

Note that when you see `#[test_only]` above a function, it means the function is a function that can only be called in the test environment. `#[test]` marks a function as a unit test.

```rust
// dependencies only used in test, if we link without #[test_only], the compiler will warn us
#[test_only]
use aptos_std::token_objects::collection::{Self, Collection};
#[test_only]
use aptos_std::token_objects::aptos_token::{Self};
// ...etc


#[test_only]
fun setup_test(
    owner: &signer,
    new_admin: &signer,
    nft_receiver: &signer,
    nft_receiver2: &signer,
    aptos_framework: &signer,
    timestamp: u64,
) acquires MintConfiguration {
    timestamp::set_time_has_started_for_testing(aptos_framework);
    timestamp::update_global_time_for_test_secs(timestamp);
    account::create_account_for_test(signer::address_of(owner));
    account::create_account_for_test(signer::address_of(nft_receiver));
    account::create_account_for_test(signer::address_of(nft_receiver2));
    account::create_account_for_test(signer::address_of(aptos_framework));
    account::create_account_for_test(signer::address_of(new_admin));
    initialize_collection(
        owner,
        get_collection_name(),
        get_collection_uri(),
        MAXIMUM_SUPPLY,
        ROYALTY_NUMERATOR,
        ROYALTY_DENOMINATOR,
        get_token_name(),
        get_token_uri(),
    );
}

// Helper functions for the default values we've been using.
// We use these to avoid `utf8` casts, since we can't set `String` type const variables.
#[test_only]
const COLLECTION_NAME: vector<u8> = b"Krazy Kangaroos";
#[test_only]
public fun get_collection_name(): String { string::utf8(COLLECTION_NAME) }
// ...etc
```
We initialize the time on-chain, set it to `timestamp`, and then create accounts for all of our test accounts. Then we initialize the collection, since it's used in all of our test functions.

Now let's write our happy path. This tests that all the expected functionality is working as intended in a scenario where nothing goes wrong.

We'll write checks for our list #1-#4 above at the end of the test.

In a `#[test]` function, we can specify accounts we want to name, set their address, and pass them in as signers to the function as if they had signed the transaction. For all of our tests, we're going to use the same addresses for simplicity's sake.

Now let's pass them in as signers and set up our happy path test:

```rust

```

For the sake of brevity, we'll only explain a single example of a negative test condition here. We'll test that setting a new admin results in the old admin being unable to call admin-only functions:

```rust

```

:::tip
Calling the `error` module to emit a specific error function is useful in that it will print out the triple slash comment above the error code when you define it in your module. The error code can be derived by adding the error code value in `error.move` to the `const` value you set it to in your module.

That is, since we call `error::permission_denied(ENOT_AUTHORIZED)` we can derive the error code by knowing that `PERMISSION_DENIED` in `error.move` is `0x5`, and our `ENOT_AUTHORIZED` is `0x1`, so the error code will be `0x50001`.
:::


```shell
aptos move run --function-id default::create_nft_with_public_phase_and_events::set_expiration_timestamp \
               --profile default                           \
               --args                                      \
                   u64:YOUR_TIMESTAMP_IN_SECONDS_HERE      \
                   address:YOUR_RESOURCE_ADDRESS_HERE   
```

```shell
aptos move publish --named-addresses mint_nft_v2_part1=default --profile default
```