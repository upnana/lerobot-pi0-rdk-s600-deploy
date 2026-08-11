# BF16 GPU vs S600 HBM — pi0 stack3 sample 0

Shared input: calibration sample `0`  
Task: `Stack the blocks from bottom to top: white, blue, black.`  
Checkpoint: `/home/rxn/models/pi0_stack_white_blue_black_040000`

## Latency comparison

| device | dtype / runtime | load time | end-to-end infer latency (mean) | action shape |
|--------|-----------------|-----------|----------------------------------|--------------|
| PC RTX 3090 (`cuda:0`) | BF16 LeRobot torch (`predict_action_chunk` + postprocessor) | 66.743 s | **154.84 ms** (n=20; std 2.34; min 152.18; max 161.66; p50 154.40; p90 156.07) | [50, 6] |
| S600 board `192.168.54.29` | Quantized HBM standalone (`pi0_stack3_final.json`) | not reported separately (engine init in smoke log only) | **1224.71 ms** (n=1 client RTT smoke) | [50, 6] |

## Action compare (fixed noise both sides)

| metric | value |
|--------|-------|
| MAE (degrees, mixed relative/abs) | **1.5955** |
| RMSE (degrees, mixed relative/abs) | **2.3212** |
| per-dim MAE `[pan,lift,elbow,wrist_flex,wrist_roll,gripper]` | [0.5211, 1.3564, 1.1221, 3.8412, 0.7921, 1.9399] |

BF16 first_action (seed0 latency run, absolute): `[-16.3071, -97.8161, 94.487, 55.5419, 3.5782, 1.8022]`  
BF16 first_action (fixed noise, absolute): `[-15.2254, -100.5602, 97.6998, 56.1513, 4.0319, 2.3358]`  
HBM first_action (fixed noise, mixed/delta-like): `[1.1562, -1.9483, -3.8259, -0.6535, -1.4975, 2.5146]`

## Notes

- **Platform compare, not silicon apples-to-apples**: BF16 is GPU server (RTX 3090); HBM is S600 board quantized runtime.
- BF16 latency protocol: warmup 5, timed 20, `torch.cuda.synchronize()`, `noise_seed=0` each run.
- HBM protocol: single offline smoke via `pi0_standalone_offline.py`; fixed noise file present (`configs/fixed_noise_cv_12345678_fp16.bin`).
- Engine log had **no SigLIP / Expert x10 / Pi0 request stage timings** (placeholder-style init lines only). End-to-end `inference_ms` is client send→recv wall time.
- Action MAE uses the same fixed noise binary on both sides after aligning representations (BF16 absolute → mixed).

## Artifacts

- [`bf16_latency_sample0_summary.json`](./bf16_latency_sample0_summary.json) (slim; full JSON kept under gemma output)
- [`hbm_smoke_sample0_summary.json`](./hbm_smoke_sample0_summary.json)
- Source full dumps: `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/bench/`
- Board output: `diagnostics/offline_smoke_stack3_final_20260811_155544`
- Write-up: [`docs/15-offline-smoke-bf16-vs-hbm.md`](../../docs/15-offline-smoke-bf16-vs-hbm.md)
