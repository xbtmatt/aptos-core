## Objective

The objective of this contract is to create a proof-of-concept example for working z-traits with dynamic NFTs. It uses the Aptoads collection with dynamic NFTs as a base to overlay the z-trait standard with.

## What's a dynamic NFT?

Traits are traditionally just fields in an NFT's metadata, like so:

```
Aptoad {
	background: String,
	body: String,
	headwear: String,
	glasses: String,
}
```

However, in the Aptoads dNFT contract, we define some of the traits as NFTs themselves, which facilitates composable NFTs.

```
Aptoad {
	background: String,
	body: String,
	headwear: Object<Headwear>,
	glasses: Object<Glasses>,
}
```

This enables Token Objects to own each other, meaning the Aptoad can equip Headwear and Glasses by owning the objects. The data for these objects is located at the object references in their respective fields, but ownership is tied to the Aptoad Token Object itself.

This opens the door for many possibilities- one of which we will explore here.

## What is a z-trait?

A z-trait is a composable trait NFT that is used in a dynamic NFT.

It operates mostly like a normal NFT, except that it has an additional Metadata resource attached to it that defines the z-index that the trait is supposed to appear at when making a composite image for the overall NFT:

```
struct zTrait has key {
	negative: bool,
	z_index: u64,
	uri: String,
}
```



// the below would be another standard entirely imo, focus on traits for now and then implement z-states once z-traits are done.
define a lambda function that returns the uri for an object given inputs Object<Trait<T>>
Trait defines this with a function call that calls the lambda defined by the creator that was given to it at initialization..? 
Is this even possible?

## Nested Traits
```
struct Aptoad has key {
	headwear: Object<Trait<Headwear>>,
}

struct Headwear has store {
	// this would have a relative z-index based on the parent's z-index...no this makes no sense, otherwise you'd need negative z-indexes?
	// actually let's use negative z-indexes 8)
	cool_thing: Object<Trait<CoolThing>>,
}

struct Headwear has key {

}
```
