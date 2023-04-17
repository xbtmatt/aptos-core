// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

// This is required because a diesel macro makes clippy sad
#![allow(clippy::extra_unused_lifetimes)]
#![allow(clippy::unused_unit)]

use super::{token_utils::TokenWriteSet, v2_token_utils::TokenStandard};
use crate::schema::{current_token_datas_v2, token_datas_v2};
use aptos_api_types::WriteTableItem as APIWriteTableItem;
use bigdecimal::BigDecimal;
use field_count::FieldCount;
use serde::{Deserialize, Serialize};

// PK of current_token_datas_v2, i.e. token_data_id
pub type CurrentTokenDataV2PK = String;

#[derive(Debug, Deserialize, FieldCount, Identifiable, Insertable, Serialize)]
#[diesel(primary_key(transaction_version, write_set_change_index))]
#[diesel(table_name = token_datas_v2)]
pub struct TokenDataV2 {
    pub transaction_version: i64,
    pub write_set_change_index: i64,
    pub token_data_id: String,
    pub collection_id: String,
    pub token_name: String,
    pub maximum: BigDecimal,
    pub supply: BigDecimal,
    pub largest_property_version_v1: BigDecimal,
    pub token_uri: String,
    pub token_properties: serde_json::Value,
    pub description: String,
    pub token_standard: String,
    pub is_fungible_v2: Option<bool>,
    pub transaction_timestamp: chrono::NaiveDateTime,
}

#[derive(Debug, Deserialize, FieldCount, Identifiable, Insertable, Serialize)]
#[diesel(primary_key(token_data_id))]
#[diesel(table_name = current_token_datas_v2)]
pub struct CurrentTokenDataV2 {
    pub token_data_id: String,
    pub collection_id: String,
    pub token_name: String,
    pub maximum: BigDecimal,
    pub supply: BigDecimal,
    pub largest_property_version_v1: BigDecimal,
    pub token_uri: String,
    pub token_properties: serde_json::Value,
    pub description: String,
    pub token_standard: String,
    pub is_fungible_v2: Option<bool>,
    pub last_transaction_version: i64,
    pub last_transaction_timestamp: chrono::NaiveDateTime,
}

impl TokenDataV2 {
    pub fn get_v1_from_write_table_item(
        table_item: &APIWriteTableItem,
        txn_version: i64,
        write_set_change_index: i64,
        txn_timestamp: chrono::NaiveDateTime,
    ) -> anyhow::Result<Option<(Self, CurrentTokenDataV2)>> {
        let table_item_data = table_item.data.as_ref().unwrap();

        let maybe_token_data = match TokenWriteSet::from_table_item_type(
            table_item_data.value_type.as_str(),
            &table_item_data.value,
            txn_version,
        )? {
            Some(TokenWriteSet::TokenData(inner)) => Some(inner),
            _ => None,
        };

        if let Some(token_data) = maybe_token_data {
            let maybe_token_data_id = match TokenWriteSet::from_table_item_type(
                table_item_data.key_type.as_str(),
                &table_item_data.key,
                txn_version,
            )? {
                Some(TokenWriteSet::TokenDataId(inner)) => Some(inner),
                _ => None,
            };
            if let Some(token_data_id_struct) = maybe_token_data_id {
                let collection_id = token_data_id_struct.get_collection_id();
                let token_data_id = token_data_id_struct.to_id();
                let token_name = token_data_id_struct.get_name_trunc();
                let token_uri = token_data.get_uri_trunc();

                return Ok(Some((
                    Self {
                        transaction_version: txn_version,
                        write_set_change_index,
                        token_data_id: token_data_id.clone(),
                        collection_id: collection_id.clone(),
                        token_name: token_name.clone(),
                        maximum: token_data.maximum.clone(),
                        supply: token_data.supply.clone(),
                        largest_property_version_v1: token_data.largest_property_version.clone(),
                        token_uri: token_uri.clone(),
                        token_properties: token_data.default_properties.clone(),
                        description: token_data.description.clone(),
                        token_standard: TokenStandard::V1.to_string(),
                        is_fungible_v2: None,
                        transaction_timestamp: txn_timestamp,
                    },
                    CurrentTokenDataV2 {
                        token_data_id,
                        collection_id,
                        token_name,
                        maximum: token_data.maximum,
                        supply: token_data.supply,
                        largest_property_version_v1: token_data.largest_property_version,
                        token_uri,
                        token_properties: token_data.default_properties,
                        description: token_data.description,
                        token_standard: TokenStandard::V1.to_string(),
                        is_fungible_v2: None,
                        last_transaction_version: txn_version,
                        last_transaction_timestamp: txn_timestamp,
                    },
                )));
            } else {
                aptos_logger::warn!(
                    transaction_version = txn_version,
                    key_type = table_item_data.key_type,
                    key = table_item_data.key,
                    "Expecting token_data_id as key for value = token_data"
                );
            }
        }
        Ok(None)
    }
}
