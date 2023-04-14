// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use aptos_crypto::HashValue;
use aptos_infallible::Mutex;
use aptos_logger::error;
use aptos_types::executable::{Executable, ModulePath};
use dashmap::DashMap;
use std::{
    hash::Hash,
    sync::atomic::{AtomicU8, AtomicUsize, Ordering},
};

/// The total size of executables is tracked per update, but lazily (adjusted after the
/// respective insertion / removal. We adjust the origin value so in between subtractions
/// that take affect out of order can't cause an underflow.
const TOTAL_SIZE_ORIGIN: usize = std::usize::MAX / 2;

/// Represents the state of the ExecutableStore. The goal is to catch errors in intended
/// use, and reset the executable cache to an empty state if its status can't guarantee
/// matching the state after the parent block id.
///
/// During the execution, the cache might get updated, i.e. if a new executable at storage
/// version gets stored. After block execution, more updates may occur to align the cache
/// contents to the new boundary: published modules may invalidated previously stored
/// executables, and new corresponding executables may also be available. 'mark_updated'
/// method can be called afterwards to mark status accordingly. Missing Updated status
/// would indicate that the cache wasn't sychronized to the new block, and should not be
/// re-used for the subsequent blocks. The Void status in such cases allows graceful
/// handling by resetting / clearing the cache as needed.
///
/// Finally, ExecutableStore must be pruned, to control its size, and then the hash of the
/// block that was executed needs to be set, marking it full circle in the Ready state.
#[derive(Copy, Clone)]
enum ExecutableStoreStatus {
    Ready = 0,   // The cache is in a ready-to-use at a state after recorded block id.
    Updated = 1, // The cache was updated / synchronized after the block execution.
    Pruned = 2,  // The cache was pruned, must record the executed block id to become ready.
    Void = 3,    // Unexpected status update order (Ready -> Updated -> Pruned).
}

pub struct ExecutableStore<K: Eq + Hash + ModulePath, X: Executable> {
    executables: DashMap<K, X>,
    // TODO: underflow bug on total_size!!!
    total_size: AtomicUsize,
    status: AtomicU8,
    block_id: Mutex<Option<HashValue>>,
}

impl<K: Eq + Hash + ModulePath, X: Executable> Default for ExecutableStore<K, X> {
    fn default() -> Self {
        Self {
            executables: DashMap::new(),
            total_size: AtomicUsize::new(TOTAL_SIZE_ORIGIN),
            status: AtomicU8::new(ExecutableStoreStatus::Ready as u8),
            block_id: Mutex::new(None),
        }
    }
}

impl<K: Eq + Hash + ModulePath, X: Executable> ExecutableStore<K, X> {
    ///
    /// The following methods should be called in quiescence. These are intended to
    /// process the state and status of the Cache between block executions and be called
    /// single-threaded. As such, no extra atomicity of ops within methods is needed.
    ///

    // Flushes the cache and marks status as Ready. This essentially happens for error
    // handling in cases when the empty cache is sufficient to proceed despite the error.
    fn reset(&self) {
        self.executables.clear();
        self.total_size.store(TOTAL_SIZE_ORIGIN, Ordering::Relaxed);
        self.block_id.lock().take();
    }

    /// Should be invoked after fully executing a new block w. block_id, and performing
    /// required steps (updating & pruning the cache to align with the new block). If
    /// the statuses were not updated in a proper order (Ready -> Updated -> Pruned),
    /// then the cache will be cleared instead of recording the block_id.
    pub fn mark_ready(&self, block_id: HashValue) {
        let prev_status = self
            .status
            .swap(ExecutableStoreStatus::Ready as u8, Ordering::Relaxed);

        if prev_status == ExecutableStoreStatus::Void as u8 {
            self.reset();
        } else {
            self.block_id.lock().replace(block_id);
        }
    }

    /// This method checks that the status is Ready, and either self.block_id is be None
    /// (corresponding to an empty cache), or matching block_id must be provided by the
    /// caller for confirmation. This method panics if the status is not ready, as
    /// mark_ready (or new ExecutableStore) can be used to ensure a proper status.
    /// However, if the block_id does not match the provided parent block id, the cache
    /// is cleared & error is logged for out of order execution.
    pub fn check_ready(&self, maybe_parent_block_id: Option<HashValue>) {
        assert!(
            self.status.load(Ordering::Relaxed) == ExecutableStoreStatus::Ready as u8,
            "Executable cache not Ready for block execution"
        );

        let block_id = self.block_id.lock().clone();
        // Lock is released to avoid reset re-entry. Note: these calls are quiescent.

        if let Some(block_id) = block_id {
            if !maybe_parent_block_id.map_or(false, |id| id == block_id) {
                self.reset();
                error!(
                    "ExecutableStore block id {:?} != provided parent block id {:?}",
                    block_id, maybe_parent_block_id
                );
            }
        }
    }

    /// If the status is observed to be expected_status, set it to new_status.
    /// Otherwise, set status to Void.
    fn set_status(
        &self,
        expected_status: ExecutableStoreStatus,
        new_status: ExecutableStoreStatus,
    ) {
        let status = self.status.load(Ordering::Relaxed);

        // Load and Store do not need to be atomic as the calling methods are supposed
        // to only be used by a single thread in quiescence.
        self.status.store(
            if status == expected_status as u8 {
                new_status as u8
            } else {
                ExecutableStoreStatus::Void as u8
            },
            Ordering::Relaxed,
        );
    }

    /// Should be called when the cache is updated to be aligned with the state after
    /// a block execution. Will set status to Void if the previous status wasn't Ready.
    pub fn mark_updated(&self) {
        self.set_status(ExecutableStoreStatus::Ready, ExecutableStoreStatus::Updated);
    }

    /// Must be called after block execution is complete, and the cache has been
    /// updated accordingly (to contain base executables after the block execution).
    /// Pruning is required to be able to update the block hash and re-use the
    /// executable cache. If the cache isn't intended to be re-used, there is no
    /// need to prune and new ExecutableStore can be created instead. If the previous
    /// status isn't Updated, the Void status is set.
    ///
    /// Basic eviction policy: if total size > provided threshold, clear everything.
    /// Returns the size of all executables before pruning.
    /// TODO: more complex eviction policy.
    pub fn prune(&self, size_threshold: usize) -> usize {
        let size = self.total_size.load(Ordering::Relaxed) - TOTAL_SIZE_ORIGIN;
        if size > size_threshold {
            self.reset();
        }

        self.set_status(
            ExecutableStoreStatus::Updated,
            ExecutableStoreStatus::Pruned,
        );

        size
    }

    ///
    /// The following methods can be concurrent when invoked during the block execution.
    ///

    pub fn get(&self, key: &K) -> Option<X> {
        self.executables.get(key).map(|x| x.clone())
    }

    pub fn insert(&self, key: K, executable: X) {
        let add_size = executable.size_bytes();
        let sub_size = self
            .executables
            .insert(key, executable)
            .map_or_else(|| 0, |x| x.size_bytes());

        if add_size >= sub_size {
            self.total_size
                .fetch_add(add_size - sub_size, Ordering::Relaxed);
        } else {
            self.total_size
                .fetch_sub(sub_size - add_size, Ordering::Relaxed);
        }
    }

    pub fn remove(&self, key: &K) {
        if let Some((_, x)) = self.executables.remove(key) {
            self.total_size.fetch_sub(x.size_bytes(), Ordering::Relaxed);
        };
    }
}
