# Bundled Core ML models

These two Core ML packages are required to build and run CalBro, but are **not committed to git**
because a single DPF weight file is ~173 MB (over GitHub's 100 MB per-file limit).

Place them here so the app target bundles them:

```
CalBro/Resources/Models/
├── DPFNutritionRGBDepth.mlpackage                 # ~174 MB — DPF-Nutrition (RGB + Depth) regressor
└── depth-anything-v2-small/
    └── DepthAnythingV2SmallF16P6.mlpackage        # ~18 MB — Depth Anything V2 (Small), Core ML
```

## How to obtain

- **Quickest — Hugging Face:** [`T0MYYY/dpf-nutrition`](https://huggingface.co/T0MYYY/dpf-nutrition) hosts both Core ML packages under `coreml/` (`DPFNutritionRGBDepth.mlpackage`, `DepthAnythingV2SmallF16P6.mlpackage`).
- **DPF-Nutrition** is trained in the research repo
  [T0MYYY/Nutrition5k](https://github.com/T0MYYY/Nutrition5k) and converted to Core ML with
  `tools/convert_dpf_nutrition_coreml.py` (run from the `nutrition5k` conda environment).
- **Depth Anything V2 (Small)** Core ML package is converted from the official
  [Depth-Anything-V2](https://github.com/DepthAnything/Depth-Anything-V2) Small checkpoint
  (fixed 518×392 input, GRAYSCALE_FLOAT16 depth output).

> Tip: if you need these in git, enable **Git LFS** (`git lfs track "*.mlpackage/**"`) before committing.
