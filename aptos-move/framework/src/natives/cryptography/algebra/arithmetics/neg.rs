// Copyright © Aptos Foundation

use crate::{
    abort_unless_arithmetics_enabled_for_structure, abort_unless_feature_flag_enabled,
    ark_unary_op_internal,
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
use std::{collections::VecDeque, ops::Neg, rc::Rc};

pub fn neg_internal(
    gas_params: &GasParameters,
    context: &mut SafeNativeContext,
    ty_args: Vec<Type>,
    mut args: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    assert_eq!(1, ty_args.len());
    let structure_opt = structure_from_ty_arg!(context, &ty_args[0]);
    abort_unless_arithmetics_enabled_for_structure!(context, structure_opt);
    match structure_opt {
        Some(Structure::BLS12381Fr) => ark_unary_op_internal!(
            context,
            args,
            ark_bls12_381::Fr,
            neg,
            gas_params.ark_bls12_381_fr_neg * NumArgs::one()
        ),
        Some(Structure::BLS12381Fq12) => ark_unary_op_internal!(
            context,
            args,
            ark_bls12_381::Fq12,
            neg,
            gas_params.ark_bls12_381_fq12_neg * NumArgs::one()
        ),
        Some(Structure::BLS12381G1) => ark_unary_op_internal!(
            context,
            args,
            ark_bls12_381::G1Projective,
            neg,
            gas_params.ark_bls12_381_g1_proj_neg * NumArgs::one()
        ),
        Some(Structure::BLS12381G2) => ark_unary_op_internal!(
            context,
            args,
            ark_bls12_381::G2Projective,
            neg,
            gas_params.ark_bls12_381_g2_proj_neg * NumArgs::one()
        ),
        Some(Structure::BLS12381Gt) => {
            let handle = safely_pop_arg!(args, u64) as usize;

            let element_ptr = context
                .extensions()
                .get::<AlgebraContext>()
                .objs
                .get(handle)
                .ok_or_else(abort_invariant_violated)?
                .clone();
            let element = element_ptr
                .downcast_ref::<ark_bls12_381::Fq12>()
                .ok_or_else(abort_invariant_violated)?;

            context.charge(gas_params.ark_bls12_381_fq12_inv * NumArgs::one())?;
            let new_element = element.inverse().ok_or_else(abort_invariant_violated)?;
            let new_handle = store_element!(context, new_element)?;
            Ok(smallvec![Value::u64(new_handle as u64)])
        },
        _ => Err(SafeNativeError::Abort {
            abort_code: MOVE_ABORT_CODE_NOT_IMPLEMENTED,
        }),
    }
}
