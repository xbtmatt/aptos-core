// Copyright © Aptos Foundation

use crate::{
    abort_unless_arithmetics_enabled_for_structure, abort_unless_feature_flag_enabled,
    natives::{
        cryptography::algebra::{
            feature_flag_from_structure, gas::GasParameters, AlgebraContext, Structure,
            BLS12381_GT_GENERATOR, BLS12381_Q12_LENDIAN, BLS12381_R_LENDIAN,
            MOVE_ABORT_CODE_NOT_IMPLEMENTED, NUM_OBJECTS_LIMIT,
        },
        helpers::{SafeNativeContext, SafeNativeError, SafeNativeResult},
    },
    store_element, structure_from_ty_arg,
};
use ark_ec::Group;
use move_core_types::gas_algebra::NumArgs;
use move_vm_types::{loaded_data::runtime_types::Type, values::Value};
use num_traits::{One, Zero};
use once_cell::sync::Lazy;
use smallvec::{smallvec, SmallVec};
use std::{collections::VecDeque, rc::Rc};
use crate::natives::cryptography::algebra::abort_invariant_violated;

macro_rules! ark_constant_op_internal {
    ($context:expr, $ark_typ:ty, $ark_func:ident, $gas:expr) => {{
        $context.charge($gas)?;
        let new_element = <$ark_typ>::$ark_func();
        let new_handle = store_element!($context, new_element)?;
        Ok(smallvec![Value::u64(new_handle as u64)])
    }};
}

pub fn zero_internal(
    gas_params: &GasParameters,
    context: &mut SafeNativeContext,
    ty_args: Vec<Type>,
    mut _args: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    let structure_opt = structure_from_ty_arg!(context, &ty_args[0]);
    abort_unless_arithmetics_enabled_for_structure!(context, structure_opt);
    match structure_opt {
        Some(Structure::BLS12381Fr) => ark_constant_op_internal!(
            context,
            ark_bls12_381::Fr,
            zero,
            gas_params.ark_bls12_381_fr_zero * NumArgs::one()
        ),
        Some(Structure::BLS12381Fq12) => ark_constant_op_internal!(
            context,
            ark_bls12_381::Fq12,
            zero,
            gas_params.ark_bls12_381_fq12_zero * NumArgs::one()
        ),
        Some(Structure::BLS12381G1) => ark_constant_op_internal!(
            context,
            ark_bls12_381::G1Projective,
            zero,
            gas_params.ark_bls12_381_g1_proj_infinity * NumArgs::one()
        ),
        Some(Structure::BLS12381G2) => ark_constant_op_internal!(
            context,
            ark_bls12_381::G2Projective,
            zero,
            gas_params.ark_bls12_381_g2_proj_infinity * NumArgs::one()
        ),
        Some(Structure::BLS12381Gt) => ark_constant_op_internal!(
            context,
            ark_bls12_381::Fq12,
            one,
            gas_params.ark_bls12_381_fq12_one * NumArgs::one()
        ),
        _ => Err(SafeNativeError::Abort {
            abort_code: MOVE_ABORT_CODE_NOT_IMPLEMENTED,
        }),
    }
}

pub fn one_internal(
    gas_params: &GasParameters,
    context: &mut SafeNativeContext,
    ty_args: Vec<Type>,
    mut _args: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    let structure_opt = structure_from_ty_arg!(context, &ty_args[0]);
    abort_unless_arithmetics_enabled_for_structure!(context, structure_opt);
    match structure_opt {
        Some(Structure::BLS12381Fr) => ark_constant_op_internal!(
            context,
            ark_bls12_381::Fr,
            one,
            gas_params.ark_bls12_381_fr_one * NumArgs::one()
        ),
        Some(Structure::BLS12381Fq12) => ark_constant_op_internal!(
            context,
            ark_bls12_381::Fq12,
            one,
            gas_params.ark_bls12_381_fq12_one * NumArgs::one()
        ),
        Some(Structure::BLS12381G1) => ark_constant_op_internal!(
            context,
            ark_bls12_381::G1Projective,
            generator,
            gas_params.ark_bls12_381_g1_proj_generator * NumArgs::one()
        ),
        Some(Structure::BLS12381G2) => ark_constant_op_internal!(
            context,
            ark_bls12_381::G2Projective,
            generator,
            gas_params.ark_bls12_381_g2_proj_generator * NumArgs::one()
        ),
        Some(Structure::BLS12381Gt) => {
            context.charge(gas_params.ark_bls12_381_fq12_clone * NumArgs::one())?;
            let element = *Lazy::force(&BLS12381_GT_GENERATOR);
            let handle = {
                let target_vec = &mut context.extensions_mut().get_mut::<AlgebraContext>().objs;
                let ret = target_vec.len();
                if ret > 999 {
                    return SafeNativeResult::Err(SafeNativeError::InvariantViolation(abort_invariant_violated()));
                }
                target_vec.push(Rc::new(element));
                ret
            };
            Ok(smallvec![Value::u64(handle as u64)])
        },
        _ => Err(SafeNativeError::Abort {
            abort_code: MOVE_ABORT_CODE_NOT_IMPLEMENTED,
        }),
    }
}

pub fn order_internal(
    _gas_params: &GasParameters,
    context: &mut SafeNativeContext,
    ty_args: Vec<Type>,
    mut _args: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    assert_eq!(1, ty_args.len());
    let structure_opt = structure_from_ty_arg!(context, &ty_args[0]);
    abort_unless_arithmetics_enabled_for_structure!(context, structure_opt);
    match structure_opt {
        Some(Structure::BLS12381Fr)
        | Some(Structure::BLS12381G1)
        | Some(Structure::BLS12381G2)
        | Some(Structure::BLS12381Gt) => {
            Ok(smallvec![Value::vector_u8(BLS12381_R_LENDIAN.clone())])
        },
        Some(Structure::BLS12381Fq12) => {
            Ok(smallvec![Value::vector_u8(BLS12381_Q12_LENDIAN.clone())])
        },
        _ => Err(SafeNativeError::Abort {
            abort_code: MOVE_ABORT_CODE_NOT_IMPLEMENTED,
        }),
    }
}
