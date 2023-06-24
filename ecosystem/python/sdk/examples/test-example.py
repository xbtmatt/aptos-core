# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

import asyncio

from aptos_sdk.account import Account
from aptos_sdk.account_address import AccountAddress
from aptos_sdk.aptos_token_client import AptosTokenClient, Property, PropertyMap
from aptos_sdk.async_client import FaucetClient, RestClient
from aptos_sdk.transactions import EntryFunction, TransactionArgument, TransactionPayload
from aptos_sdk.bcs import Serializer
from aptos_sdk import ed25519

from common import FAUCET_URL, NODE_URL

testnet_account = Account(AccountAddress.from_hex('0x527b0716834c96aea9f4e2ec8ef9873bdcc83f4268b59906a5cc243dbee6180c'),
                          ed25519.PrivateKey.from_hex('0x70920d419400e7f26fa3716416042f07133f3633e791fdc05f1a005db7513e23'))

async def main():
    rest_client = RestClient(NODE_URL)
    faucet_client = FaucetClient(FAUCET_URL, rest_client)
    token_client = AptosTokenClient(rest_client)
    
    print(await test_function(
         rest_client,
         testnet_account
	 ))
	 
async def test_function(
	rest_client: RestClient, account: Account
) -> str:

	payload = EntryFunction.natural(
			"0x3::token",
			"opt_in_direct_transfer",
			[],
			[TransactionArgument(True, Serializer.bool)],
	)

	signed_transaction = await rest_client.create_bcs_signed_transaction(
		account, TransactionPayload(payload)
	)
	return await rest_client.submit_bcs_transaction(signed_transaction)


if __name__ == "__main__":
    asyncio.run(main())
