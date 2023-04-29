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
    safely_pop_arg, store_element, structure_from_ty_arg,
};
use move_core_types::gas_algebra::NumArgs;
use move_vm_types::{loaded_data::runtime_types::Type, values::Value};
use smallvec::{smallvec, SmallVec};
use std::{collections::VecDeque, rc::Rc};

macro_rules! from_u64_internal {
    ($context:expr, $args:ident, $typ:ty, $gas:expr) => {{
        let value = safely_pop_arg!($args, u64);
        $context.charge($gas)?;
        let element = <$typ>::from(value as u64);
        let handle = store_element!($context, element)?;
        Ok(smallvec![Value::u64(handle as u64)])
    }};
}

pub fn from_u64_internal(
    gas_params: &GasParameters,
    context: &mut SafeNativeContext,
    ty_args: Vec<Type>,
    mut args: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    assert_eq!(1, ty_args.len());
    let structure_opt = structure_from_ty_arg!(context, &ty_args[0]);
    abort_unless_arithmetics_enabled_for_structure!(context, structure_opt);
    match structure_opt {
        Some(Structure::BLS12381Fr) => from_u64_internal!(
            context,
            args,
            ark_bls12_381::Fr,
            gas_params.ark_bls12_381_fr_from_u64 * NumArgs::one()
        ),
        Some(Structure::BLS12381Fq12) => from_u64_internal!(
            context,
            args,
            ark_bls12_381::Fq12,
            gas_params.ark_bls12_381_fq12_from_u64 * NumArgs::one()
        ),
        _ => Err(SafeNativeError::Abort {
            abort_code: MOVE_ABORT_CODE_NOT_IMPLEMENTED,
        }),
    }
}
