// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{EntryPoints, TransactionType};
use clap::{ArgEnum, Parser};
use serde::{Deserialize, Serialize};

/// Utility class for specifying transaction type with predefined configurations through CLI
#[derive(Debug, Copy, Clone, ArgEnum, Deserialize, Parser, Serialize)]
pub enum TransactionTypeArg {
    NoOp,
    NoOp2Signers,
    NoOp5Signers,
    CoinTransfer,
    CoinTransferWithInvalid,
    AccountGeneration,
    AccountGenerationLargePool,
    NftMintAndTransfer,
    PublishPackage,
    CreateNewAccountResource,
    ModifyGlobalResource,
    Batch100Transfer,
    TokenV1NFTMintAndStoreSequential,
    TokenV1NFTMintAndTransferSequential,
    TokenV1NFTMintAndStoreParallel,
    TokenV1NFTMintAndTransferParallel,
    TokenV1FTMintAndStore,
    TokenV1FTMintAndTransfer,
    TokenV2AmbassadorMint,
}

impl Default for TransactionTypeArg {
    fn default() -> Self {
        TransactionTypeArg::CoinTransfer
    }
}

impl TransactionTypeArg {
    pub fn materialize(&self, module_working_set_size: usize) -> TransactionType {
        match self {
            TransactionTypeArg::CoinTransfer => TransactionType::CoinTransfer {
                invalid_transaction_ratio: 0,
                sender_use_account_pool: false,
            },
            TransactionTypeArg::CoinTransferWithInvalid => TransactionType::CoinTransfer {
                invalid_transaction_ratio: 10,
                sender_use_account_pool: false,
            },
            TransactionTypeArg::AccountGeneration => TransactionType::default_account_generation(),
            TransactionTypeArg::AccountGenerationLargePool => TransactionType::AccountGeneration {
                add_created_accounts_to_pool: true,
                max_account_working_set: 50_000_000,
                creation_balance: 200_000_000,
            },
            TransactionTypeArg::NftMintAndTransfer => TransactionType::NftMintAndTransfer,
            TransactionTypeArg::PublishPackage => TransactionType::PublishPackage {
                use_account_pool: true,
            },
            TransactionTypeArg::CreateNewAccountResource => TransactionType::CallCustomModules {
                entry_point: EntryPoints::BytesMakeOrChange {
                    data_length: Some(32),
                },
                num_modules: module_working_set_size,
                use_account_pool: true,
            },
            TransactionTypeArg::ModifyGlobalResource => TransactionType::CallCustomModules {
                entry_point: EntryPoints::StepDst,
                num_modules: module_working_set_size,
                use_account_pool: false,
            },
            TransactionTypeArg::NoOp => TransactionType::CallCustomModules {
                entry_point: EntryPoints::Nop,
                num_modules: module_working_set_size,
                use_account_pool: false,
            },
            TransactionTypeArg::NoOp2Signers => TransactionType::CallCustomModules {
                entry_point: EntryPoints::Nop,
                num_modules: module_working_set_size,
                use_account_pool: false,
            },
            TransactionTypeArg::NoOp5Signers => TransactionType::CallCustomModules {
                entry_point: EntryPoints::Nop,
                num_modules: module_working_set_size,
                use_account_pool: false,
            },
            TransactionTypeArg::Batch100Transfer => {
                TransactionType::BatchTransfer { batch_size: 100 }
            },
            TransactionTypeArg::TokenV1NFTMintAndStoreSequential => {
                TransactionType::CallCustomModules {
                    entry_point: EntryPoints::TokenV1MintAndStoreNFTSequential,
                    num_modules: module_working_set_size,
                    use_account_pool: false,
                }
            },
            TransactionTypeArg::TokenV1NFTMintAndTransferSequential => {
                TransactionType::CallCustomModules {
                    entry_point: EntryPoints::TokenV1MintAndTransferNFTSequential,
                    num_modules: module_working_set_size,
                    use_account_pool: false,
                }
            },
            TransactionTypeArg::TokenV1NFTMintAndStoreParallel => {
                TransactionType::CallCustomModules {
                    entry_point: EntryPoints::TokenV1MintAndStoreNFTParallel,
                    num_modules: module_working_set_size,
                    use_account_pool: false,
                }
            },
            TransactionTypeArg::TokenV1NFTMintAndTransferParallel => {
                TransactionType::CallCustomModules {
                    entry_point: EntryPoints::TokenV1MintAndTransferNFTParallel,
                    num_modules: module_working_set_size,
                    use_account_pool: false,
                }
            },
            TransactionTypeArg::TokenV1FTMintAndStore => TransactionType::CallCustomModules {
                entry_point: EntryPoints::TokenV1MintAndStoreFT,
                num_modules: module_working_set_size,
                use_account_pool: false,
            },
            TransactionTypeArg::TokenV1FTMintAndTransfer => TransactionType::CallCustomModules {
                entry_point: EntryPoints::TokenV1MintAndTransferFT,
                num_modules: module_working_set_size,
                use_account_pool: false,
            },
            TransactionTypeArg::TokenV2AmbassadorMint => TransactionType::CallCustomModules {
                entry_point: EntryPoints::TokenV2AmbassadorMint,
                num_modules: module_working_set_size,
                use_account_pool: false,
            },
        }
    }
}
