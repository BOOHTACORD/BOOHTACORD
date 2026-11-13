//! Local ownership experiment, not a production build.
use tract_core::ndarray::prelude::*;
use wasm_bindgen::prelude::*;
use crate::tract::*;

#[wasm_bindgen]
pub struct Denoiser { inner: DfTract, pristine: DfTract }

#[wasm_bindgen]
impl Denoiser {
    #[wasm_bindgen(constructor)]
    pub fn new(model: &[u8], attenuation: f32) -> Result<Denoiser, JsValue> {
        if !attenuation.is_finite() { return Err(JsValue::from_str("invalid attenuation")); }
        let params = DfParams::from_bytes(model).map_err(|_| JsValue::from_str("invalid model"))?;
        let runtime = RuntimeParams::default_with_ch(1).with_atten_lim(attenuation)
            .with_thresholds(f32::NEG_INFINITY, f32::INFINITY, f32::INFINITY);
        let inner = DfTract::new(params, &runtime).map_err(|_| JsValue::from_str("model initialization failed"))?;
        if inner.hop_size != 480 { return Err(JsValue::from_str("invalid frame size")); }
        let pristine = inner.clone();
        Ok(Denoiser { inner, pristine })
    }

    pub fn frame_size(&self) -> usize { self.inner.hop_size }

    pub fn reset(&mut self) { self.inner = self.pristine.clone(); }

    pub fn process(&mut self, input: &[f32]) -> Result<js_sys::Float32Array, JsValue> {
        if input.len() != 480 || !input.iter().all(|value| value.is_finite()) {
            return Err(JsValue::from_str("invalid audio frame"));
        }
        let input = ArrayView2::from_shape((1, 480), input).map_err(|_| JsValue::from_str("invalid frame"))?;
        let mut output = Array2::zeros((1, 480));
        self.inner.process(input, output.view_mut()).map_err(|_| JsValue::from_str("processing failed"))?;
        let samples = output.as_slice().ok_or_else(|| JsValue::from_str("invalid output"))?;
        if !samples.iter().all(|value| value.is_finite()) { return Err(JsValue::from_str("nonfinite output")); }
        Ok(js_sys::Float32Array::from(samples))
    }
}
