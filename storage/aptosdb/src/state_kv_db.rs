// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

#![forbid(unsafe_code)]

use crate::{
    db_metadata::{DbMetadataKey, DbMetadataSchema, DbMetadataValue},
    db_options::{gen_state_kv_cfds, state_kv_db_column_families},
    utils::truncation_helper::{get_state_kv_commit_progress, truncate_state_kv_db_shards},
    COMMIT_POOL, NUM_STATE_SHARDS,
};
use anyhow::Result;
use aptos_config::config::{RocksdbConfig, RocksdbConfigs};
use aptos_logger::prelude::info;
use aptos_rocksdb_options::gen_rocksdb_options;
use aptos_schemadb::{SchemaBatch, DB};
use aptos_types::transaction::Version;
use arr_macro::arr;
use std::{
    path::{Path, PathBuf},
    sync::Arc,
};

pub const STATE_KV_DB_FOLDER_NAME: &str = "state_kv_db";
pub const STATE_KV_METADATA_DB_NAME: &str = "state_kv_metadata_db";

pub struct StateKvDb {
    state_kv_metadata_db: Arc<DB>,
    state_kv_db_shards: [Arc<DB>; NUM_STATE_SHARDS],
    enabled_sharding: bool,
}

impl StateKvDb {
    // TODO(grao): Support more flexible path to make it easier for people to put different shards
    // on different disks.
    pub(crate) fn new<P: AsRef<Path>>(
        db_root_path: P,
        rocksdb_configs: RocksdbConfigs,
        readonly: bool,
        ledger_db: Arc<DB>,
    ) -> Result<Self> {
        if !rocksdb_configs.split_ledger_db {
            info!("State K/V DB is not enabled!");
            return Ok(Self {
                state_kv_metadata_db: Arc::clone(&ledger_db),
                state_kv_db_shards: arr![Arc::clone(&ledger_db); 16],
                enabled_sharding: false,
            });
        }

        Self::open(db_root_path, rocksdb_configs.state_kv_db_config, readonly)
    }

    pub(crate) fn open<P: AsRef<Path>>(
        db_root_path: P,
        state_kv_db_config: RocksdbConfig,
        readonly: bool,
    ) -> Result<Self> {
        let state_kv_metadata_db_path = Self::metadata_db_path(db_root_path.as_ref());

        let state_kv_metadata_db = Arc::new(Self::open_db(
            state_kv_metadata_db_path.clone(),
            STATE_KV_METADATA_DB_NAME,
            &state_kv_db_config,
            readonly,
        )?);

        info!(
            state_kv_metadata_db_path = state_kv_metadata_db_path,
            "Opened state kv metadata db!"
        );

        let state_kv_db_shards = {
            let mut shard_id: usize = 0;
            arr![{
                let db = Self::open_shard(db_root_path.as_ref(), shard_id as u8, &state_kv_db_config, readonly)?;
                shard_id += 1;
                Arc::new(db)
            }; 16]
        };

        let state_kv_db = Self {
            state_kv_metadata_db,
            state_kv_db_shards,
            enabled_sharding: true,
        };

        if let Some(overall_kv_commit_progress) = get_state_kv_commit_progress(&state_kv_db)? {
            truncate_state_kv_db_shards(&state_kv_db, overall_kv_commit_progress, None)?;
        }

        Ok(state_kv_db)
    }

    pub(crate) fn commit(
        &self,
        version: Version,
        state_kv_metadata_batch: SchemaBatch,
        sharded_state_kv_batches: [SchemaBatch; NUM_STATE_SHARDS],
    ) -> Result<()> {
        COMMIT_POOL.scope(|s| {
            let mut batches = sharded_state_kv_batches.into_iter();
            for shard_id in 0..NUM_STATE_SHARDS {
                let state_kv_batch = batches.next().unwrap();
                s.spawn(move |_| {
                    // TODO(grao): Consider propagating the error instead of panic, if necessary.
                    self.commit_single_shard(version, shard_id as u8, state_kv_batch)
                        .unwrap_or_else(|_| panic!("Failed to commit shard {shard_id}."));
                });
            }
        });

        self.state_kv_metadata_db
            .write_schemas(state_kv_metadata_batch)?;

        self.write_progress(version)
    }

    pub(crate) fn commit_raw_batch(&self, state_kv_batch: SchemaBatch) -> Result<()> {
        // TODO(grao): Support sharding here.
        self.state_kv_metadata_db.write_schemas(state_kv_batch)
    }

    pub(crate) fn write_progress(&self, version: Version) -> Result<()> {
        self.state_kv_metadata_db.put::<DbMetadataSchema>(
            &DbMetadataKey::StateKvCommitProgress,
            &DbMetadataValue::Version(version),
        )
    }

    pub(crate) fn write_pruner_progress(&self, version: Version) -> Result<()> {
        self.state_kv_metadata_db.put::<DbMetadataSchema>(
            &DbMetadataKey::StateKvPrunerProgress,
            &DbMetadataValue::Version(version),
        )
    }

    pub(crate) fn create_checkpoint(
        db_root_path: impl AsRef<Path>,
        cp_root_path: impl AsRef<Path>,
    ) -> Result<()> {
        let state_kv_db = Self::open(db_root_path, RocksdbConfig::default(), false)?;
        let cp_state_kv_db_path = cp_root_path.as_ref().join(STATE_KV_DB_FOLDER_NAME);

        info!("Creating state_kv_db checkpoint at: {cp_state_kv_db_path:?}");

        std::fs::remove_dir_all(&cp_state_kv_db_path).unwrap_or(());
        std::fs::create_dir_all(&cp_state_kv_db_path).unwrap_or(());

        state_kv_db
            .metadata_db()
            .create_checkpoint(Self::metadata_db_path(cp_root_path.as_ref()))?;

        for shard_id in 0..NUM_STATE_SHARDS {
            state_kv_db
                .db_shard(shard_id as u8)
                .create_checkpoint(Self::db_shard_path(cp_root_path.as_ref(), shard_id as u8))?;
        }

        Ok(())
    }

    pub(crate) fn metadata_db(&self) -> &DB {
        &self.state_kv_metadata_db
    }

    pub(crate) fn db_shard(&self, shard_id: u8) -> &DB {
        &self.state_kv_db_shards[shard_id as usize]
    }

    pub(crate) fn db_shard_arc(&self, shard_id: u8) -> Arc<DB> {
        Arc::clone(&self.state_kv_db_shards[shard_id as usize])
    }

    pub(crate) fn enabled_sharding(&self) -> bool {
        self.enabled_sharding
    }

    pub(crate) fn num_shards(&self) -> u8 {
        NUM_STATE_SHARDS as u8
    }

    pub(crate) fn commit_single_shard(
        &self,
        version: Version,
        shard_id: u8,
        batch: SchemaBatch,
    ) -> Result<()> {
        batch.put::<DbMetadataSchema>(
            &DbMetadataKey::StateKvShardCommitProgress(shard_id as usize),
            &DbMetadataValue::Version(version),
        )?;
        self.state_kv_db_shards[shard_id as usize].write_schemas(batch)
    }

    fn open_shard<P: AsRef<Path>>(
        db_root_path: P,
        shard_id: u8,
        state_kv_db_config: &RocksdbConfig,
        readonly: bool,
    ) -> Result<DB> {
        let db_name = format!("state_kv_db_shard_{}", shard_id);
        Self::open_db(
            Self::db_shard_path(db_root_path, shard_id),
            &db_name,
            state_kv_db_config,
            readonly,
        )
    }

    fn open_db(
        path: PathBuf,
        name: &str,
        state_kv_db_config: &RocksdbConfig,
        readonly: bool,
    ) -> Result<DB> {
        Ok(if readonly {
            DB::open_cf_readonly(
                &gen_rocksdb_options(state_kv_db_config, true),
                path,
                name,
                state_kv_db_column_families(),
            )?
        } else {
            DB::open_cf(
                &gen_rocksdb_options(state_kv_db_config, false),
                path,
                name,
                gen_state_kv_cfds(state_kv_db_config),
            )?
        })
    }

    fn db_shard_path<P: AsRef<Path>>(db_root_path: P, shard_id: u8) -> PathBuf {
        let shard_sub_path = format!("shard_{}", shard_id);
        db_root_path
            .as_ref()
            .join(STATE_KV_DB_FOLDER_NAME)
            .join(Path::new(&shard_sub_path))
    }

    fn metadata_db_path<P: AsRef<Path>>(db_root_path: P) -> PathBuf {
        db_root_path
            .as_ref()
            .join(STATE_KV_DB_FOLDER_NAME)
            .join("metadata")
    }
}
