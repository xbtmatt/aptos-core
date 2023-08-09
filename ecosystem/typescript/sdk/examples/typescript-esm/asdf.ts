import { Provider, Network } from 'aptos';

const provider = new Provider(Network.MAINNET); // your network here
const address = "0xffc117086980d34dc3b5a42cb407ed888f60623f46021f35c2ca522ea13cc961"; // your address here
const tokensOwned = await provider.indexerClient.getOwnedTokens(address);

console.log(`tokens owned by ${address}:\n`);
console.log(tokensOwned.current_token_ownerships_v2);
