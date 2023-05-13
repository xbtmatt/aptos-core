---
title: "Mint NFTs (v2) with the Aptos CLI"
---

# Mint NFTs (v2) with the Aptos CLI

This tutorial is intended to demonstrate how to programmatically mint NFTs on Aptos. It builds upon the simplest version of an NFT Collection creator manually minting an NFT to a receiver's account to eventually creating a more complex smart contract that facilitates users requesting an NFT and receiving it without ever having to get explicit signer approval from the Collection creator.

## Prerequisites

This tutorial assumes you have:

* the [Aptos CLI](../../tools/install-cli/index.md) (or you can run from [aptos-core](https://github.com/aptos-labs/aptos-core) source via `cargo run`)
* the `aptos-core` repository checked out: `git clone https://github.com/aptos-labs/aptos-core.git`
* a general understanding of NFTs and NFT Collections
* an understanding of [the Token V2 standard](https://aptos.dev/guides/nfts/token-v2)

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

:::tip Advanced Tip
We could generate `resource_addr` inside the `mint` function instead of making the user supply it by calling `create_resource_address(source_address, seed)` in account.move, but the function has heavy computational overhead because it uses a cryptographic hashing function. In some instances where we only call this function a few times, this might be okay, but since a `mint` function is intended to be called by potentially thousands of users in a very short period of time, we make the user supply the resource address instead.
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

### Publishing the module

Publishing the module is basically the same as before. Just make sure you're in the `2-Using-Resource-Account` directory and run this command, note the only thing that changed is the module name in the first line, `create_nft_with_resource_account` instead of `create_nft:

```shell
aptos move publish --named-addresses mint_nft_v2_part2=default --profile default --assume-yes
```

### Running the contract

Call this function as the owner of the contract, which is our `default` profile. Keep in mind the `--profile default` flag:

```shell
aptos move run --function-id default::create_nft_with_resource_account::initialize_collection   \
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

Now we call this function as a user, which we simulate with our `nft-receiver` profile:

```shell
aptos move run --function-id default::create_nft_with_resource_account::mint --profile nft-receiver
```

Great! Now you've created the collection as an owner and requested to mint as a user and received the newly minted NFT.

It may not feel different, since you're acting as the owner and the receiver all from the command line, but the user flow for this makes much more sense than before.

Imagine the difference in the first part vs the second part as a user:

1. You have to wait for the owner of the contract to send you an NFT.
2. You can request to mint the NFT yourself.

The second option is a significantly better user experience, and it was only possible because we utilized a resource account.

## 3. Adding a start time, an end time, and an admin