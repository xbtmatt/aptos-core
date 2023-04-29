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
use move_core_types::gas_algebra::NumArgs;
use move_vm_types::{loaded_data::runtime_types::Type, values::Value};
use num_traits::Zero;
use smallvec::{smallvec, SmallVec};
use std::{collections::VecDeque, ops::Div, rc::Rc};

macro_rules! ark_div_internal {
    ($context:expr, $args:ident, $ark_typ:ty, $ark_func:ident, $gas_eq:expr, $gas_div:expr) => {{
        let handle_2 = safely_pop_arg!($args, u64) as usize;
        let handle_1 = safely_pop_arg!($args, u64) as usize;
        safe_borrow_element!($context, handle_1, $ark_typ, element_1_ptr, element_1);
        safe_borrow_element!($context, handle_2, $ark_typ, element_2_ptr, element_2);
        $context.charge($gas_eq)?;
        if element_2.is_zero() {
            return Ok(smallvec![Value::bool(false), Value::u64(0_u64)]);
        }
        $context.charge($gas_div)?;
        let new_element = element_1.$ark_func(element_2);
        let new_handle = store_element!($context, new_element)?;
        Ok(smallvec![Value::bool(true), Value::u64(new_handle as u64)])
    }};
}

pub fn div_internal(
    gas_params: &GasParameters,
    context: &mut SafeNativeContext,
    ty_args: Vec<Type>,
    mut args: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    assert_eq!(1, ty_args.len());
    let structure_opt = structure_from_ty_arg!(context, &ty_args[0]);
    abort_unless_arithmetics_enabled_for_structure!(context, structure_opt);
    match structure_opt {
        Some(Structure::BLS12381Fr) => ark_div_internal!(
            context,
            args,
            ark_bls12_381::Fr,
            div,
            gas_params.ark_bls12_381_fr_eq * NumArgs::one(),
            gas_params.ark_bls12_381_fr_div * NumArgs::one()
        ),
        Some(Structure::BLS12381Fq12) => ark_div_internal!(
            context,
            args,
            ark_bls12_381::Fq12,
            div,
            gas_params.ark_bls12_381_fq12_eq * NumArgs::one(),
            gas_params.ark_bls12_381_fq12_div * NumArgs::one()
        ),
        _ => Err(SafeNativeError::Abort {
            abort_code: MOVE_ABORT_CODE_NOT_IMPLEMENTED,
        }),
    }
}
