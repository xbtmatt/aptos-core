// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

// This is required because a diesel macro makes clippy sad
#![allow(clippy::extra_unused_lifetimes)]
#![allow(clippy::unused_unit)]

use super::{
    token_utils::TokenWriteSet, tokens::TableHandleToOwner, v2_token_utils::TokenStandard,
};
use crate::{
    schema::{current_token_ownerships_v2, token_ownerships_v2},
    util::{ensure_not_negative, standardize_address},
};
use aptos_api_types::{DeleteTableItem as APIDeleteTableItem, WriteTableItem as APIWriteTableItem};
use bigdecimal::{BigDecimal, Zero};
use field_count::FieldCount;
use serde::{Deserialize, Serialize};

// PK of current_token_ownerships_v2, i.e. token_data_id, property_version_v1, owner_address, storage_id
pub type CurrentTokenOwnershipV2PK = (String, BigDecimal, String, String);

#[derive(Debug, Deserialize, FieldCount, Identifiable, Insertable, Serialize)]
#[diesel(primary_key(transaction_version, write_set_change_index))]
#[diesel(table_name = token_ownerships_v2)]
pub struct TokenOwnershipV2 {
    pub transaction_version: i64,
    pub write_set_change_index: i64,
    pub token_data_id: String,
    pub property_version_v1: BigDecimal,
    pub owner_address: Option<String>,
    pub storage_id: String,
    pub amount: BigDecimal,
    pub table_type_v1: Option<String>,
    pub token_properties_mutated_v1: Option<serde_json::Value>,
    pub token_standard: String,
    pub is_fungible_v2: Option<bool>,
    pub transaction_timestamp: chrono::NaiveDateTime,
}

#[derive(Debug, Deserialize, FieldCount, Identifiable, Insertable, Serialize)]
#[diesel(primary_key(token_data_id, property_version_v1, owner_address, storage_id))]
#[diesel(table_name = current_token_ownerships_v2)]
pub struct CurrentTokenOwnershipV2 {
    pub token_data_id: String,
    pub property_version_v1: BigDecimal,
    pub owner_address: String,
    pub storage_id: String,
    pub amount: BigDecimal,
    pub table_type_v1: Option<String>,
    pub token_properties_mutated_v1: Option<serde_json::Value>,
    pub token_standard: String,
    pub is_fungible_v2: Option<bool>,
    pub last_transaction_version: i64,
    pub last_transaction_timestamp: chrono::NaiveDateTime,
}

impl TokenOwnershipV2 {
    /// We want to track tokens in any offer/claims and tokenstore
    pub fn get_v1_from_write_table_item(
        table_item: &APIWriteTableItem,
        txn_version: i64,
        write_set_change_index: i64,
        txn_timestamp: chrono::NaiveDateTime,
        table_handle_to_owner: &TableHandleToOwner,
    ) -> anyhow::Result<Option<(Self, Option<CurrentTokenOwnershipV2>)>> {
        let table_item_data = table_item.data.as_ref().unwrap();

        let maybe_token = match TokenWriteSet::from_table_item_type(
            table_item_data.value_type.as_str(),
            &table_item_data.value,
            txn_version,
        )? {
            Some(TokenWriteSet::Token(inner)) => Some(inner),
            _ => None,
        };

        if let Some(token) = maybe_token {
            let table_handle = standardize_address(&table_item.handle.to_string());
            let amount = ensure_not_negative(token.amount);
            let token_id_struct = token.id;
            let token_data_id_struct = token_id_struct.token_data_id;
            let token_data_id = token_data_id_struct.to_id();

            let maybe_table_metadata = table_handle_to_owner.get(&table_handle);
            let (curr_token_ownership, owner_address, table_type) = match maybe_table_metadata {
                Some(tm) => {
                    let owner_address = standardize_address(&tm.owner_address);
                    (
                        Some(CurrentTokenOwnershipV2 {
                            token_data_id: token_data_id.clone(),
                            property_version_v1: token_id_struct.property_version.clone(),
                            owner_address: owner_address.clone(),
                            storage_id: table_handle.clone(),
                            amount: amount.clone(),
                            table_type_v1: Some(tm.table_type.clone()),
                            token_properties_mutated_v1: Some(token.token_properties.clone()),
                            token_standard: TokenStandard::V1.to_string(),
                            is_fungible_v2: None,
                            last_transaction_version: txn_version,
                            last_transaction_timestamp: txn_timestamp,
                        }),
                        Some(owner_address),
                        Some(tm.table_type.clone()),
                    )
                },
                None => {
                    aptos_logger::warn!(
                        transaction_version = txn_version,
                        table_handle = table_handle,
                        "Missing table handle metadata for TokenStore. {:?}",
                        table_handle_to_owner
                    );
                    (None, None, None)
                },
            };

            Ok(Some((
                Self {
                    transaction_version: txn_version,
                    write_set_change_index,
                    token_data_id,
                    property_version_v1: token_id_struct.property_version,
                    owner_address,
                    storage_id: table_handle,
                    amount,
                    table_type_v1: table_type,
                    token_properties_mutated_v1: Some(token.token_properties),
                    token_standard: TokenStandard::V1.to_string(),
                    is_fungible_v2: None,
                    transaction_timestamp: txn_timestamp,
                },
                curr_token_ownership,
            )))
        } else {
            Ok(None)
        }
    }

    /// We want to track tokens in any offer/claims and tokenstore
    pub fn get_v1_from_delete_table_item(
        table_item: &APIDeleteTableItem,
        txn_version: i64,
        write_set_change_index: i64,
        txn_timestamp: chrono::NaiveDateTime,
        table_handle_to_owner: &TableHandleToOwner,
    ) -> anyhow::Result<Option<(Self, Option<CurrentTokenOwnershipV2>)>> {
        let table_item_data = table_item.data.as_ref().unwrap();

        let maybe_token_id = match TokenWriteSet::from_table_item_type(
            table_item_data.key_type.as_str(),
            &table_item_data.key,
            txn_version,
        )? {
            Some(TokenWriteSet::TokenId(inner)) => Some(inner),
            _ => None,
        };

        if let Some(token_id_struct) = maybe_token_id {
            let table_handle = standardize_address(&table_item.handle.to_string());
            let token_data_id_struct = token_id_struct.token_data_id;
            let token_data_id = token_data_id_struct.to_id();

            let maybe_table_metadata = table_handle_to_owner.get(&table_handle);
            let (curr_token_ownership, owner_address, table_type) = match maybe_table_metadata {
                Some(tm) => {
                    let owner_address = standardize_address(&tm.owner_address);
                    (
                        Some(CurrentTokenOwnershipV2 {
                            token_data_id: token_data_id.clone(),
                            property_version_v1: token_id_struct.property_version.clone(),
                            owner_address: owner_address.clone(),
                            storage_id: table_handle.clone(),
                            amount: BigDecimal::zero(),
                            table_type_v1: Some(tm.table_type.clone()),
                            token_properties_mutated_v1: None,
                            token_standard: TokenStandard::V1.to_string(),
                            is_fungible_v2: None,
                            last_transaction_version: txn_version,
                            last_transaction_timestamp: txn_timestamp,
                        }),
                        Some(owner_address),
                        Some(tm.table_type.clone()),
                    )
                },
                None => {
                    aptos_logger::warn!(
                        transaction_version = txn_version,
                        table_handle = table_handle,
                        "Missing table handle metadata for TokenStore. {:?}",
                        table_handle_to_owner
                    );
                    (None, None, None)
                },
            };

            Ok(Some((
                Self {
                    transaction_version: txn_version,
                    write_set_change_index,
                    token_data_id,
                    property_version_v1: token_id_struct.property_version,
                    owner_address,
                    storage_id: table_handle,
                    amount: BigDecimal::zero(),
                    table_type_v1: table_type,
                    token_properties_mutated_v1: None,
                    token_standard: TokenStandard::V1.to_string(),
                    is_fungible_v2: None,
                    transaction_timestamp: txn_timestamp,
                },
                curr_token_ownership,
            )))
        } else {
            Ok(None)
        }
    }
}
