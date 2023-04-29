// Copyright © Aptos Foundation

use crate::{
    abort_unless_arithmetics_enabled_for_structure, abort_unless_feature_flag_enabled,
    natives::{
        cryptography::algebra::{
            abort_invariant_violated, feature_flag_from_structure, gas::GasParameters,
            AlgebraContext, Structure, MOVE_ABORT_CODE_NOT_IMPLEMENTED, NUM_OBJECTS_LIMIT,
        },
        helpers::{SafeNativeContext, SafeNativeError, SafeNativeResult},
    },
    safe_borrow_element, safely_pop_arg, store_element, structure_from_ty_arg,
};
use ark_ff::Field;
use move_core_types::gas_algebra::NumArgs;
use move_vm_types::{loaded_data::runtime_types::Type, values::Value};
use smallvec::{smallvec, SmallVec};
use std::{collections::VecDeque, rc::Rc};

macro_rules! ark_inverse_internal {
    ($context:expr, $args:ident, $ark_typ:ty, $gas:expr) => {{
        let handle = safely_pop_arg!($args, u64) as usize;
        safe_borrow_element!($context, handle, $ark_typ, element_ptr, element);
        $context.charge($gas)?;
        match element.inverse() {
            Some(new_element) => {
                let new_handle = store_element!($context, new_element)?;
                Ok(smallvec![Value::bool(true), Value::u64(new_handle as u64)])
            },
            None => Ok(smallvec![Value::bool(false), Value::u64(0)]),
        }
    }};
}

pub fn inv_internal(
    gas_params: &GasParameters,
    context: &mut SafeNativeContext,
    ty_args: Vec<Type>,
    mut args: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    let structure_opt = structure_from_ty_arg!(context, &ty_args[0]);
    abort_unless_arithmetics_enabled_for_structure!(context, structure_opt);
    match structure_opt {
        Some(Structure::BLS12381Fr) => ark_inverse_internal!(
            context,
            args,
            ark_bls12_381::Fr,
            gas_params.ark_bls12_381_fr_inv * NumArgs::one()
        ),
        Some(Structure::BLS12381Fq12) => ark_inverse_internal!(
            context,
            args,
            ark_bls12_381::Fq12,
            gas_params.ark_bls12_381_fq12_inv * NumArgs::one()
        ),
        _ => Err(SafeNativeError::Abort {
            abort_code: MOVE_ABORT_CODE_NOT_IMPLEMENTED,
        }),
    }
}
