//! Isolated FFI feasibility experiment; not a production API.
use std::{panic::{catch_unwind, AssertUnwindSafe}, path::PathBuf, slice, str};
use ndarray::{ArrayView2, ArrayViewMut2};
use crate::tract::{DfParams, DfTract, RuntimeParams, ReduceMask};

pub struct ResearchState(DfTract);

#[no_mangle]
pub unsafe extern "C" fn research_create(path: *const u8, length: usize, out: *mut *mut ResearchState) -> i32 {
    if path.is_null() || out.is_null() || length == 0 || length > 32768 { return 1; }
    *out = std::ptr::null_mut();
    match catch_unwind(AssertUnwindSafe(|| {
        let text = str::from_utf8(slice::from_raw_parts(path, length)).map_err(|_| ())?;
        let params = DfParams::new(PathBuf::from(text)).map_err(|_| ())?;
        let runtime = RuntimeParams::default_with_ch(1).with_atten_lim(25.0)
            .with_thresholds(-15.0, 35.0, 35.0).with_post_filter(0.0)
            .with_mask_reduce(ReduceMask::MAX);
        let model = DfTract::new(params, &runtime).map_err(|_| ())?;
        if model.hop_size != 480 { return Err(()); }
        Ok(Box::into_raw(Box::new(ResearchState(model))))
    })) {
        Ok(Ok(state)) => { *out = state; 0 },
        Ok(Err(())) => 2,
        Err(_) => 4,
    }
}

#[no_mangle]
pub unsafe extern "C" fn research_process(state: *mut ResearchState, input: *const f32,
                                           output: *mut f32, count: usize) -> i32 {
    if state.is_null() || input.is_null() || output.is_null() || count != 480 ||
       (input as usize) % 4 != 0 || (output as usize) % 4 != 0 { return 1; }
    let input_end = match (input as usize).checked_add(count * 4) { Some(end) => end, None => return 1 };
    let output_end = match (output as usize).checked_add(count * 4) { Some(end) => end, None => return 1 };
    if (input as usize) < output_end && (output as usize) < input_end { return 1; }
    let input = slice::from_raw_parts(input, count);
    let output = slice::from_raw_parts_mut(output, count);
    output.fill(0.0);
    if !input.iter().all(|x| x.is_finite()) { return 1; }
    match catch_unwind(AssertUnwindSafe(|| {
        let input_view = ArrayView2::from_shape((1, count), input).map_err(|_| ())?;
        let output_view = ArrayViewMut2::from_shape((1, count), &mut *output).map_err(|_| ())?;
        (*state).0.process(input_view, output_view).map_err(|_| ())?;
        if !output.iter().all(|x| x.is_finite()) { return Err(()); }
        Ok(())
    })) {
        Ok(Ok(())) => 0,
        Ok(Err(())) => { output.fill(0.0); 3 },
        Err(_) => { output.fill(0.0); 4 },
    }
}

#[no_mangle]
pub unsafe extern "C" fn research_free(state: *mut ResearchState) -> i32 {
    if state.is_null() { return 1; }
    match catch_unwind(AssertUnwindSafe(|| drop(Box::from_raw(state)))) {
        Ok(()) => 0,
        Err(_) => 4,
    }
}
