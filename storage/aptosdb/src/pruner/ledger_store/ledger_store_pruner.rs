// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    ledger_db::LedgerDb,
    metrics::PRUNER_VERSIONS,
    pruner::{
        db_pruner::DBPruner,
        db_sub_pruner::DBSubPruner,
        event_store::event_store_pruner::EventStorePruner,
        ledger_store::ledger_metadata_pruner::LedgerMetadataPruner,
        transaction_store::{
            transaction_accumulator_pruner::TransactionAccumulatorPruner,
            transaction_info_pruner::TransactionInfoPruner, transaction_pruner::TransactionPruner,
            write_set_pruner::WriteSetPruner,
        },
    },
    EventStore, TransactionStore,
};
use anyhow::Result;
use aptos_logger::info;
use aptos_types::transaction::{AtomicVersion, Version};
use std::{
    cmp::min,
    sync::{atomic::Ordering, Arc},
};

pub const LEDGER_PRUNER_NAME: &str = "ledger_pruner";

/// Responsible for pruning everything except for the state tree.
pub(crate) struct LedgerPruner {
    /// Keeps track of the target version that the pruner needs to achieve.
    target_version: AtomicVersion,

    progress: AtomicVersion,

    ledger_metadata_pruner: Box<LedgerMetadataPruner>,

    sub_pruners: Vec<Box<dyn DBSubPruner + Send + Sync>>,
}

impl DBPruner for LedgerPruner {
    fn name(&self) -> &'static str {
        LEDGER_PRUNER_NAME
    }

    fn prune(&self, max_versions: usize) -> Result<Version> {
        let mut progress = self.progress();
        let target_version = self.target_version();

        while progress < target_version {
            let current_batch_target_version =
                min(progress + max_versions as Version, target_version);

            self.ledger_metadata_pruner
                .prune(progress, current_batch_target_version)?;

            // NOTE: If necessary, this can be done in parallel.
            self.sub_pruners
                .iter()
                .try_for_each(|pruner| pruner.prune(progress, current_batch_target_version))?;

            progress = current_batch_target_version;
            self.record_progress(progress);
        }

        Ok(target_version)
    }

    fn progress(&self) -> Version {
        self.progress.load(Ordering::SeqCst)
    }

    fn set_target_version(&self, target_version: Version) {
        self.target_version.store(target_version, Ordering::SeqCst);
        PRUNER_VERSIONS
            .with_label_values(&["ledger_pruner", "target"])
            .set(target_version as i64);
    }

    fn target_version(&self) -> Version {
        self.target_version.load(Ordering::SeqCst)
    }

    fn record_progress(&self, progress: Version) {
        self.progress.store(progress, Ordering::SeqCst);
        PRUNER_VERSIONS
            .with_label_values(&["ledger_pruner", "progress"])
            .set(progress as i64);
    }
}

impl LedgerPruner {
    pub fn new(ledger_db: Arc<LedgerDb>) -> Result<Self> {
        info!(name = LEDGER_PRUNER_NAME, "Initializing...");

        let ledger_metadata_pruner = Box::new(
            LedgerMetadataPruner::new(ledger_db.metadata_db_arc())
                .expect("Failed to initialize ledger_metadata_pruner."),
        );

        let metadata_progress = ledger_metadata_pruner.progress()?;

        let transaction_store = Arc::new(TransactionStore::new(Arc::clone(&ledger_db)));

        let event_store_pruner = Box::new(EventStorePruner::new(
            Arc::new(EventStore::new(ledger_db.event_db_arc())),
            ledger_db.event_db_arc(),
            metadata_progress,
        )?);
        let transaction_accumulator_pruner = Box::new(TransactionAccumulatorPruner::new(
            Arc::clone(&transaction_store),
            ledger_db.transaction_accumulator_db_arc(),
            metadata_progress,
        )?);
        let transaction_info_pruner = Box::new(TransactionInfoPruner::new(
            Arc::clone(&transaction_store),
            ledger_db.transaction_info_db_arc(),
            metadata_progress,
        )?);
        let transaction_pruner = Box::new(TransactionPruner::new(
            Arc::clone(&transaction_store),
            ledger_db.transaction_db_arc(),
            metadata_progress,
        )?);
        let write_set_pruner = Box::new(WriteSetPruner::new(
            Arc::clone(&transaction_store),
            ledger_db.write_set_db_arc(),
            metadata_progress,
        )?);

        let pruner = LedgerPruner {
            target_version: AtomicVersion::new(metadata_progress),
            progress: AtomicVersion::new(metadata_progress),
            ledger_metadata_pruner,
            sub_pruners: vec![
                event_store_pruner,
                transaction_accumulator_pruner,
                transaction_info_pruner,
                transaction_pruner,
                write_set_pruner,
            ],
        };

        info!(
            name = pruner.name(),
            progress = metadata_progress,
            "Initialized."
        );

        Ok(pruner)
    }
}
