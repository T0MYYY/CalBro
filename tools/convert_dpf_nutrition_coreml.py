import argparse
import os
import sys
from pathlib import Path

import torch


class DPFExportWrapper(torch.nn.Module):
    def __init__(self, model, tasks):
        super().__init__()
        self.model = model
        self.tasks = tasks

    def forward(self, rgb, depth):
        outputs = self.model(rgb, depth)
        return torch.stack([outputs[task] for task in self.tasks], dim=1)


def load_state(path):
    checkpoint = torch.load(path, map_location="cpu")
    if isinstance(checkpoint, dict):
        for key in ("model_state_dict", "state_dict", "model", "net", "network"):
            value = checkpoint.get(key)
            if isinstance(value, dict):
                return value
    if isinstance(checkpoint, dict):
        return checkpoint
    raise ValueError(f"Unsupported checkpoint format: {path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--nutrition5k-root", default="/Users/t0m/Downloads/nutrition5k")
    parser.add_argument("--checkpoint", default="/Users/t0m/Downloads/nutrition5k/checkpoints/dpf_food2k/best.pt")
    parser.add_argument("--food2k", default="/Users/t0m/Downloads/nutrition5k/weights/food2k_resnet101.pth")
    parser.add_argument("--output", default="/Users/t0m/Downloads/nutrition5k/coreml/DPFNutritionRGBDepth.mlpackage")
    parser.add_argument("--image-height", type=int, default=336)
    parser.add_argument("--image-width", type=int, default=448)
    args = parser.parse_args()

    root = Path(args.nutrition5k_root)
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    try:
        import coremltools as ct
    except ImportError as exc:
        raise SystemExit("coremltools is missing in the active conda environment") from exc

    from nutrition5k_pkg.models.dpf_nutrition import DPFNutritionNet

    checkpoint_path = Path(args.checkpoint)
    food2k_path = Path(args.food2k)
    output_path = Path(args.output)

    if not checkpoint_path.is_file():
        raise SystemExit(f"Missing checkpoint: {checkpoint_path}")
    if not food2k_path.is_file():
        raise SystemExit(f"Missing Food2K weights: {food2k_path}")

    tasks = ["calories", "mass", "fat", "carb", "protein"]
    model = DPFNutritionNet(
        tasks=tasks,
        pretrained=True,
        fusion_channels=512,
        head_hidden=512,
        food2k_resnet101_path=str(food2k_path),
    )
    model.load_state_dict(load_state(checkpoint_path), strict=False)
    model.eval()

    wrapper = DPFExportWrapper(model, tasks).eval()
    rgb = torch.rand(1, 3, args.image_height, args.image_width)
    depth = torch.rand(1, 1, args.image_height, args.image_width)

    traced = torch.jit.trace(wrapper, (rgb, depth), strict=False)
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[
            ct.TensorType(name="rgb", shape=rgb.shape),
            ct.TensorType(name="depth", shape=depth.shape),
        ],
        outputs=[ct.TensorType(name="nutrition")],
        minimum_deployment_target=ct.target.iOS17,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(output_path))
    print(output_path)


if __name__ == "__main__":
    os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")
    main()
