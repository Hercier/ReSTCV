import os
import sys

MOGWAI_DATA_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
sys.path.append(MOGWAI_DATA_PATH)
from config_setting import *


scene_view = None
case_name = "cbox_bunny"
scene_path = os.path.join(MEDIA_ROOT_DIR, "TestScenes", "CornellBoxBunny.pyscene")
target_frame = 0
start_anim_time = 0
only_GI = True
figure_exposure_ev = 0

outputDir = os.path.join(OUTPUT_ROOT_DIR, case_name)


def scene_setup(m):
    m.loadScene(scene_path)
