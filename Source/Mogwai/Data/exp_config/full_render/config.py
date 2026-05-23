import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
MEDIA_ROOT_DIR = os.environ.get("FALCOR_MEDIA_DIR", os.path.join(PROJECT_ROOT, "Media"))
ASSETS_ROOT_DIR = os.environ.get("RESTIR_PT_ASSETS_DIR", MEDIA_ROOT_DIR)
OUTPUT_ROOT_DIR = os.environ.get("RESTIR_PT_OUTPUT_DIR", os.path.join(PROJECT_ROOT, "Output", "Mogwai"))
outputs=["AccumulatePass.output","ToneMapper.dst"]
neighbour_count=3
